import AppKit
import Vision

// MARK: - Drop Action Protocol

protocol DropAction: Identifiable {
    var id: String { get }
    var name: String { get }
    var iconName: String { get }
    var supportedExtensions: Set<String> { get }

    func canHandle(url: URL) -> Bool
    func execute(urls: [URL]) async throws -> DropActionResult
}

extension DropAction {
    func canHandle(url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}

struct DropActionResult {
    let success: Bool
    let message: String
    /// Optional output file path for pipeline chaining
    let outputPath: String?

    init(success: Bool, message: String, outputPath: String? = nil) {
        self.success = success
        self.message = message
        self.outputPath = outputPath
    }
}

// MARK: - Compress Image Action

struct CompressImageAction: DropAction {
    let id = "compress-image"
    let name = "Compress Image"
    let iconName = "arrow.down.right.and.arrow.up.left"
    let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "bmp", "heic", "webp"]

    func execute(urls: [URL]) async throws -> DropActionResult {
        var count = 0
        for url in urls where canHandle(url: url) {
            guard let image = NSImage(contentsOf: url) else { continue }

            // Resize to max 1024px on longest side and compress as JPEG
            let maxDimension: CGFloat = 1024
            let size = image.size
            let scale: CGFloat
            if size.width > maxDimension || size.height > maxDimension {
                scale = maxDimension / max(size.width, size.height)
            } else {
                scale = 1.0
            }

            let newSize = NSSize(width: size.width * scale, height: size.height * scale)
            let resized = NSImage(size: newSize)
            resized.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize),
                       from: NSRect(origin: .zero, size: size),
                       operation: .copy,
                       fraction: 1.0)
            resized.unlockFocus()

            guard let tiffData = resized.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
                continue
            }

            // Copy compressed image data to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(jpegData, forType: .png) // Use PNG type for broader compatibility
            // Also write the NSImage for apps that prefer that
            pasteboard.writeObjects([resized])
            count += 1
        }

        if count > 0 {
            return DropActionResult(success: true, message: "Compressed \(count) image\(count == 1 ? "" : "s") → clipboard")
        } else {
            return DropActionResult(success: false, message: "No valid images found")
        }
    }
}

// MARK: - OCR Action

struct OCRAction: DropAction {
    let id = "ocr-text"
    let name = "Extract Text (OCR)"
    let iconName = "doc.text.viewfinder"
    let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "bmp", "heic", "webp", "pdf"]

    func execute(urls: [URL]) async throws -> DropActionResult {
        var allText: [String] = []

        for url in urls where canHandle(url: url) {
            let text = try await recognizeText(in: url)
            if !text.isEmpty {
                allText.append(text)
            }
        }

        let combined = allText.joined(separator: "\n\n")

        if combined.isEmpty {
            return DropActionResult(success: false, message: "No text found in image")
        }

        // Copy extracted text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combined, forType: .string)

        let charCount = combined.count
        return DropActionResult(success: true, message: "Extracted \(charCount) chars → clipboard")
    }

    private func recognizeText(in url: URL) async throws -> String {
        guard let cgImage = loadCGImage(from: url) else {
            return ""
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func loadCGImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
}

// MARK: - Shortcut Drop Action

struct ShortcutDropAction: DropAction {
    let id: String
    let name: String
    let iconName = "shortcuts"
    let supportedExtensions: Set<String>
    let shortcutName: String

    init(shortcutName: String, supportedExtensions: Set<String> = ["*"]) {
        self.id = "shortcut-\(shortcutName)"
        self.name = "Shortcut: \(shortcutName)"
        self.shortcutName = shortcutName
        self.supportedExtensions = supportedExtensions
    }

    func canHandle(url: URL) -> Bool {
        supportedExtensions.contains("*") || supportedExtensions.contains(url.pathExtension.lowercased())
    }

    func execute(urls: [URL]) async throws -> DropActionResult {
        guard let firstURL = urls.first else {
            return DropActionResult(success: false, message: "No files provided")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", shortcutName, "--input-path", firstURL.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 {
            // If stdout contains a file path, use it as output for pipeline chaining
            let outputPath: String? = stdout.hasPrefix("/") ? stdout : nil
            let msg = stdout.isEmpty ? "Shortcut '\(shortcutName)' completed" : "Shortcut done: \(stdout.prefix(100))"
            return DropActionResult(success: true, message: msg, outputPath: outputPath)
        } else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            return DropActionResult(success: false, message: "Shortcut failed: \(stderr.prefix(100))")
        }
    }
}

