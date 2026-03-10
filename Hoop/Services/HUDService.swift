import AppKit
import CoreAudio
import AudioToolbox
import Observation

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

    func startObserving() {
        fetchDefaultOutputDevice()
        installDefaultDeviceListener()
        installVolumeListener()
    }

    func stopObserving() {
        removeVolumeListener()
        removeDefaultDeviceListener()
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
}
