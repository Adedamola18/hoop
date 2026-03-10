import AppKit
import CoreAudio
import AudioToolbox
import Observation
import IOKit.graphics
import CoreGraphics

enum HUDType {
    case volume
    case brightness
}

@Observable
final class HUDService {

    var currentLevel: Float = 0
    var hudType: HUDType = .volume
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
    private var defaultDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?

    // MARK: - OSD Suppression (CGEventTap)

    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?

    /// NX_SUBTYPE_AUX_CONTROL_BUTTONS
    private static let auxControlSubtype: Int64 = 8
    /// Key types for OSD-triggering keys
    private static let soundUpKeyType: Int32 = 0       // NX_KEYTYPE_SOUND_UP
    private static let soundDownKeyType: Int32 = 1     // NX_KEYTYPE_SOUND_DOWN
    private static let muteKeyType: Int32 = 7          // NX_KEYTYPE_MUTE
    private static let brightnessUpKeyType: Int32 = 21 // Brightness up
    private static let brightnessDownKeyType: Int32 = 22 // Brightness down

    private var volumePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    /// Callback fired when HUD should show (with type and level).
    var onHUDShow: ((HUDType, Float) -> Void)?

    /// Callback fired when HUD should dismiss.
    var onHUDDismiss: (() -> Void)?

    // MARK: - Brightness State

    private var brightnessPollingTimer: DispatchSourceTimer?
    private var lastKnownBrightness: Float = -1

    func startObserving() {
        fetchDefaultOutputDevice()
        installDefaultDeviceListener()
        installVolumeListener()
        startBrightnessPolling()
        installEventTapIfNeeded()
    }

    func stopObserving() {
        removeVolumeListener()
        removeDefaultDeviceListener()
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

    // MARK: - Volume Control

    func setVolume(_ level: Float) {
        guard defaultDeviceID != kAudioObjectUnknown else { return }
        var volume = max(0, min(1, level))
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(
            defaultDeviceID,
            &volumePropertyAddress,
            0, nil,
            size,
            &volume
        )
    }

    // MARK: - Show / Dismiss

    func showHUD(type: HUDType, level: Float) {
        hudType = type
        currentLevel = level
        isShowingHUD = true
        onHUDShow?(type, level)
        scheduleDismiss()
    }

    func dismissHUD() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        isShowingHUD = false
        onHUDDismiss?()
    }

    private func scheduleDismiss() {
        dismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.dismissHUD()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissTimeout, execute: work)
    }

    // MARK: - Default Output Device

    private func fetchDefaultOutputDevice() {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            0, nil,
            &size,
            &deviceID
        )
        if status == noErr {
            defaultDeviceID = deviceID
        }
    }

    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?

    private func installDefaultDeviceListener() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.removeVolumeListener()
                self?.fetchDefaultOutputDevice()
                self?.installVolumeListener()
            }
        }
        defaultDeviceListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            DispatchQueue.main,
            block
        )
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            DispatchQueue.main,
            block
        )
        defaultDeviceListenerBlock = nil
    }

    // MARK: - Volume Listener

    private func installVolumeListener() {
        guard defaultDeviceID != kAudioObjectUnknown else { return }

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.handleVolumeChange()
            }
        }
        volumeListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            defaultDeviceID,
            &volumePropertyAddress,
            DispatchQueue.main,
            block
        )
    }

    private func removeVolumeListener() {
        guard defaultDeviceID != kAudioObjectUnknown, let block = volumeListenerBlock else { return }
        AudioObjectRemovePropertyListenerBlock(
            defaultDeviceID,
            &volumePropertyAddress,
            DispatchQueue.main,
            block
        )
        volumeListenerBlock = nil
    }

    private func handleVolumeChange() {
        guard defaultDeviceID != kAudioObjectUnknown else { return }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            defaultDeviceID,
            &volumePropertyAddress,
            0, nil,
            &size,
            &volume
        )
        if status == noErr {
            showHUD(type: .volume, level: volume)
        }
    }

    // MARK: - Native HUD Suppression (CGEventTap)

    private func installEventTapIfNeeded() {
        guard hudReplacementEnabled, eventTap == nil else { return }

        // Create a CGEventTap to intercept system-defined events (media/brightness keys).
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
                HUDService.soundUpKeyType,
                HUDService.soundDownKeyType,
                HUDService.muteKeyType,
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

    private func startBrightnessPolling() {
        // Seed initial brightness so the first real change triggers the HUD
        lastKnownBrightness = readBrightness() ?? -1

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.3, repeating: 0.3)
        timer.setEventHandler { [weak self] in
            self?.pollBrightness()
        }
        timer.resume()
        brightnessPollingTimer = timer
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
            showHUD(type: .brightness, level: brightness)
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
