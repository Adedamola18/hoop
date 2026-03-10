import AppKit
import SwiftUI

struct ColorPickerWidgetView: View {
    @State private var pickedColor: NSColor?
    @State private var colorHistory: [NSColor] = []
    @State private var isPicking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "eyedropper")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Color Picker")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button {
                    pickColor()
                } label: {
                    Label("Pick", systemImage: "eyedropper.halffull")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            if let color = pickedColor {
                colorDetail(color)
            }

            if !colorHistory.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(colorHistory.prefix(10).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(Color(nsColor: color))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                            .onTapGesture {
                                copyHex(color)
                            }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    private func colorDetail(_ color: NSColor) -> some View {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let hex = String(format: "#%02X%02X%02X",
                         Int(rgb.redComponent * 255),
                         Int(rgb.greenComponent * 255),
                         Int(rgb.blueComponent * 255))
        let rgbStr = String(format: "rgb(%d, %d, %d)",
                            Int(rgb.redComponent * 255),
                            Int(rgb.greenComponent * 255),
                            Int(rgb.blueComponent * 255))

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: color))
                .frame(width: 32, height: 32)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 2) {
                copyableText(hex)
                copyableText(rgbStr)
            }
        }
    }

    private func copyableText(_ text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            HStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
    }

    private func pickColor() {
        NSColorSampler().show { color in
            if let color {
                pickedColor = color
                colorHistory.insert(color, at: 0)
                if colorHistory.count > 10 {
                    colorHistory.removeLast()
                }
            }
        }
    }

    private func copyHex(_ color: NSColor) {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let hex = String(format: "#%02X%02X%02X",
                         Int(rgb.redComponent * 255),
                         Int(rgb.greenComponent * 255),
                         Int(rgb.blueComponent * 255))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
        pickedColor = color
    }
}

// MARK: - Widget Conformance

final class ColorPickerNotchWidget: NotchWidget {
    let id = "colorpicker"
    let name = "Color Picker"
    let icon = "eyedropper"
    let size: WidgetSize = .large

    @MainActor
    func makeBody() -> AnyView {
        AnyView(ColorPickerWidgetView())
    }
}
