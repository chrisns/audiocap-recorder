import Foundation

public final class ShutdownCoordinator {
    private let audioCapturer: AudioCapturerProtocol
    private let fileController: FileControllerProtocol

    public init(audioCapturer: AudioCapturerProtocol, fileController: FileControllerProtocol) {
        self.audioCapturer = audioCapturer
        self.fileController = fileController
    }

    public func performGracefulShutdown(finalData: Data?, outputDirectory: String?) {
        audioCapturer.stopCapture()
        if let finalData, let directory = outputDirectory {
            _ = try? fileController.writeAudioData(finalData, to: directory)
        }
    }
}
