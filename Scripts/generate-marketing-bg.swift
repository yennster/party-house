#!/usr/bin/env swift
// Generates the shared marketing-screenshot background (dark party gradient with
// soft glows, matching the app's look). Output: Marketing/background.png
// Run: swift Scripts/generate-marketing-bg.swift

import AppKit
import CoreGraphics

let width = 2200
let height = 3000
let scriptDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot = scriptDirectory.deletingLastPathComponent()
let output = repoRoot.appendingPathComponent("Marketing/background.png")

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

let rect = CGRect(x: 0, y: 0, width: width, height: height)

// Deep night base.
let base = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [color(0x17091f), color(0x1d0f33), color(0x0b0a18)] as CFArray,
    locations: [0.0, 0.5, 1.0]
)!
ctx.drawLinearGradient(
    base,
    start: CGPoint(x: 0, y: rect.maxY),
    end: CGPoint(x: rect.maxX, y: 0),
    options: []
)

// Party glows.
func glow(_ hex: UInt32, x: CGFloat, y: CGFloat, radius: CGFloat, alpha: CGFloat) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [color(hex, alpha: alpha), color(hex, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    let center = CGPoint(x: rect.width * x, y: rect.height * y)
    ctx.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: []
    )
}

glow(0xff2e93, x: 0.15, y: 0.85, radius: 1300, alpha: 0.34)
glow(0x7b2cbf, x: 0.85, y: 0.62, radius: 1400, alpha: 0.30)
glow(0x00bbf9, x: 0.30, y: 0.18, radius: 1200, alpha: 0.22)
glow(0xffd166, x: 0.88, y: 0.10, radius: 800, alpha: 0.12)

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
rep.size = NSSize(width: width, height: height)
let data = rep.representation(using: .png, properties: [:])!
try! FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try! data.write(to: output)
print("wrote \(output.path)")
