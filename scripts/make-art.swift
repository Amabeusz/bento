// Regenerates scripts/AppIcon.icns, docs/icon.png and docs/banner.png: swift scripts/make-art.swift
import AppKit

func hex(_ v: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let sky = hex(0x3d9dff)
let ink = hex(0x111216)
let shades = [sky, hex(0x2b7fdc), hex(0x2063b2), hex(0x174a87)]

func canvas(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    return ctx.makeImage()!
}

func save(_ image: CGImage, _ path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Rect with continuous (superellipse) corners, like Apple's icon shapes.
func smooth(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    let c = min(radius * 1.6, r.width / 2, r.height / 2)
    let path = CGMutablePath()
    let corners = [(CGPoint(x: r.maxX - c, y: r.minY + c), -CGFloat.pi / 2), (CGPoint(x: r.maxX - c, y: r.maxY - c), 0),
                   (CGPoint(x: r.minX + c, y: r.maxY - c), CGFloat.pi / 2), (CGPoint(x: r.minX + c, y: r.minY + c), CGFloat.pi)]
    for (center, start) in corners {
        for step in 0...24 {
            let a = start + CGFloat(step) / 24 * .pi / 2
            let p = CGPoint(x: center.x + c * copysign(pow(abs(cos(a)), 0.5), cos(a)),
                            y: center.y + c * copysign(pow(abs(sin(a)), 0.5), sin(a)))
            if path.isEmpty { path.move(to: p) } else { path.addLine(to: p) }
        }
    }
    path.closeSubpath()
    return path
}

/// Dwindle split of `r`: big cell left, then top-right, then the rest halved side by side.
func dwindle(_ r: CGRect, gap: CGFloat) -> [CGRect] {
    let half = (r.width - gap) / 2
    let left = CGRect(x: r.minX, y: r.minY, width: half, height: r.height)
    let rx = r.minX + half + gap
    let upperH = (r.height - gap) * 0.5
    let top = CGRect(x: rx, y: r.maxY - upperH, width: half, height: upperH)
    let lowH = r.height - upperH - gap
    let quarter = (half - gap) / 2
    let bl = CGRect(x: rx, y: r.minY, width: quarter, height: lowH)
    let br = CGRect(x: rx + quarter + gap, y: r.minY, width: quarter, height: lowH)
    return [left, top, bl, br]
}

/// App icon on Apple's 1024 grid: an 824 pt black box with 100 pt margins, its compartments
/// a dwindle layout in flat blue, drawn at `px` pixels.
func icon(_ px: Int) -> CGImage {
    canvas(px, px) { ctx in
        let k = CGFloat(px) / 1024
        ctx.scaleBy(x: k, y: k)
        let small = px <= 64
        let box = CGRect(x: 100, y: 100, width: 824, height: 824)
        let shape = smooth(box, 185)
        ctx.saveGState()
        if !small { ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: hex(0, 0.45)) }
        ctx.addPath(shape)
        ctx.setFillColor(ink)
        ctx.fillPath()
        ctx.restoreGState()
        let area = box.insetBy(dx: small ? 96 : 104, dy: small ? 96 : 104)
        for (cell, shade) in zip(dwindle(area, gap: small ? 56 : 38), shades) {
            ctx.addPath(smooth(cell, min(64, cell.width * 0.28)))
            ctx.setFillColor(shade)
            ctx.fillPath()
        }
    }
}

func text(_ ctx: CGContext, _ s: String, _ font: NSFont, at p: CGPoint, color: CGColor) {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
        .font: font, .foregroundColor: NSColor(cgColor: color)!,
    ]))
    ctx.textPosition = p
    CTLineDraw(line, ctx)
}

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
}

