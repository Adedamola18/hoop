import Darwin
import Foundation
import Observation

@Observable
final class SystemStatsService {

    struct Stats {
        var cpuUsage: Double = 0       // 0-100%
        var memoryUsed: UInt64 = 0     // bytes
        var memoryTotal: UInt64 = 0    // bytes
        var memoryPressure: Double = 0 // 0-1

        var memoryUsedGB: Double {
            Double(memoryUsed) / (1024 * 1024 * 1024)
        }

        var memoryTotalGB: Double {
            Double(memoryTotal) / (1024 * 1024 * 1024)
        }
    }

    var stats = Stats()
    var cpuHistory: [Double] = []

    private var pollTimer: Timer?
    private var previousCPUInfo: host_cpu_load_info?

    func startObserving(interval: TimeInterval = 2) {
        stats.memoryTotal = ProcessInfo.processInfo.physicalMemory
        refreshStats()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshStats()
        }
    }

    func stopObserving() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshStats() {
        updateCPU()
        updateMemory()
    }

    // MARK: - CPU

    private func updateCPU() {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        if let prev = previousCPUInfo {
            let userDelta = Double(cpuInfo.cpu_ticks.0 - prev.cpu_ticks.0)
            let systemDelta = Double(cpuInfo.cpu_ticks.1 - prev.cpu_ticks.1)
            let idleDelta = Double(cpuInfo.cpu_ticks.2 - prev.cpu_ticks.2)
            let niceDelta = Double(cpuInfo.cpu_ticks.3 - prev.cpu_ticks.3)
            let totalDelta = userDelta + systemDelta + idleDelta + niceDelta

            if totalDelta > 0 {
                stats.cpuUsage = ((userDelta + systemDelta + niceDelta) / totalDelta) * 100
            }
        }

        previousCPUInfo = cpuInfo

        cpuHistory.append(stats.cpuUsage)
        if cpuHistory.count > 20 {
            cpuHistory.removeFirst()
        }
    }

    // MARK: - Memory

    private func updateMemory() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize

        stats.memoryUsed = active + wired + compressed
        let free = UInt64(vmStats.free_count) * pageSize
        let total = stats.memoryUsed + free
        stats.memoryPressure = total > 0 ? Double(stats.memoryUsed) / Double(total) : 0
    }
}
