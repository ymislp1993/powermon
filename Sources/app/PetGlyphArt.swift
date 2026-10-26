// PetGlyphArt.swift — 手绘 SVG 四态兽（数据驱动版）
// 数据源：设计稿 ui-design-language-v2.html symbol 预解析为绝对坐标指令（python 生成）。
// 渲染时零字符串解析；currentColor = 传入 tint（琥珀/红）；其余为插画固定色。

import SwiftUI

enum GlyphOp {
    case move, line, curve, quad, close, circle
}

struct GlyphCmd {
    let op: GlyphOp
    let pts: [CGFloat]
}

struct GlyphDraw {
    let id: Int
    let isFill: Bool
    let colorKey: String
    let lineWidth: CGFloat
    let cmds: [GlyphCmd]
}

enum PetGlyphArt {
    static let walk: [GlyphDraw] = [
            GlyphDraw(id: 0, isFill: false, colorKey: "currentColor", lineWidth: 1.0, cmds: [
                    .init(op: .move, pts: [9.50, 33.00]),
                    .init(op: .curve, pts: [4.50, 30.50, 3.60, 24.60, 7.20, 21.60]),
                ]),
            GlyphDraw(id: 1, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [12.00, 25.00]),
                    .init(op: .curve, pts: [12.00, 16.00, 18.60, 10.50, 26.00, 10.50]),
                    .init(op: .curve, pts: [33.40, 10.50, 39.00, 15.60, 39.00, 22.50]),
                    .init(op: .line, pts: [39.00, 36.50]),
                    .init(op: .curve, pts: [39.00, 38.40, 37.40, 40.00, 35.50, 40.00]),
                    .init(op: .line, pts: [15.50, 40.00]),
                    .init(op: .curve, pts: [13.60, 40.00, 12.00, 38.40, 12.00, 36.50]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 2, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [22.60, 12.40]),
                    .init(op: .line, pts: [24.60, 4.60]),
                    .init(op: .line, pts: [29.40, 10.90]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 3, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [31.40, 10.70]),
                    .init(op: .line, pts: [34.80, 4.40]),
                    .init(op: .line, pts: [37.60, 11.60]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 4, isFill: true, colorKey: "dark", lineWidth: 0.0, cmds: [
                    .init(op: .circle, pts: [31.80, 19.50, 1.90]),
                ])
    ]

    static let sleep: [GlyphDraw] = [
            GlyphDraw(id: 0, isFill: true, colorKey: "dark", lineWidth: 0.0, cmds: [
                    .init(op: .circle, pts: [23.00, 28.50, 12.50]),
                ]),
            GlyphDraw(id: 1, isFill: false, colorKey: "currentColor", lineWidth: 1.0, cmds: [
                    .init(op: .move, pts: [34.50, 35.50]),
                    .init(op: .curve, pts: [40.00, 32.50, 40.50, 25.00, 36.00, 21.50]),
                ]),
            GlyphDraw(id: 2, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [27.50, 17.50]),
                    .init(op: .line, pts: [28.80, 11.40]),
                    .init(op: .line, pts: [33.00, 16.40]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 3, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [18.60, 18.60]),
                    .init(op: .line, pts: [18.40, 12.30]),
                    .init(op: .line, pts: [23.40, 16.30]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 4, isFill: false, colorKey: "#3F2C06", lineWidth: 1.0, cmds: [
                    .init(op: .move, pts: [27.50, 27.50]),
                    .init(op: .quad, pts: [29.70, 29.50, 31.90, 27.50]),
                ])
    ]

    static let run: [GlyphDraw] = [
            GlyphDraw(id: 0, isFill: false, colorKey: "#C79112", lineWidth: 1.0, cmds: [
                    .init(op: .move, pts: [2.50, 21.00]),
                    .init(op: .line, pts: [7.00, 21.00]),
                    .init(op: .move, pts: [1.50, 27.00]),
                    .init(op: .line, pts: [7.50, 27.00]),
                ]),
            GlyphDraw(id: 1, isFill: false, colorKey: "currentColor", lineWidth: 1.0, cmds: [
                    .init(op: .move, pts: [11.50, 31.00]),
                    .init(op: .curve, pts: [7.50, 25.50, 8.50, 18.00, 13.50, 13.50]),
                ]),
            GlyphDraw(id: 2, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [12.00, 25.00]),
                    .init(op: .curve, pts: [12.00, 16.00, 18.60, 10.50, 26.00, 10.50]),
                    .init(op: .curve, pts: [33.40, 10.50, 39.00, 15.60, 39.00, 22.50]),
                    .init(op: .line, pts: [39.00, 36.50]),
                    .init(op: .curve, pts: [39.00, 38.40, 37.40, 40.00, 35.50, 40.00]),
                    .init(op: .line, pts: [15.50, 40.00]),
                    .init(op: .curve, pts: [13.60, 40.00, 12.00, 38.40, 12.00, 36.50]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 3, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [22.60, 12.40]),
                    .init(op: .line, pts: [24.60, 4.60]),
                    .init(op: .line, pts: [29.40, 10.90]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 4, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [31.40, 10.70]),
                    .init(op: .line, pts: [34.80, 4.40]),
                    .init(op: .line, pts: [37.60, 11.60]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 5, isFill: true, colorKey: "dark", lineWidth: 0.0, cmds: [
                    .init(op: .circle, pts: [31.80, 19.50, 1.90]),
                ])
    ]