// MARK: - Shell Script Drop Action

struct ShellScriptDropAction: DropAction {
    let id: String
    let name: String
    let iconName = "terminal"
    let supportedExtensions: Set<String>
    let command: String

    init(name: String, command: String, supportedExtensions: Set<String> = ["*"]) {
        self.id = "shell-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        self.name = name
        self.command = command
        self.supportedExtensions = supportedExtensions
    }

    func canHandle(url: URL) -> Bool {
        supportedExtensions.contains("*") || supportedExtensions.contains(url.pathExtension.lowercased())
    }

    func execute(urls: [URL]) async throws -> DropActionResult {
        guard let firstURL = urls.first else {
            return DropActionResult(success: false, message: "No files provided")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command, "--", firstURL.path]
        process.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 {
            // If stdout contains a file path, use it as output for pipeline chaining
            let outputPath: String? = stdout.hasPrefix("/") ? stdout : nil
            if !stdout.isEmpty {
                // Copy stdout to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(stdout, forType: .string)
            }
            let msg = stdout.isEmpty ? "Script completed" : "Output (\(stdout.count) chars) → clipboard"
            return DropActionResult(success: true, message: msg, outputPath: outputPath)
        } else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            return DropActionResult(success: false, message: "Script failed: \(stderr.prefix(100))")
        }
    }
}

// MARK: - Pipeline Configuration (Codable)

enum PipelineStepType: String, Codable, CaseIterable {
    case compressImage
    case ocr
    case shortcut
    case shellScript
}

struct PipelineStep: Codable, Identifiable {
    let id: UUID
    var stepType: PipelineStepType
    /// For shortcut: shortcut name. For shellScript: command string. For built-ins: unused.
    var config: String

    init(stepType: PipelineStepType, config: String = "") {
        self.id = UUID()
        self.stepType = stepType
        self.config = config
    }
}

struct PipelineConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var steps: [PipelineStep]
    var supportedExtensions: Set<String>

    init(id: UUID = UUID(), name: String, steps: [PipelineStep], supportedExtensions: Set<String> = ["*"]) {
        self.id = id
        self.name = name
        self.steps = steps
        self.supportedExtensions = supportedExtensions
    }
}

// MARK: - Pipeline Drop Action

struct PipelineDropAction: DropAction {
    let id: String
    let name: String
    let iconName = "arrow.triangle.branch"
    let supportedExtensions: Set<String>
    let pipeline: PipelineConfig

    init(pipeline: PipelineConfig) {
        self.id = "pipeline-\(pipeline.id.uuidString)"
        self.name = pipeline.name
        self.supportedExtensions = pipeline.supportedExtensions
        self.pipeline = pipeline
    }

    func canHandle(url: URL) -> Bool {
        supportedExtensions.contains("*") || supportedExtensions.contains(url.pathExtension.lowercased())
    }

    func execute(urls: [URL]) async throws -> DropActionResult {
        var currentURLs = urls

        for (index, step) in pipeline.steps.enumerated() {
            let action = makeAction(for: step)
            let result = try await action.execute(urls: currentURLs)

            if !result.success {
                return DropActionResult(
                    success: false,
                    message: "Pipeline failed at step \(index + 1): \(result.message)"
                )
            }

            // Chain: if step produced an output path, use it as input for next step
            if let outputPath = result.outputPath {
                currentURLs = [URL(fileURLWithPath: outputPath)]
            }
            // Otherwise keep currentURLs for next step
        }

        return DropActionResult(
            success: true,
            message: "Pipeline '\(pipeline.name)' completed (\(pipeline.steps.count) steps)"
        )
    }

    private func makeAction(for step: PipelineStep) -> any DropAction {
        switch step.stepType {
        case .compressImage:
            return CompressImageAction()
        case .ocr:
            return OCRAction()
        case .shortcut:
            return ShortcutDropAction(shortcutName: step.config)
        case .shellScript:
            return ShellScriptDropAction(name: "Pipeline Step", command: step.config)
        }
    }
}

// MARK: - Custom Drop Action Configuration (Codable)

enum CustomDropActionType: String, Codable, CaseIterable {
    case shortcut
    case shellScript

    var label: String {
        switch self {
        case .shortcut: return "Shortcut"
        case .shellScript: return "Shell Script"
        }
    }

    var iconName: String {
        switch self {
        case .shortcut: return "shortcuts"
        case .shellScript: return "terminal"
        }
    }
}

