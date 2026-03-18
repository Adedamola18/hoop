import AVFoundation
import SwiftUI

struct WebcamWidgetView: View {
    @StateObject private var camera = WebcamManager()

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "web.camera")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Webcam")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if camera.isRunning {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }

            if camera.isAuthorized {
                if let image = camera.currentFrame {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.04))
                        .frame(height: 90)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Camera access required")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(height: 90)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}

final class WebcamManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentFrame: NSImage?
    @Published var isRunning = false
    @Published var isAuthorized = false

    private var session: AVCaptureSession?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    func stop() {
        session?.stopRunning()
        isRunning = false
    }

    private func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "webcam"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = nsImage
        }
    }
}

// MARK: - Widget Conformance

final class WebcamNotchWidget: NotchWidget {
    let id = "webcam"
    let name = "Webcam"
    let icon = "web.camera"
    let size: WidgetSize = .large

    @MainActor
    func makeBody() -> AnyView {
        AnyView(WebcamWidgetView())
    }
}
