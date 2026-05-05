#!/usr/bin/env swift

// Renders the Hoop app icon as PNGs at the macOS AppIcon sizes.
// Mirrors the visual style of `HoopLogo` in SettingsView.swift but on a
// dark squircle background suitable for the macOS app icon grid.
//
// Run:  swift scripts/generate-app-icon.swift
// Output: Hoop/Assets.xcassets/AppIcon.appiconset/icon_<px>.png

import AppKit
import Foundation

// MARK: - Sizes (point-size, scale, output pixels)

let icons: [(point: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

let outputDir = "Hoop/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// MARK: - Drawing

/// Draws the Hoop icon at the given pixel size into a CGContext.
func drawIcon(into ctx: CGContext, size: CGFloat) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // 1. Squircle background — near-black with a subtle radial highlight.
    let bgRadius = size * 0.225 // macOS HIG continuous corner ratio
    let bgPath = CGPath(roundedRect: rect, cornerWidth: bgRadius, cornerHeight: bgRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let bgGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(red: 0.066, green: 0.106, blue: 0.184, alpha: 1).cgColor,
            NSColor(red: 0.012, green: 0.024, blue: 0.055, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        bgGradient,
        startCenter: CGPoint(x: size * 0.4, y: size * 0.65),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.5, y: size * 0.5),
        endRadius: size * 0.75,
        options: []
    )
    ctx.restoreGState()

    // 2. Outer ring — angular gradient (approximated as multi-stop conic).
    let ringInset = size * 0.18
    let ringRect = rect.insetBy(dx: ringInset, dy: ringInset)
    let ringWidth = size * 0.075
    let ringCenter = CGPoint(x: rect.midX, y: rect.midY)
    let ringRadius = ringRect.width / 2

    // Glow — wider, softer ring underneath.
    ctx.saveGState()
    ctx.setLineWidth(ringWidth * 1.5)
    ctx.setStrokeColor(NSColor(red: 0.45, green: 0.4, blue: 0.95, alpha: 0.35).cgColor)
    ctx.addArc(center: ringCenter, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // Main ring drawn as multiple short arcs with interpolated colors so it
    // visually approximates an angular gradient.
    let ringColors: [NSColor] = [
        NSColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 1.0),
        NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0),
    ]
    let segments = 360
    ctx.saveGState()
    ctx.setLineWidth(ringWidth)
    ctx.setLineCap(.butt)
    for i in 0..<segments {
        let t0 = Double(i) / Double(segments)
        let t1 = Double(i + 1) / Double(segments)
        let a0 = t0 * .pi * 2 - .pi / 2
        let a1 = t1 * .pi * 2 - .pi / 2
        let color = interpolatedColor(at: t0, stops: ringColors)
        ctx.setStrokeColor(color.cgColor)
        ctx.addArc(center: ringCenter, radius: ringRadius, startAngle: a0, endAngle: a1, clockwise: false)
        ctx.strokePath()
    }
    ctx.restoreGState()

    // 3. Inner highlight — thin white circle just inside the ring.
    ctx.saveGState()
    ctx.setLineWidth(max(1, size * 0.005))
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
    ctx.addArc(center: ringCenter, radius: ringRadius - ringWidth * 0.55, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Center notch hint — rounded rectangle with vertical gradient,
    //    sitting near the top center of the ring (matches HoopLogo's offset).
    let notchWidth = size * 0.30
    let notchHeight = size * 0.13
    let notchRect = CGRect(
        x: rect.midX - notchWidth / 2,
        y: rect.midY - notchHeight / 2 + size * 0.025,
        width: notchWidth,
        height: notchHeight
    )
    let notchPath = CGPath(roundedRect: notchRect, cornerWidth: size * 0.04, cornerHeight: size * 0.04, transform: nil)
    ctx.saveGState()
    ctx.addPath(notchPath)
    ctx.clip()
    let notchGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 0.65).cgColor,
            NSColor(red: 0.30, green: 0.40, blue: 0.85, alpha: 0.30).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        notchGradient,
        start: CGPoint(x: notchRect.midX, y: notchRect.maxY),
        end: CGPoint(x: notchRect.midX, y: notchRect.minY),
        options: []
    )
    ctx.restoreGState()
}

/// Linearly interpolate between an array of color stops at position t in [0,1].
func interpolatedColor(at t: Double, stops: [NSColor]) -> NSColor {
    guard stops.count > 1 else { return stops.first ?? .white }
    let scaled = t * Double(stops.count - 1)
    let i = Int(scaled.rounded(.down))
    let f = scaled - Double(i)
    let c0 = stops[i]
    let c1 = stops[min(i + 1, stops.count - 1)]
    return blend(c0, c1, t: CGFloat(f))
}

func blend(_ a: NSColor, _ b: NSColor, t: CGFloat) -> NSColor {
    let ca = a.usingColorSpace(.sRGB)!
    let cb = b.usingColorSpace(.sRGB)!
    return NSColor(
        red: ca.redComponent + (cb.redComponent - ca.redComponent) * t,
        green: ca.greenComponent + (cb.greenComponent - ca.greenComponent) * t,
        blue: ca.blueComponent + (cb.blueComponent - ca.blueComponent) * t,
        alpha: ca.alphaComponent + (cb.alphaComponent - ca.alphaComponent) * t
    )
}

// MARK: - Render and save

func renderPNG(pixelSize: Int, to path: String) {
    let size = CGFloat(pixelSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext")
    }

    drawIcon(into: ctx, size: size)

    guard let image = ctx.makeImage() else {
        fatalError("Failed to create CGImage")
    }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG")
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

// MARK: - Generate

var manifestImages: [[String: String]] = []

for (point, scale) in icons {
    let pixels = point * scale
    let filename = "icon_\(point)x\(point)@\(scale)x.png"
    let path = "\(outputDir)/\(filename)"
    renderPNG(pixelSize: pixels, to: path)
    print("Wrote \(path) (\(pixels)x\(pixels))")
    manifestImages.append([
        "size": "\(point)x\(point)",
        "idiom": "mac",
        "filename": filename,
        "scale": "\(scale)x",
    ])
}

// Write Contents.json
let manifest: [String: Any] = [
    "images": manifestImages,
    "info": ["version": 1, "author": "xcode"],
]
let manifestData = try! JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try! manifestData.write(to: URL(fileURLWithPath: "\(outputDir)/Contents.json"))
print("Wrote \(outputDir)/Contents.json")
