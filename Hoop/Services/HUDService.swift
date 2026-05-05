import AppKit
import Observation
import IOKit.graphics
import CoreGraphics

@Observable
final class HUDService {

    var currentLevel: Float = 0
    var isShowingHUD: Bool = false

    /// Whether the custom HUD replaces the native macOS HUD. Opt-in via Settings (default: on).
    var hudReplacementEnabled: Bool {
        let v = UserDefaults.standard.object(forKey: "hudReplacementEnabled")
        return (v as? Bool) ?? true
    }

    /// Auto-dismiss timeout in seconds. Configurable 1-5s, default 2s.
    var autoDismissTimeout: TimeInterval {
        let t = UserDefaults.standard.double(forKey: "hudDismissTimeout")
        return t > 0 ? max(1, min(5, t)) : 2
    }

    private var dismissWorkItem: DispatchWorkItem?

    // MARK: - OSD Suppression (CGEventTap)

    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?

    /// NX_SUBTYPE_AUX_CONTROL_BUTTONS
    private static let auxControlSubtype: Int64 = 8
    /// Key types for OSD-triggering keys
    private static let brightnessUpKeyType: Int32 = 21
    private static let brightnessDownKeyType: Int32 = 22

    /// Callback fired when HUD should show (with level).
    var onHUDShow: ((Float) -> Void)?

    /// Callback fired when HUD should dismiss.
    var onHUDDismiss: (() -> Void)?

    // MARK: - Brightness State

    private var brightnessPollingTimer: DispatchSourceTimer?
    private var lastKnownBrightness: Float = -1

    func startObserving() {
        startBrightnessPolling()
        installEventTapIfNeeded()
    }

    func stopObserving() {
        stopBrightnessPolling()
        removeEventTap()
    }

    /// Re-evaluate whether the event tap should be active (called when settings change).
    func updateSuppressionState() {
        if hudReplacementEnabled {
            installEventTapIfNeeded()
        } else {
            removeEventTap()
        }
    }

    // MARK: - Show / Dismiss

    func showHUD(level: Float) {
        currentLevel = level
        isShowingHUD = true
        onHUDShow?(level)
        scheduleDismiss()
        updateBrightnessPollingRate()
    }

    func dismissHUD() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        isShowingHUD = false
        onHUDDismiss?()
        updateBrightnessPollingRate()
    }

    private func scheduleDismiss() {
        dismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.dismissHUD()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissTimeout, execute: work)
    }

    // MARK: - Native HUD Suppression (CGEventTap)

    private func installEventTapIfNeeded() {
        guard hudReplacementEnabled, eventTap == nil else { return }

        // Create a CGEventTap to intercept system-defined events (brightness keys).
        // Returning nil from the callback suppresses the native OSD.
        // Requires Accessibility permission; fails gracefully if not granted.
        let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
            // Re-enable tap if it gets disabled by the system (e.g., timeout)
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon {
                    let service = Unmanaged<HUDService>.fromOpaque(refcon).takeUnretainedValue()
                    if let tap = service.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }
                return Unmanaged.passRetained(event)
            }

            guard type == .keyDown || type == .keyUp || CGEventType(rawValue: 14) == type else {
                return Unmanaged.passRetained(event)
            }

            let nsEvent = NSEvent(cgEvent: event)
            guard let nsEvent, nsEvent.subtype.rawValue == HUDService.auxControlSubtype else {
                return Unmanaged.passRetained(event)
            }

            let keyType = Int32((nsEvent.data1 >> 16) & 0xFF)
            let suppressedKeys: [Int32] = [
                HUDService.brightnessUpKeyType,
                HUDService.brightnessDownKeyType,
            ]

            if suppressedKeys.contains(keyType) {
                // Check if replacement is still enabled (read from UserDefaults for thread safety)
                let enabled = UserDefaults.standard.object(forKey: "hudReplacementEnabled") as? Bool ?? true
                if enabled {
                    return nil // Suppress native OSD
                }
            }

            return Unmanaged.passRetained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << 14), // NSEventTypeSystemDefined = 14
            callback: tapCallback,
            userInfo: refcon
        ) else {
            // Accessibility permission not granted or tap creation failed — degrade gracefully.
            // Both native and custom HUD will show, which is acceptable per AC.
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTapRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeEventTap() {
        if let source = eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            eventTapRunLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    // MARK: - Brightness Monitoring (IOKit polling)

    /// Adaptive brightness polling interval: slow when idle, fast when HUD is active.
    private var brightnessPollingInterval: TimeInterval {
        isShowingHUD ? 0.1 : 1.0
    }

    private func startBrightnessPolling() {
        // Seed initial brightness so the first real change triggers the HUD
        lastKnownBrightness = readBrightness() ?? -1
        scheduleBrightnessTimer(interval: 1.0)
    }

    private func scheduleBrightnessTimer(interval: TimeInterval) {
        brightnessPollingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.pollBrightness()
        }
        timer.resume()
        brightnessPollingTimer = timer
    }

    /// Adjust brightness polling rate when HUD state changes.
    private func updateBrightnessPollingRate() {
        guard brightnessPollingTimer != nil else { return }
        scheduleBrightnessTimer(interval: brightnessPollingInterval)
    }

    private func stopBrightnessPolling() {
        brightnessPollingTimer?.cancel()
        brightnessPollingTimer = nil
    }

    private func pollBrightness() {
        guard let brightness = readBrightness() else { return }
        let delta = abs(brightness - lastKnownBrightness)
        if delta > 0.005 { // ignore noise
            lastKnownBrightness = brightness
            showHUD(level: brightness)
        }
    }

    /// Read display brightness via IOKit `IODisplayGetFloatParameter`.
    private func readBrightness() -> Float? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var brightness: Float = 0
            let err = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
            IOObjectRelease(service)
            if err == kIOReturnSuccess {
                return brightness
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    /// Set display brightness via IOKit `IODisplaySetFloatParameter`.
    func setBrightness(_ level: Float) {
        let clamped = max(0, min(1, level))

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else { return }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            let err = IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, clamped)
            IOObjectRelease(service)
            if err == kIOReturnSuccess {
                lastKnownBrightness = clamped
                return
            }
            service = IOIteratorNext(iterator)
        }
    }
}
