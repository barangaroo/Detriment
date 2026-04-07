#!/usr/bin/env swift
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

// Background — dark gradient
let bgRect = NSRect(origin: .zero, size: size)
let gradient = NSGradient(colors: [
    NSColor(red: 0.08, green: 0.02, blue: 0.02, alpha: 1.0),
    NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
])!
gradient.draw(in: bgRect, angle: -90)

// Shield shape — centered
let ctx = NSGraphicsContext.current!.cgContext

let centerX: CGFloat = 512
let centerY: CGFloat = 520

// Draw shield path
let shieldPath = NSBezierPath()
let shieldW: CGFloat = 420
let shieldH: CGFloat = 500
let topY = centerY + shieldH * 0.45
let bottomY = centerY - shieldH * 0.55
let midY = centerY - shieldH * 0.1

shieldPath.move(to: NSPoint(x: centerX, y: topY))
shieldPath.curve(to: NSPoint(x: centerX + shieldW / 2, y: midY + 120),
                 controlPoint1: NSPoint(x: centerX + shieldW * 0.15, y: topY),
                 controlPoint2: NSPoint(x: centerX + shieldW / 2, y: topY - 40))
shieldPath.line(to: NSPoint(x: centerX + shieldW / 2, y: midY))
shieldPath.curve(to: NSPoint(x: centerX, y: bottomY),
                 controlPoint1: NSPoint(x: centerX + shieldW / 2, y: midY - 160),
                 controlPoint2: NSPoint(x: centerX + 60, y: bottomY + 40))
shieldPath.curve(to: NSPoint(x: centerX - shieldW / 2, y: midY),
                 controlPoint1: NSPoint(x: centerX - 60, y: bottomY + 40),
                 controlPoint2: NSPoint(x: centerX - shieldW / 2, y: midY - 160))
shieldPath.line(to: NSPoint(x: centerX - shieldW / 2, y: midY + 120))
shieldPath.curve(to: NSPoint(x: centerX, y: topY),
                 controlPoint1: NSPoint(x: centerX - shieldW / 2, y: topY - 40),
                 controlPoint2: NSPoint(x: centerX - shieldW * 0.15, y: topY))
shieldPath.close()

// Shield fill — left half red, right half dark
ctx.saveGState()
shieldPath.addClip()

// Left half — red
let leftRect = NSRect(x: 0, y: 0, width: 512, height: 1024)
NSColor(red: 0.9, green: 0.15, blue: 0.12, alpha: 1.0).setFill()
leftRect.fill()

// Right half — very dark red
let rightRect = NSRect(x: 512, y: 0, width: 512, height: 1024)
NSColor(red: 0.35, green: 0.06, blue: 0.05, alpha: 1.0).setFill()
rightRect.fill()

ctx.restoreGState()

// Shield outline glow
NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 0.5).setStroke()
shieldPath.lineWidth = 4
shieldPath.stroke()

// WiFi exclamation icon — draw 3 arcs + dot
let wifiCenterX: CGFloat = 512
let wifiCenterY: CGFloat = 440
let arcColor = NSColor.white

// Arc radii
let radii: [CGFloat] = [80, 140, 200]
arcColor.setStroke()

for (i, radius) in radii.enumerated() {
    let arc = NSBezierPath()
    let startAngle: CGFloat = 45
    let endAngle: CGFloat = 135
    arc.appendArc(withCenter: NSPoint(x: wifiCenterX, y: wifiCenterY),
                  radius: radius,
                  startAngle: startAngle,
                  endAngle: endAngle)
    arc.lineWidth = CGFloat(28 - i * 4)
    arc.lineCapStyle = .round
    arc.stroke()
}

// Exclamation mark below arcs
let exclX: CGFloat = 512
let exclTopY: CGFloat = 440
let exclBottomY: CGFloat = 320

// Line
let exclLine = NSBezierPath()
exclLine.move(to: NSPoint(x: exclX, y: exclTopY))
exclLine.line(to: NSPoint(x: exclX, y: exclBottomY))
exclLine.lineWidth = 28
exclLine.lineCapStyle = .round
NSColor.white.setStroke()
exclLine.stroke()

// Dot
let dotSize: CGFloat = 30
let dot = NSBezierPath(ovalIn: NSRect(
    x: exclX - dotSize / 2,
    y: exclBottomY - 60 - dotSize / 2,
    width: dotSize,
    height: dotSize
))
NSColor.white.setFill()
dot.fill()

image.unlockFocus()

// Save as PNG
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to generate PNG")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Generated icon at \(outputPath)")
