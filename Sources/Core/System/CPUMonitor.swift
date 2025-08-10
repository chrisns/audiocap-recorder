import Foundation
import Darwin.Mach

public final class CPUMonitor {
    private var lastUser: UInt32 = 0
    private var lastSystem: UInt32 = 0
    private var lastIdle: UInt32 = 0
    private var lastNice: UInt32 = 0
    private var hasLast: Bool = false

    public init() {}

    public func sampleUsedPercent() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                return host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let user = info.cpu_ticks.0
        let system = info.cpu_ticks.1
        let idle = info.cpu_ticks.2
        let nice = info.cpu_ticks.3

        if !hasLast {
            lastUser = user; lastSystem = system; lastIdle = idle; lastNice = nice; hasLast = true
            return 0
        }
        let dUser = user &- lastUser
        let dSystem = system &- lastSystem
        let dIdle = idle &- lastIdle
        let dNice = nice &- lastNice

        lastUser = user; lastSystem = system; lastIdle = idle; lastNice = nice

        let total = Double(dUser &+ dSystem &+ dIdle &+ dNice)
        guard total > 0 else { return 0 }
        let used = Double(dUser &+ dSystem &+ dNice)
        return min(100.0, max(0.0, (used / total) * 100.0))
    }
}
