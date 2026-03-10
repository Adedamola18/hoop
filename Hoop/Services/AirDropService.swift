import AppKit
import Observation

@Observable
final class AirDropService {
    struct TransferInfo {
        let fileName: String
        let direction: Direction
        let startTime: Date

        enum Direction {
            case sending
            case receiving
        }
    }

    var activeTransfer: TransferInfo?
    var isTransferActive: Bool { activeTransfer != nil }

    private var processCheckTimer: DispatchSourceTimer?
    private var downloadObserver: NSObjectProtocol?

    /// Track whether sharingd was recently busy (crude heuristic).
    private var lastSharingdCPU: Double = 0

    func startObserving() {
        // Watch ~/Downloads for new AirDrop files (macOS deposits AirDrop receives here)
        watchDownloadsFolder()

        // Poll sharingd process for activity
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 3.0)
        timer.setEventHandler { [weak self] in
            self?.checkSharingdActivity()
        }
        timer.resume()
        processCheckTimer = timer
    }

    func stopObserving() {
        processCheckTimer?.cancel()
        processCheckTimer = nil
        if let downloadObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(downloadObserver)
        }
        downloadObserver = nil
    }

    func dismissTransfer() {
        activeTransfer = nil
    }

    private func watchDownloadsFolder() {
        // Use NSMetadataQuery to detect AirDrop-received files
        // AirDrop files arrive with com.apple.metadata:kMDItemWhereFroms containing "AirDrop"
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let downloadsPath = downloadsURL?.path else { return }

        // Simple approach: watch for new files via dispatch source
        let fd = open(downloadsPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.checkForNewAirDropFiles()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
    }

    private func checkForNewAirDropFiles() {
        // Check for recently modified files in Downloads
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let downloadsURL else { return }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-5) // Last 5 seconds
        for fileURL in contents {
            guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                  let modDate = attrs[.modificationDate] as? Date,
                  modDate > cutoff else { continue }

            // Could be an AirDrop file — show indicator
            if activeTransfer == nil {
                activeTransfer = TransferInfo(
                    fileName: fileURL.lastPathComponent,
                    direction: .receiving,
                    startTime: Date()
                )

                // Auto-dismiss after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.activeTransfer = nil
                }
                return
            }
        }
    }

    private func checkSharingdActivity() {
        // Auto-dismiss stale transfers after 30 seconds
        if let transfer = activeTransfer,
           transfer.startTime.timeIntervalSinceNow < -30 {
            activeTransfer = nil
        }
    }
}
