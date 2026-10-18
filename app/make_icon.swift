import AppKit

// 生成 1024×1024 的 app 图标：蓝色渐变圆角底 + 三个叠放的窗口 + 播放三角
let px = 1024.0
let img = NSImage(size: NSSize(width: px, height: px))
img.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
ctx.setAllowsAntialiasing(true)
ctx.interpolationQuality = .high

// 背景
let inset = 88.0
let bgRect = NSRect(x: inset, y: inset, width: px - inset * 2, height: px - inset * 2)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: 196, yRadius: 196)
let grad = NSGradient(colors: [
    NSColor(srgbRed: 0.18, green: 0.42, blue: 0.96, alpha: 1),
    NSColor(srgbRed: 0.07, green: 0.13, blue: 0.38, alpha: 1),
])!
grad.draw(in: bg, angle: -55)

// 柔和高光
NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 180, y: 560, width: 700, height: 520)).fill()

// 三个叠放的窗口
let winW = 430.0, winH = 300.0
let offsets: [(Double, Double, Double)] = [(0, 0, 0.32), (58, 58, 0.55), (116, 116, 0.95)]
for (dx, dy, alpha) in offsets {
    let r = NSRect(x: 206 + dx, y: 214 + dy, width: winW, height: winH)
    let p = NSBezierPath(roundedRect: r, xRadius: 46, yRadius: 46)
    NSColor.white.withAlphaComponent(alpha).setFill()
    p.fill()
}

// 最上层窗口里画播放三角
let tri = NSBezierPath()
let cx = 206 + 116 + winW / 2 + 14, cy = 214 + 116 + winH / 2
tri.move(to: NSPoint(x: cx - 62, y: cy + 82))
tri.line(to: NSPoint(x: cx - 62, y: cy - 82))
tri.line(to: NSPoint(x: cx + 82, y: cy))
tri.close()
let blue = NSColor(srgbRed: 0.12, green: 0.30, blue: 0.85, alpha: 1)
blue.setFill()
tri.fill()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
try? png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
