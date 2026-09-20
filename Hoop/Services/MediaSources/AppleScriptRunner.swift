import Foundation

/// Runs an AppleScript via /usr/bin/osascript and returns trimmed stdout,
/// or nil if the process fails or exits non-zero. Blocking — never call on main.
enum AppleScriptRunner {
    /// Runs `script` via osascript and returns trimmed stdout, or nil on failure,
    /// non-zero exit, or timeout. `timeout` bounds how long a stalled/hung script
    /// (e.g. a beach-balled player) can block the caller's queue.
    static func run(_ script: String, timeout: TimeInterval = 10) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            proc.terminate()
            return nil
        }

        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