    static let pant: [GlyphDraw] = [
            GlyphDraw(id: 0, isFill: false, colorKey: "currentColor", lineWidth: 1.0, cmds: [
                    .init(op: .move, pts: [9.50, 33.00]),
                    .init(op: .curve, pts: [4.50, 30.50, 3.60, 24.60, 7.20, 21.60]),
                ]),
            GlyphDraw(id: 1, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [12.00, 25.00]),
                    .init(op: .curve, pts: [12.00, 16.00, 18.60, 10.50, 26.00, 10.50]),
                    .init(op: .curve, pts: [33.40, 10.50, 39.00, 15.60, 39.00, 22.50]),
                    .init(op: .line, pts: [39.00, 36.50]),
                    .init(op: .curve, pts: [39.00, 38.40, 37.40, 40.00, 35.50, 40.00]),
                    .init(op: .line, pts: [15.50, 40.00]),
                    .init(op: .curve, pts: [13.60, 40.00, 12.00, 38.40, 12.00, 36.50]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 2, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [22.60, 12.40]),
                    .init(op: .line, pts: [24.60, 4.60]),
                    .init(op: .line, pts: [29.40, 10.90]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 3, isFill: true, colorKey: "currentColor", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [31.40, 10.70]),
                    .init(op: .line, pts: [34.80, 4.40]),
                    .init(op: .line, pts: [37.60, 11.60]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 4, isFill: true, colorKey: "dark", lineWidth: 0.0, cmds: [
                    .init(op: .circle, pts: [32.00, 18.00, 1.90]),
                ]),
            GlyphDraw(id: 5, isFill: true, colorKey: "#8E231D", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [30.60, 24.60]),
                    .init(op: .line, pts: [38.40, 23.40]),
                    .init(op: .line, pts: [35.60, 30.20]),
                    .init(op: .close, pts: []),
                ]),
            GlyphDraw(id: 6, isFill: false, colorKey: "#FF8A80", lineWidth: 1.0, cmds: [
                    .init(op: .move, pts: [33.20, 27.40]),
                    .init(op: .quad, pts: [35.00, 30.40, 37.50, 29.00]),
                ]),
            GlyphDraw(id: 7, isFill: true, colorKey: "#6FB6FF", lineWidth: 0.0, cmds: [
                    .init(op: .move, pts: [43.50, 12.50]),
                    .init(op: .curve, pts: [45.30, 15.20, 45.30, 17.30, 43.50, 18.30]),
                    .init(op: .curve, pts: [41.70, 17.30, 41.70, 15.20, 43.50, 12.50]),
                    .init(op: .close, pts: []),
                ])
    ]

    static func draws(for state: PetState) -> [GlyphDraw] {
        switch state {
        case .walk: return walk
        case .sleep: return sleep
        case .run: return run
        case .pant: return pant
        }
    }
}

/// 单条绘制指令的渲染（fill 或 stroke）
struct GlyphDrawView: View {
    let draw: GlyphDraw
    let tint: Color
    let isHot: Bool

    var color: Color {
        switch draw.colorKey {
        case "tint": return isHot ? PM.alert : tint
        case "amberDeep": return PM.amberDeep
        case "dark": return Color(red: 0.25, green: 0.17, blue: 0.02)
        case "alertDim": return PM.alert.opacity(0.75)
        case "alertDeep": return PM.alert.opacity(0.8)
        case "alertLight": return PM.alert.opacity(0.9)
        case "drop": return Color(red: 0.435, green: 0.714, blue: 1.000)
        default: return PM.text3
        }
    }

    var body: some View {
        GlyphShape(cmds: draw.cmds)
            .apply { s in
                if draw.isFill {
                    AnyView(s.fill(color))
                } else {
                    AnyView(s.stroke(color, style: StrokeStyle(lineWidth: draw.lineWidth, lineCap: .round, lineJoin: .round)))
                }
            }
    }
}

/// 四态兽视图（数据驱动渲染）
struct PetArtView: View {
    let state: PetState
    var height: CGFloat = 40
    var tint: Color
    var isHot: Bool = false

    var body: some View {
        let draws = PetGlyphArt.draws(for: state)
        ZStack {
            ForEach(Array(draws.enumerated()), id: \.offset) { _, d in
                GlyphDrawView(draw: d, tint: tint, isHot: isHot)
            }
            if state == .sleep {
                Text("zZ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PM.amberDeep)
                    .offset(x: 34, y: 4)
            }
        }
        .frame(width: height * 1.2, height: height, alignment: .topLeading)
        .scaleEffect(height / 40, anchor: .topLeading)
    }
}

private extension Shape {
    func apply(_ transform: (Self) -> AnyView) -> AnyView {
        transform(self)
    }
}

/// GlyphShape：48×48 设计坐标 → 渲染矩形
struct GlyphShape: Shape {
    let cmds: [GlyphCmd]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let sx = rect.width / 48, sy = rect.height / 48
        var cur = CGPoint.zero
        for c in cmds {
            let v = c.pts
            switch c.op {
            case .move:
                cur = CGPoint(x: v[0] * sx, y: v[1] * sy); p.move(to: cur)
            case .line:
                cur = CGPoint(x: v[0] * sx, y: v[1] * sy); p.addLine(to: cur)
            case .curve:
                let to = CGPoint(x: v[4] * sx, y: v[5] * sy)
                let c1 = CGPoint(x: v[0] * sx, y: v[1] * sy)
                let c2 = CGPoint(x: v[2] * sx, y: v[3] * sy)
                cur = to; p.addCurve(to: to, control1: c1, control2: c2)
            case .quad:
                let to = CGPoint(x: v[2] * sx, y: v[3] * sy)
                let ctl = CGPoint(x: v[0] * sx, y: v[1] * sy)
                cur = to; p.addQuadCurve(to: to, control: ctl)
            case .close:
                p.closeSubpath()
            case .circle:
                let cx = v[0] * sx, cy = v[1] * sy, r = v[2] * sx
                p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }
        }
        return p
    }
}
