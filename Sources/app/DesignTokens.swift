// DesignTokens.swift — v2 视觉语言唯一色源（设计稿 ui-design-language-v2.html 的落地常量）
// 原则：禁止在视图里散落写色值；琥珀只给兽和瓦数；红只给异常；蓝绿紫只属于额度三列。
// 深色为主战场，浅色保证可用（动态色随系统外观切换）。

import SwiftUI

enum PM {
    /// 深浅双态动态色
    private static func dyn(dark: Color, light: Color) -> Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }

    // 中性 · 文字三级
    static let text1 = dyn(dark: Color(red: 0.949, green: 0.949, blue: 0.961),
                           light: Color(red: 0.114, green: 0.114, blue: 0.125))
    static let text2 = dyn(dark: Color(red: 0.663, green: 0.663, blue: 0.690),
                           light: Color(red: 0.431, green: 0.431, blue: 0.451))
    static let text3 = dyn(dark: Color(red: 0.541, green: 0.541, blue: 0.573),
                           light: Color(red: 0.541, green: 0.541, blue: 0.557))

    // 中性 · 面与线
    static let raised   = dyn(dark: Color(red: 0.176, green: 0.176, blue: 0.192), light: Color.white)
    static let hairline = dyn(dark: Color.white.opacity(0.08), light: Color.black.opacity(0.08))
    static let track    = dyn(dark: Color.white.opacity(0.08), light: Color.black.opacity(0.08))

    // 品牌：琥珀只给兽和瓦数
    static let amber     = dyn(dark: Color(red: 1.000, green: 0.722, blue: 0.141),
                               light: Color(red: 0.722, green: 0.498, blue: 0.055))
    static let amberDeep = dyn(dark: Color(red: 0.780, green: 0.569, blue: 0.071),
                               light: Color(red: 0.639, green: 0.459, blue: 0.094))
    static let alert     = dyn(dark: Color(red: 1.000, green: 0.353, blue: 0.322),
                               light: Color(red: 0.878, green: 0.212, blue: 0.180))

    // 额度三列（对齐智谱控制台）
    static let quotaBlue   = dyn(dark: Color(red: 0.039, green: 0.518, blue: 1.000),
                                 light: Color(red: 0.000, green: 0.478, blue: 1.000))
    static let quotaGreen  = dyn(dark: Color(red: 0.188, green: 0.820, blue: 0.345),
                                 light: Color(red: 0.204, green: 0.780, blue: 0.349))
    static let quotaPurple = dyn(dark: Color(red: 0.749, green: 0.353, blue: 0.949),
                                 light: Color(red: 0.686, green: 0.322, blue: 0.871))

    // 添柴榜条芯（灰阶）
    static let barGray = dyn(dark: Color(red: 0.557, green: 0.557, blue: 0.576),
                             light: Color(red: 0.604, green: 0.604, blue: 0.620))

    // 字体四级（数字一律 monospacedDigit）
    static let pmT1 = Font.system(size: 32, weight: .semibold).monospacedDigit()
    static let pmT2 = Font.system(size: 15, weight: .semibold).monospacedDigit()
    static let pmT3 = Font.system(size: 13).monospacedDigit()
    static let pmT4 = Font.system(size: 11)

    // 间距节奏
    static let gapSection: CGFloat = 12
    static let gapElement: CGFloat = 8
    static let insetPanel: CGFloat = 14
}
