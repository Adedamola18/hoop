import Foundation
import IOKit.ps
import Observation

@Observable
final class BatteryService {

    struct BatteryInfo {
        var percentage: Int = -1
        var isCharging: Bool = false
        var isPluggedIn: Bool = false
        var isValid: Bool = false
    }

    var battery = BatteryInfo()

    private var pollTimer: Timer?

    func startObserving() {
        refreshBattery()
        // Poll every 30 seconds — battery changes are slow
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshBattery()
        }
    }

    func stopObserving() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let first = sources.first else {
            battery.isValid = false
            return
        }

        guard let desc = IOPSGetPowerSourceDescription(snapshot, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any] else {
            battery.isValid = false
            return
        }

        let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let powerSource = desc[kIOPSPowerSourceStateKey] as? String ?? ""

        battery.percentage = capacity
        battery.isCharging = isCharging
        battery.isPluggedIn = powerSource == kIOPSACPowerValue
        battery.isValid = capacity >= 0
    }
}