struct CustomDropActionConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var actionType: CustomDropActionType
    /// For shortcut: shortcut name. For shellScript: command string.
    var config: String
    var fileExtensions: Set<String>

    init(id: UUID = UUID(), name: String, actionType: CustomDropActionType, config: String, fileExtensions: Set<String> = ["*"]) {
        self.id = id
        self.name = name
        self.actionType = actionType
        self.config = config
        self.fileExtensions = fileExtensions
    }

    func toDropAction() -> any DropAction {
        switch actionType {
        case .shortcut:
            return ShortcutDropAction(shortcutName: config, supportedExtensions: fileExtensions)
        case .shellScript:
            return ShellScriptDropAction(name: name, command: config, supportedExtensions: fileExtensions)
        }
    }
}

// MARK: - Custom Drop Action Store (UserDefaults persistence)

struct CustomDropActionStore {
    private static let key = "customDropActions"
    private static var cached: [CustomDropActionConfig]?

    static func load() -> [CustomDropActionConfig] {
        if let cached { return cached }
        guard let data = UserDefaults.standard.data(forKey: key),
              let actions = try? JSONDecoder().decode([CustomDropActionConfig].self, from: data) else {
            cached = []
            return []
        }
        cached = actions
        return actions
    }

    static func save(_ actions: [CustomDropActionConfig]) {
        cached = actions
        if let data = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Pipeline Store (UserDefaults persistence)

struct PipelineStore {
    private static let key = "dropActionPipelines"
    private static var cached: [PipelineConfig]?

    static func load() -> [PipelineConfig] {
        if let cached { return cached }
        guard let data = UserDefaults.standard.data(forKey: key),
              let pipelines = try? JSONDecoder().decode([PipelineConfig].self, from: data) else {
            cached = []
            return []
        }
        cached = pipelines
        return pipelines
    }

    static func save(_ pipelines: [PipelineConfig]) {
        cached = pipelines
        if let data = try? JSONEncoder().encode(pipelines) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Drop Action Service

@Observable
final class DropActionService {

    enum DropPhase {
        case idle
        case selecting([any DropAction], [URL])
        case executing(any DropAction)
        case result(DropActionResult)
    }

    var dropPhase: DropPhase = .idle

    private let builtInActions: [any DropAction] = [
        CompressImageAction(),
        OCRAction()
    ]

    /// Cached combined actions list. Invalidated when custom actions or pipelines change.
    private var cachedAllActions: [any DropAction]?

    /// All available actions: built-in + custom actions + pipelines loaded from UserDefaults.
    var allActions: [any DropAction] {
        if let cached = cachedAllActions { return cached }
        var actions: [any DropAction] = builtInActions
        let customActions = CustomDropActionStore.load()
        actions.append(contentsOf: customActions.map { $0.toDropAction() })
        let pipelines = PipelineStore.load()
        actions.append(contentsOf: pipelines.map { PipelineDropAction(pipeline: $0) })
        cachedAllActions = actions
        return actions
    }

    /// Invalidate cached actions (call when custom actions or pipelines are modified).
    func invalidateActionsCache() {
        cachedAllActions = nil
    }

    /// Find matching actions for dropped files and start selection.
    func handleDrop(urls: [URL]) {
        let matching = allActions.filter { action in
            urls.contains { action.canHandle(url: $0) }
        }

        if matching.isEmpty {
            dropPhase = .result(DropActionResult(success: false, message: "No actions for this file type"))
            scheduleDismiss()
            return
        }

        if matching.count == 1 {
            // Single match — execute immediately
            executeAction(matching[0], urls: urls)
        } else {
            // Multiple matches — show selection UI
            dropPhase = .selecting(matching, urls)
        }
    }

    /// Execute the selected action.
    func executeAction(_ action: any DropAction, urls: [URL]) {
        dropPhase = .executing(action)

        Task { @MainActor in
            do {
                let result = try await action.execute(urls: urls)
                dropPhase = .result(result)
            } catch {
                dropPhase = .result(DropActionResult(success: false, message: "Error: \(error.localizedDescription)"))
            }
            scheduleDismiss()
        }
    }

    /// Reset to idle.
    func reset() {
        dropPhase = .idle
    }

    private var dismissWorkItem: DispatchWorkItem?

    private func scheduleDismiss() {
        dismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onDismissAfterResult?()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    /// Callback invoked when result auto-dismisses.
    var onDismissAfterResult: (() -> Void)?
}
