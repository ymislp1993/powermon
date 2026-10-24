// SparklineView.swift — 迷你趋势曲线（SPEC F5）
// 10s 一个点；nil 断线（采样失败段不画）；y 轴 0 到峰值 ×1.15

import SwiftUI

struct SparklineView: View {
    let values: [Double?]

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let yMax = peak()
                guard yMax > 0 else { return }
                let count = values.count
                guard count > 1 else { return }
                var pen = false
                for (i, v) in values.enumerated() {
                    guard let v, v.isFinite, v >= 0 else {
                        pen = false
                        continue
                    }
                    let x = geo.size.width * CGFloat(i) / CGFloat(count - 1)
                    let y = geo.size.height * (1 - CGFloat(v / yMax))
                    let pt = CGPoint(x: x, y: y)
                    if pen {
                        p.addLine(to: pt)
                    } else {
                        p.move(to: pt)
                        pen = true
                    }
                }
            }
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .frame(height: 64)
        .accessibilityLabel("过去 60 分钟整机功率曲线")
    }

    private func peak() -> Double {
        let m = values.compactMap { $0 }.max() ?? 0
        return m > 0 ? m * 1.15 : 0
    }
}
