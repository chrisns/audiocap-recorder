import Foundation
import AVFoundation
import Accelerate

struct ComplexityMetrics {
    let rms: Float
    let spectralCentroidHz: Float
    let spectralFlatness: Float
}

final class AdaptiveBitrateController {
    private let sampleRate: Double
    private var analysisCounter: Int = 0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func analyze(_ buffer: AVAudioPCMBuffer) -> ComplexityMetrics {
        let n = Int(buffer.frameLength)
        guard n > 0, let ch = buffer.floatChannelData else {
            return ComplexityMetrics(rms: 0, spectralCentroidHz: 0, spectralFlatness: 0)
        }
        // Mix to mono
        let channels = Int(buffer.format.channelCount)
        var mono = [Float](repeating: 0, count: n)
        for i in 0..<n {
            var sum: Float = 0
            for c in 0..<channels { sum += ch[c][i] }
            mono[i] = sum / Float(channels)
        }
        // RMS
        var rms: Float = 0
        vDSP_rmsqv(mono, 1, &rms, vDSP_Length(n))
        // Hann window
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        var winMono = [Float](repeating: 0, count: n)
        vDSP_vmul(mono, 1, window, 1, &winMono, 1, vDSP_Length(n))
        // Next power of two
        var fftN = 1
        while fftN < n { fftN <<= 1 }
        var re = winMono + [Float](repeating: 0, count: fftN - n)
        var im = [Float](repeating: 0, count: fftN)
        let log2n = vDSP_Length(log2(Float(fftN)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return ComplexityMetrics(rms: rms, spectralCentroidHz: 0, spectralFlatness: 0)
        }
        defer { vDSP_destroy_fftsetup(setup) }
        re.withUnsafeMutableBufferPointer { reBP in
            im.withUnsafeMutableBufferPointer { imBP in
                var split = DSPSplitComplex(realp: reBP.baseAddress!, imagp: imBP.baseAddress!)
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }
        var mags = [Float](repeating: 0, count: fftN/2)
        re.withUnsafeMutableBufferPointer { reBP in
            im.withUnsafeMutableBufferPointer { imBP in
                var split = DSPSplitComplex(realp: reBP.baseAddress!, imagp: imBP.baseAddress!)
                vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(fftN/2))
            }
        }
        // Spectral centroid
        var freqAxis = [Float](repeating: 0, count: mags.count)
        var start: Float = 0
        var step: Float = Float(sampleRate) / Float(fftN)
        vDSP_vramp(&start, &step, &freqAxis, 1, vDSP_Length(mags.count))
        var weightedSum: Float = 0
        vDSP_dotpr(mags, 1, freqAxis, 1, &weightedSum, vDSP_Length(mags.count))
        var magSum: Float = 0
        vDSP_sve(mags, 1, &magSum, vDSP_Length(mags.count))
        let centroid = magSum > 0 ? weightedSum / magSum : 0
        // Spectral flatness: geometric mean / arithmetic mean
        var logMags = mags.map { max($0, 1e-12) }
        var count = Int32(logMags.count)
        vvlogf(&logMags, logMags, &count)
        var meanLog: Float = 0
        vDSP_meanv(logMags, 1, &meanLog, vDSP_Length(logMags.count))
        let geomMean = expf(meanLog)
        let arithMean = magSum / Float(mags.count)
        let flatness = arithMean > 0 ? geomMean / arithMean : 0
        return ComplexityMetrics(rms: rms, spectralCentroidHz: centroid, spectralFlatness: flatness)
    }

    func suggestBitrate(baseKbps: UInt32, minKbps: UInt32 = 64, maxKbps: UInt32 = 320, metrics: ComplexityMetrics) -> UInt32 {
        // Heuristic: higher RMS and higher centroid and lower flatness -> higher bitrate
        // Normalize features
        let rmsNorm = min(max(metrics.rms / 0.2, 0), 1)
        let centroidNorm = min(max(metrics.spectralCentroidHz / Float(sampleRate/4.0), 0), 1)
        let tonality = 1 - min(max(metrics.spectralFlatness, 0), 1) // 1=tonal, 0=noisy
        let score = 0.5 * rmsNorm + 0.3 * centroidNorm + 0.2 * tonality
        let range = Double(maxKbps - minKbps)
        let target = Double(minKbps) + Double(score) * range
        // Smooth towards base bitrate every few analyses
        analysisCounter += 1
        let alpha: Double = analysisCounter % 3 == 0 ? 0.7 : 0.4
        let smoothed = alpha * target + (1 - alpha) * Double(baseKbps)
        let snapped = UInt32(min(max(minKbps, UInt32(smoothed.rounded())), maxKbps))
        // Snap to common steps
        let steps: [UInt32] = [64, 96, 128, 160, 192, 224, 256, 320]
        var nearest = steps.first ?? snapped
        var bestDiff = UInt32.max
        for s in steps {
            let d = s > snapped ? s - snapped : snapped - s
            if d < bestDiff { bestDiff = d; nearest = s }
        }
        // Down-cap for quiet/noisy content
        if metrics.rms < 0.01 { nearest = min(nearest, 128) }
        if metrics.spectralFlatness > 0.85 { nearest = min(nearest, 128) }
        return nearest
    }
}
