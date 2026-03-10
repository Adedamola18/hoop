import Foundation
import Observation

@Observable
final class ShortcutsService {

    struct Shortcut: Identifiable, Hashable {
        let id: String
        let name: String
    }

    enum RunState {
        case idle
        case running(String)
        case success(String)
        case failure(String)
    }

    var allShortcuts: [Shortcut] = []
    var favoriteNames: [String] {
        didSet {
            UserDefaults.standard.set(favoriteNames, forKey: "shortcutFavorites")
        }
    }
    var runState: RunState = .idle

    var favorites: [Shortcut] {
        favoriteNames.compactMap { name in
            allShortcuts.first { $0.name == name }
        }
    }

    init() {
        favoriteNames = UserDefaults.standard.stringArray(forKey: "shortcutFavorites") ?? []
    }

    func loadShortcuts() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        proc.arguments = ["list"]
        let pipe = Pipe()
        proc.standardOutput = pipe

        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let names = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                allShortcuts = names.map { Shortcut(id: $0, name: $0) }
            }
        } catch {
            allShortcuts = []
        }
    }

    func toggleFavorite(_ name: String) {
        if favoriteNames.contains(name) {
            favoriteNames.removeAll { $0 == name }
        } else if favoriteNames.count < 6 {
            favoriteNames.append(name)
        }
    }

    func runShortcut(_ name: String) {
        runState = .running(name)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            proc.arguments = ["run", name]

            do {
                try proc.run()
                proc.waitUntilExit()
                DispatchQueue.main.async {
                    if proc.terminationStatus == 0 {
                        self?.runState = .success(name)
                    } else {
                        self?.runState = .failure(name)
                    }
                    // Auto-reset after 2s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.runState = .idle
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.runState = .failure(name)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.runState = .idle
                    }
                }
            }
        }
    }
}