func banner() -> CGImage {
    canvas(1280, 640) { ctx in
        ctx.setFillColor(hex(0x0b0c0f))
        ctx.fill(CGRect(x: 0, y: 0, width: 1280, height: 640))

        ctx.draw(icon(256), in: CGRect(x: 64, y: 330, width: 176, height: 176))
        text(ctx, "bento", roundedFont(124, .heavy), at: CGPoint(x: 240, y: 370), color: sky)
        text(ctx, "Hyprland-style tiling for macOS,", roundedFont(30, .medium), at: CGPoint(x: 92, y: 262), color: hex(0xe6e8ee))
        text(ctx, "plus handy tools, in one menu bar app.", roundedFont(30, .medium), at: CGPoint(x: 92, y: 222),
             color: hex(0xe6e8ee))
        var x: CGFloat = 92
        for chip in ["dwindle", "10 workspaces", "clipboard", "overview"] {
            let font = roundedFont(19, .semibold)
            let w = (chip as NSString).size(withAttributes: [.font: font]).width + 32
            ctx.addPath(rounded(CGRect(x: x, y: 128, width: w, height: 40), 20))
            ctx.setFillColor(hex(0x1c1e24))
            ctx.fillPath()
            text(ctx, chip, font, at: CGPoint(x: x + 16, y: 141), color: hex(0x9aa0ad))
            x += w + 12
        }

        let screen = CGRect(x: 700, y: 92, width: 520, height: 456)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: hex(0, 0.6))
        ctx.addPath(rounded(screen, 26))
        ctx.setFillColor(ink)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.addPath(rounded(screen.insetBy(dx: 1, dy: 1), 25))
        ctx.setLineWidth(2)
        ctx.setStrokeColor(hex(0x2a2d35))
        ctx.strokePath()

        let island = CGRect(x: screen.midX - 92, y: screen.maxY - 46, width: 184, height: 30)
        ctx.addPath(rounded(island, 15))
        ctx.setFillColor(hex(0x1c1e24))
        ctx.fillPath()
        for (i, n) in ["1", "2", "3", "4"].enumerated() {
            let cell = CGRect(x: island.minX + 6 + CGFloat(i) * 44, y: island.minY + 4, width: 40, height: 22)
            if i == 0 {
                ctx.addPath(rounded(cell, 11))
                ctx.setFillColor(sky)
                ctx.fillPath()
            }
            text(ctx, n, roundedFont(15, .bold), at: CGPoint(x: cell.midX - 4, y: cell.minY + 6),
                 color: i == 0 ? ink : (i == 3 ? hex(0x5a5f6b) : hex(0xe6e8ee)))
        }

        let area = CGRect(x: screen.minX + 18, y: screen.minY + 18, width: screen.width - 36, height: screen.height - 82)
        for (i, cell) in dwindle(area, gap: 14).enumerated() {
            ctx.addPath(rounded(cell, 14))
            ctx.setFillColor(hex(0x1a1c22))
            ctx.fillPath()
            let border: CGFloat = i == 0 ? 4 : 2
            ctx.addPath(rounded(cell.insetBy(dx: border / 2, dy: border / 2), 14 - border / 2))
            ctx.setLineWidth(border)
            ctx.setStrokeColor(i == 0 ? sky : hex(0x2e3139))
            ctx.strokePath()
            let bar = CGRect(x: cell.minX + 14, y: cell.maxY - 24, width: cell.width - 28, height: 8)
            ctx.addPath(rounded(bar, 4))
            ctx.setFillColor(hex(0x2e3139))
            ctx.fillPath()
            var y = bar.minY - 26
            var n = 0
            while y > cell.minY + 14 {
                let w = (cell.width - 28) * [0.82, 0.6, 0.72, 0.45][(n + i) % 4]
                ctx.addPath(rounded(CGRect(x: cell.minX + 14, y: y, width: w, height: 7), 3.5))
                ctx.setFillColor(i == 0 && n % 3 == 0 ? hex(0x3d9dff, 0.6) : hex(0x3a3e48, 0.8))
                ctx.fillPath()
                y -= 20
                n += 1
            }
        }
    }
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent().path
let iconset = NSTemporaryDirectory() + "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    save(icon(pt), "\(iconset)/icon_\(pt)x\(pt).png")
    save(icon(pt * 2), "\(iconset)/icon_\(pt)x\(pt)@2x.png")
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "\(root)/scripts/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
save(icon(512), "\(root)/docs/icon.png")
save(banner(), "\(root)/docs/banner.png")
print("scripts/AppIcon.icns docs/icon.png docs/banner.png")
