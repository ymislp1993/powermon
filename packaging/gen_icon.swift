// gen_icon.swift — 生成 PowerMon 应用图标 1024px（Mac16 风格圆角矩形 + 琥珀色闪电）
// 用法：swift gen_icon.swift  （产物 AppIcon_1024.png，随后由 Makefile 走 sips/iconutil 转 icns）
import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let size = 1024
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// 背景圆角矩形：Big Sur 模板比例（824/1024，圆角约 22.45%）
let inset = CGFloat(100), side = CGFloat(824)
let rect = CGRect(x: inset, y: inset, width: side, height: side)
let radius = side * 0.2245
ctx.setFillColor(CGColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1))
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.fillPath()

// 闪电多边形（坐标按 y 向下书写，绘制时翻转）
let boltPoints: [(Double, Double)] = [
    (0.56, 0.78), (0.40, 0.52), (0.50, 0.52), (0.44, 0.26),
    (0.62, 0.50), (0.52, 0.50), (0.60, 0.78),
]
let bolt = boltPoints.map {
    CGPoint(x: inset + side * CGFloat($0.0), y: inset + side * CGFloat(1 - $0.1))
}
ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.77, blue: 0.10, alpha: 1))
ctx.addLines(between: bolt)
ctx.closePath()
ctx.fillPath()

let img = ctx.makeImage()!
let url = URL(fileURLWithPath: "AppIcon_1024.png") as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("AppIcon_1024.png written")
