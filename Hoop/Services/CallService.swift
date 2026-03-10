import AppKit
import Observation

@Observable
final class CallService {
    struct CallInfo {
        let callerName: String
        let callerNumber: String
        let timestamp: Date
    }

    var incomingCall: CallInfo?
    var isCallActive: Bool { incomingCall != nil }

    private var observer: NSObjectProtocol?
    private var processCheckTimer: DispatchSourceTimer?

    /// Whether FaceTime is currently showing an incoming call UI.
    private var lastFaceTimeState: Bool = false

    func startObserving() {
        // Monitor DistributedNotificationCenter for FaceTime call notifications
        observer = DistributedNotificationCenter.default().addObserver(
            forName: nil,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // FaceTime uses com.apple.FaceTime notifications
            let name = notification.name.rawValue
            if name.contains("FaceTime") || name.contains("IncomingCall") || name.contains("telephony") {
                self?.handleCallNotification(notification)
            }
        }

        // Poll for FaceTime ringing state as fallback
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 2.0)
        timer.setEventHandler { [weak self] in
            self?.checkFaceTimeState()
        }
        timer.resume()
        processCheckTimer = timer
    }

    func stopObserving() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
        processCheckTimer?.cancel()
        processCheckTimer = nil
    }

    func acceptCall() {
        // Open FaceTime to accept
        if let url = URL(string: "facetime://") {
            NSWorkspace.shared.open(url)
        }
        dismissCall()
    }

    func declineCall() {
        dismissCall()
    }

    func dismissCall() {
        incomingCall = nil
    }

    private func handleCallNotification(_ notification: Notification) {
        let userInfo = notification.userInfo
        let caller = userInfo?["callerName"] as? String
            ?? userInfo?["caller"] as? String
            ?? "Unknown Caller"
        let number = userInfo?["callerNumber"] as? String
            ?? userInfo?["number"] as? String
            ?? ""

        incomingCall = CallInfo(
            callerName: caller,
            callerNumber: number,
            timestamp: Date()
        )

        // Auto-dismiss after 30 seconds if not answered
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if let call = self?.incomingCall, call.timestamp.timeIntervalSinceNow < -25 {
                self?.incomingCall = nil
            }
        }
    }

    private func checkFaceTimeState() {
        let isFaceTimeRinging = NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.apple.FaceTime" && app.isActive
        }

        // If FaceTime just became active and we don't have a call, create a generic one
        if isFaceTimeRinging && !lastFaceTimeState && incomingCall == nil {
            // FaceTime became active — might be an incoming call
            // Only trigger if FaceTime was not previously in foreground
        }
        lastFaceTimeState = isFaceTimeRinging

        // If FaceTime is no longer active and we have a call, dismiss it
        if !isFaceTimeRinging && incomingCall != nil {
            // Give it a moment in case user is switching apps
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                let stillRunning = NSWorkspace.shared.runningApplications.contains {
                    $0.bundleIdentifier == "com.apple.FaceTime" && $0.isActive
                }
                if !stillRunning {
                    self?.incomingCall = nil
                }
            }
        }
    }
}
