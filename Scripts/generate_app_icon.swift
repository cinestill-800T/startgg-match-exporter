#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let outputs: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}

func strokeLine(
    _ context: CGContext,
    _ points: [CGPoint],
    color: CGColor,
    width: CGFloat
) {
    guard let first = points.first else { return }
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.beginPath()
    context.move(to: first)
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.strokePath()
}

func strokeArrow(
    _ context: CGContext,
    from: CGPoint,
    to: CGPoint,
    color: CGColor,
    width: CGFloat
) {
    strokeLine(context, [from, to], color: color, width: width)
    strokeLine(
        context,
        [
            CGPoint(x: to.x - 66, y: to.y + 60),
            to,
            CGPoint(x: to.x - 66, y: to.y - 60),
        ],
        color: color,
        width: width
    )
}

func drawIcon(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "Icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create CGContext"])
    }

    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(rect(0, 0, 1024, 1024))

    let tile = rect(104, 88, 816, 816)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -24), blur: 42, color: CGColor(gray: 0, alpha: 0.13))
    context.setFillColor(rgb(252, 252, 250))
    context.addPath(CGPath(roundedRect: tile, cornerWidth: 188, cornerHeight: 188, transform: nil))
    context.fillPath()
    context.restoreGState()

    context.setStrokeColor(rgb(230, 233, 238))
    context.setLineWidth(6)
    context.addPath(CGPath(roundedRect: tile.insetBy(dx: 18, dy: 18), cornerWidth: 170, cornerHeight: 170, transform: nil))
    context.strokePath()

    context.setStrokeColor(rgb(43, 105, 226, 0.16))
    context.setLineWidth(18)
    context.addPath(CGPath(roundedRect: tile.insetBy(dx: 48, dy: 48), cornerWidth: 140, cornerHeight: 140, transform: nil))
    context.strokePath()

    let ink = rgb(32, 37, 46)
    let muted = rgb(150, 158, 170)
    let blue = rgb(43, 105, 226)

    let document = rect(310, 250, 314, 500)
    context.setStrokeColor(ink)
    context.setLineWidth(34)
    context.setLineJoin(.round)
    context.addPath(CGPath(roundedRect: document, cornerWidth: 42, cornerHeight: 42, transform: nil))
    context.strokePath()

    strokeLine(context, [CGPoint(x: 382, y: 388), CGPoint(x: 512, y: 388)], color: muted, width: 22)
    strokeLine(context, [CGPoint(x: 382, y: 462), CGPoint(x: 552, y: 462)], color: muted, width: 22)
    strokeLine(context, [CGPoint(x: 382, y: 536), CGPoint(x: 492, y: 536)], color: muted, width: 22)

    strokeLine(
        context,
        [
            CGPoint(x: 398, y: 642),
            CGPoint(x: 454, y: 642),
            CGPoint(x: 454, y: 690),
            CGPoint(x: 526, y: 690),
        ],
        color: ink,
        width: 28
    )

    for point in [CGPoint(x: 398, y: 642), CGPoint(x: 526, y: 690)] {
        let node = rect(point.x - 22, point.y - 22, 44, 44)
        context.setFillColor(rgb(252, 252, 250))
        context.fillEllipse(in: node)
        context.setStrokeColor(ink)
        context.setLineWidth(18)
        context.strokeEllipse(in: node)
    }

    strokeLine(
        context,
        [
            CGPoint(x: 626, y: 432),
            CGPoint(x: 626, y: 354),
            CGPoint(x: 776, y: 354),
            CGPoint(x: 776, y: 432),
        ],
        color: ink,
        width: 30
    )

    strokeArrow(context, from: CGPoint(x: 560, y: 488), to: CGPoint(x: 746, y: 488), color: blue, width: 32)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    return data
}

for output in outputs {
    let data = try drawIcon(size: output.size)
    try data.write(to: iconset.appendingPathComponent(output.name))
}

print("Wrote \(outputs.count) icon PNGs to \(iconset.path)")
