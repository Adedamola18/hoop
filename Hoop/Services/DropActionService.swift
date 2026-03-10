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

    /// Find matching actions for dropped files and start selection.
    func handleDrop(urls: [URL]) {
        let matching = builtInActions.filter { action in
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
