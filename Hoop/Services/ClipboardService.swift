import AppKit
import Observation

@Observable
final class ClipboardService {

    struct ClipboardEntry: Identifiable {
        let id = UUID()
        let content: ClipboardContent
        let timestamp: Date

        var preview: String {
            switch content {
            case .text(let str):
                return String(str.prefix(80))
            case .image:
                return "[Image]"
            case .fileURL(let url):
                return url.lastPathComponent
            }
        }
    }

    enum ClipboardContent {
        case text(String)
        case image(NSImage)
        case fileURL(URL)
    }

    var entries: [ClipboardEntry] = []
    var searchQuery: String = ""

    var filteredEntries: [ClipboardEntry] {
        guard !searchQuery.isEmpty else { return entries }
        return entries.filter { $0.preview.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var pollTimer: Timer?
    private var lastChangeCount: Int = 0
    private let maxEntries = 20

    func startObserving() {
        lastChangeCount = NSPasteboard.general.changeCount
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stopObserving() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func copyToClipboard(_ entry: ClipboardEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch entry.content {
        case .text(let str):
            pb.setString(str, forType: .string)
        case .image(let image):
            if let tiffData = image.tiffRepresentation {
                pb.setData(tiffData, forType: .tiff)
            }
        case .fileURL(let url):
            pb.setString(url.absoluteString, forType: .string)
        }
        // Update change count so we don't re-capture what we just set
        lastChangeCount = pb.changeCount
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let string = pb.string(forType: .string), !string.isEmpty {
            addEntry(.text(string))
        } else if let imageData = pb.data(forType: .tiff), let image = NSImage(data: imageData) {
            addEntry(.image(image))
        } else if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], let url = urls.first {
            addEntry(.fileURL(url))
        }
    }

    private func addEntry(_ content: ClipboardContent) {
        let entry = ClipboardEntry(content: content, timestamp: Date())
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast()
        }
    }
}
