#!/usr/bin/env swift
// Generates the Party House app icon in all appearances:
//   iOS:   AppIcon-1024.png (light), AppIcon-1024-dark.png, AppIcon-1024-tinted.png
//   macOS: AppIcon-*.png size set (full bleed; Tahoe applies its own glass mask)
// Pure CoreGraphics — run `swift Scripts/generate-icon.swift` from the repo root.

import AppKit
import CoreGraphics

let size = 1024
let scriptDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot = scriptDirectory.deletingLastPathComponent()

/// App Store icons must be fully opaque (no alpha channel); only the tinted
/// variant and the macOS squircle set are allowed transparency.
func makeContext(opaque: Bool = false) -> CGContext {
    CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue
    )!
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

/// The white glyph layer: glow, house silhouette, and disco sparkles. The door is
/// punched to transparency when allowed, or filled dark for opaque icons.
func drawForeground(in ctx: CGContext, rect: CGRect, withGlow: Bool = true, punchDoor: Bool = true) {
    if withGlow {
        let glow = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            colors: [color(0xffffff, alpha: 0.55), color(0xffffff, alpha: 0.0)] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.04),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.04),
            endRadius: rect.width * 0.42,
            options: []
        )
    }

    let w = rect.width
    let h = rect.height
    let house = CGMutablePath()
    let baseY = rect.minY + h * 0.26
    let bodyW = w * 0.42
    let bodyH = h * 0.26
    let bodyX = rect.midX - bodyW / 2
    let roofPeakY = baseY + bodyH + h * 0.16

    house.move(to: CGPoint(x: bodyX, y: baseY))
    house.addLine(to: CGPoint(x: bodyX + bodyW, y: baseY))
    house.addLine(to: CGPoint(x: bodyX + bodyW, y: baseY + bodyH))
    house.addLine(to: CGPoint(x: rect.midX + w * 0.27, y: baseY + bodyH))
    house.addLine(to: CGPoint(x: rect.midX, y: roofPeakY))
    house.addLine(to: CGPoint(x: rect.midX - w * 0.27, y: baseY + bodyH))
    house.addLine(to: CGPoint(x: bodyX, y: baseY + bodyH))
    house.closeSubpath()

    ctx.setFillColor(color(0xffffff))
    ctx.addPath(house)
    ctx.fillPath()

    // Door — punched out where transparency is allowed, filled dark otherwise.
    let doorW = w * 0.10
    let doorH = h * 0.13
    let doorRect = CGRect(x: rect.midX - doorW / 2, y: baseY, width: doorW, height: doorH)
    if punchDoor {
        ctx.setBlendMode(.clear)
    } else {
        ctx.setFillColor(color(0x2b1a52))
    }
    ctx.addPath(CGPath(roundedRect: doorRect, cornerWidth: doorW * 0.45, cornerHeight: doorW * 0.45, transform: nil))
    ctx.fillPath()
    ctx.setBlendMode(.normal)
    ctx.setFillColor(color(0xffffff))

    // Disco sparkles.
    ctx.setFillColor(color(0xffffff, alpha: 0.95))
    let sparkles: [(CGFloat, CGFloat, CGFloat)] = [
        (0.23, 0.78, 0.020), (0.79, 0.82, 0.026), (0.69, 0.66, 0.014),
        (0.30, 0.62, 0.012), (0.17, 0.40, 0.016), (0.84, 0.42, 0.018),
    ]
    for (fx, fy, fr) in sparkles {
        let r = w * fr
        ctx.fillEllipse(in: CGRect(
            x: rect.minX + w * fx - r,
            y: rect.minY + h * fy - r,
            width: r * 2,
            height: r * 2
        ))
    }
}

func drawBackground(in ctx: CGContext, rect: CGRect, colors: [CGColor]) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: colors as CFArray,
        locations: [0.0, 0.55, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed for \(url.path)")
    }
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
    print("wrote \(url.path)")
}

func resized(_ image: CGImage, to pixel: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: pixel, height: pixel,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixel, height: pixel))
    return ctx.makeImage()!
}

let fullRect = CGRect(x: 0, y: 0, width: size, height: size)
let iosSet = repoRoot.appendingPathComponent("Apps/iOS/Assets.xcassets/AppIcon.appiconset")

// Light (default): the party gradient. Fully opaque — App Store requirement.
let lightCtx = makeContext(opaque: true)
drawBackground(in: lightCtx, rect: fullRect, colors: [color(0xff2e93), color(0x7b2cbf), color(0x2b1a78)])
drawForeground(in: lightCtx, rect: fullRect, punchDoor: false)
let lightIcon = lightCtx.makeImage()!
writePNG(lightIcon, to: iosSet.appendingPathComponent("AppIcon-1024.png"))

// Dark appearance: same glyph over a deep night gradient.
let darkCtx = makeContext(opaque: true)
drawBackground(in: darkCtx, rect: fullRect, colors: [color(0x48103f), color(0x271055), color(0x100b26)])
drawForeground(in: darkCtx, rect: fullRect, punchDoor: false)
writePNG(darkCtx.makeImage()!, to: iosSet.appendingPathComponent("AppIcon-1024-dark.png"))

// Tinted/clear appearance: grayscale glyph on transparency — the system supplies
// the glass backdrop and the user's tint.
let tintedCtx = makeContext()
drawForeground(in: tintedCtx, rect: fullRect, withGlow: false)
writePNG(tintedCtx.makeImage()!, to: iosSet.appendingPathComponent("AppIcon-1024-tinted.png"))

// macOS: artwork pre-masked to the Tahoe squircle at FULL canvas size (zero
// margin), so the icon fills its Dock tile instead of floating in the
// compatibility tray with gaps.
let macCtx = makeContext()
let squircle = CGPath(
    roundedRect: fullRect,
    cornerWidth: fullRect.width * 0.2256,
    cornerHeight: fullRect.width * 0.2256,
    transform: nil
)
macCtx.addPath(squircle)
macCtx.clip()
drawBackground(in: macCtx, rect: fullRect, colors: [color(0xff2e93), color(0x7b2cbf), color(0x2b1a78)])
drawForeground(in: macCtx, rect: fullRect)
let macIcon = macCtx.makeImage()!

let macSet = repoRoot.appendingPathComponent("Apps/macOS/Assets.xcassets/AppIcon.appiconset")
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = points * scale
    writePNG(resized(macIcon, to: pixels), to: macSet.appendingPathComponent("AppIcon-\(points)@\(scale)x.png"))
}

print("done")
