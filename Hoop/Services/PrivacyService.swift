import AVFoundation
import AppKit
import CoreAudio
import CoreGraphics
import Observation

@Observable
final class PrivacyService {

    var isCameraActive: Bool = false
    var isMicrophoneActive: Bool = false
    var isScreenRecording: Bool = false
    var cameraAppName: String?
    var microphoneAppName: String?
    var screenRecordingAppName: String?

    private var pollTimer: Timer?

    func startObserving() {
        refreshPrivacyState()
        // Poll every 2 seconds for camera/mic state changes
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshPrivacyState()
        }
    }

    func stopObserving() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshPrivacyState() {
        checkCameraState()
        checkMicrophoneState()
        checkScreenRecordingState()
    }

    // MARK: - Camera Detection

    private func checkCameraState() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices

        let wasActive = isCameraActive
        isCameraActive = devices.contains { $0.isInUseByAnotherApplication }

        if isCameraActive && !wasActive {
            // Try to find the app using the camera by checking running apps
            // with known camera-using bundle IDs
            cameraAppName = findCameraApp()
        } else if !isCameraActive {
            cameraAppName = nil
        }
    }

    private func findCameraApp() -> String? {
        let cameraApps = [
            "us.zoom.xos": "Zoom",
            "com.microsoft.teams": "Teams",
            "com.apple.FaceTime": "FaceTime",
            "com.google.Chrome": "Chrome",
            "com.apple.Safari": "Safari",
            "com.tinyspeck.slackmacgap": "Slack",
            "com.webex.meetingmanager": "Webex",
        ]

        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier,
               let name = cameraApps[bundleID] {
                return name
            }
        }
        return nil
    }

    // MARK: - Microphone Detection

    private func checkMicrophoneState() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size, &deviceID
        ) == noErr else {
            isMicrophoneActive = false
            microphoneAppName = nil
            return
        }

        // Check if the input device is running (being used)
        var isRunning: UInt32 = 0
        var runningSize = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let wasActive = isMicrophoneActive
        if AudioObjectGetPropertyData(
            deviceID,
            &runningAddress,
            0, nil,
            &runningSize, &isRunning
        ) == noErr {
            isMicrophoneActive = isRunning != 0
        } else {
            isMicrophoneActive = false
        }

        if isMicrophoneActive && !wasActive {
            microphoneAppName = findMicApp()
        } else if !isMicrophoneActive {
            microphoneAppName = nil
        }
    }

    private func findMicApp() -> String? {
        let micApps = [
            "us.zoom.xos": "Zoom",
            "com.microsoft.teams": "Teams",
            "com.apple.FaceTime": "FaceTime",
            "com.tinyspeck.slackmacgap": "Slack",
            "com.webex.meetingmanager": "Webex",
        ]

        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier,
               let name = micApps[bundleID] {
                return name
            }
        }
        return nil
    }

    // MARK: - Screen Recording Detection

    private func checkScreenRecordingState() {
        // Check for screen recording by looking for known recording apps
        // that are running, since CGDisplayStream-based detection requires
        // screen recording permission which we don't want to request.
        let recordingApps = [
            "com.apple.screencaptureui": "Screenshot",
            "com.apple.QuickTimePlayerX": "QuickTime",
            "com.obsproject.obs-studio": "OBS",
            "com.loom.desktop": "Loom",
            "com.techsmith.camtasia": "Camtasia",
            "com.getcleanshot.app": "CleanShot",
            "com.ScreenSnapAI.ScreenSnapAI": "ScreenSnap",
        ]

        let wasRecording = isScreenRecording
        var foundApp: String?

        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier,
               let name = recordingApps[bundleID] {
                foundApp = name
                break
            }
        }

        // Also check if the macOS screen recording indicator is active
        // by looking for the ScreenCaptureKit daemon
        if foundApp == nil {
            let hasCaptureDaemon = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.screencaptured"
            }
            if hasCaptureDaemon {
                foundApp = "Screen Recording"
            }
        }

        isScreenRecording = foundApp != nil

        if isScreenRecording && !wasRecording {
            screenRecordingAppName = foundApp
        } else if !isScreenRecording {
            screenRecordingAppName = nil
        }
    }
}
