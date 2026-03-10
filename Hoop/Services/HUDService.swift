import AppKit
import CoreAudio
import AudioToolbox
import Observation
import IOKit.graphics

enum HUDType {
    case volume
    case brightness
}

@Observable
final class HUDService {

    var currentLevel: Float = 0
    var hudType: HUDType = .volume
    var isShowingHUD: Bool = false

    /// Auto-dismiss timeout in seconds. Configurable 1-5s, default 2s.
    var autoDismissTimeout: TimeInterval {
        let t = UserDefaults.standard.double(forKey: "hudDismissTimeout")
        return t > 0 ? max(1, min(5, t)) : 2
    }

    private var dismissWorkItem: DispatchWorkItem?
    private var defaultDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
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
    }

    func stopObserving() {
        removeVolumeListener()
        removeDefaultDeviceListener()
        stopBrightnessPolling()
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
