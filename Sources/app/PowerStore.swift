// PowerStore.swift — 采样调度与 UI 状态（@MainActor）
// 节奏（SPEC F1–F6）：瓦数/温度 2s；Top5 约 4s；趋势点 10s（画 EMA 均值线）；CSV 每 10s 一行（记原始值）。
// 显示层（v1.1 耗电兽）：菜单栏与面板都不再直出瞬时值——
//   EMA(α≈0.18, 时间常数≈10s) → 四态状态机（睡/走/跑/喘），
//   异常判定带滞回：4 拍（跨度 6s）EMA 持续 >25W 才进入，EMA<20W 才解除。
// 可靠性（SPEC）：单次采样失败只更新提示并补断点，定时器永不停摆；
// 退出清理走同步路径（applicationWillTerminate 不等异步任务）。

import Foundation
import SwiftUI

enum PetState {
    case sleep, walk, run, pant

    var symbolName: String {
        switch self {
        case .sleep: return "zzz"
        case .walk: return "figure.walk"
        case .run: return "figure.run"
        case .pant: return "lungs.fill"
        }
    }
}

/// 菜单栏图标专用轻量状态源（性能优化 P1）：只含图标用到的两项，
/// 菜单栏 label 只订阅它，图标状态不变就完全不发事件——
/// 与温度/台词等面板发布彻底解耦，砍掉每拍无效的菜单栏重算
@MainActor
final class MenuIconStore: ObservableObject {
    @Published var petState: PetState = .sleep
    @Published var isHot = false
}

@MainActor
final class PowerStore: ObservableObject {
    static let shared = PowerStore()
    static let trendCapacity = 360      // 10s × 360 = 60 分钟
    static let hotWatts = 25.0          // 异常判定线
    static let calmWatts = 20.0         // 滞回解除线
    static let sleepWatts = 10.0        // 睡/走分界
    static let hotSustainTicks = 4      // 4 拍（跨度 6s）EMA 持续 >25W 才算"持续"

    @Published private(set) var petState: PetState = .sleep
    @Published private(set) var speech: String = "刚醒来，看看谁在动…"
    @Published private(set) var isHot = false
    @Published private(set) var detail: String = "采集中…"
    @Published private(set) var external: Bool = true
    @Published private(set) var socText: String = "--"
    @Published private(set) var cpuTemp: Double?
    @Published private(set) var gpuTemp: Double?
    @Published private(set) var battTemp: Double?
    @Published private(set) var ambient: Double?
    @Published private(set) var top: [ProcUsage] = []
    @Published private(set) var trend: [Double?] = Array(repeating: nil, count: PowerStore.trendCapacity)

    /// 菜单栏轻量状态源（P1）：仅在 petState/isHot 变化时经 setPetState/setIsHot 写入
    let menu = MenuIconStore()
    let notifier = PowerNotifier()

    private let sampler = Sampler()
    private let history = HistoryStore()
    private var timer: DispatchSourceTimer?
    private var tick = 0
    private var ema: Double?
    private var hotTicks = 0

    var trendMinMax: (min: Double, max: Double)? {
        let vals = trend.compactMap { $0 }
        guard let lo = vals.min(), let hi = vals.max(), lo != hi || vals.count > 1 else { return nil }
        return (lo, hi)
    }

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "powermon.sampler"))
        // leeway 200ms：允许内核合并唤醒省能耗（P5），不改变 2s 采样节奏语义
        t.schedule(deadline: .now(), repeating: 2.0, leeway: .milliseconds(200))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let sample = self.sampler.sample()          // IO 在后台队列，状态在 Sampler 自有队列串行化
            Task { @MainActor in self.apply(sample) }
        }
        t.resume()
        timer = t
    }

    /// 同步停止采样并清理。applicationWillTerminate 在主线程直接调用，
    /// 不经异步派发——terminate 流程不会等待异步任务（评审 B1/B5）。
    func stopSampling() {
        timer?.cancel()
        timer = nil
        sampler.shutdown()
        history.closeFile()
    }

    private func apply(_ s: AppSample?) {
        tick += 1
        guard let s else {
            if detail != "采样失败，下轮重试" { detail = "采样失败，下轮重试" }
            if tick % 5 == 0 { pushTrend(nil) }         // 断点占位只占趋势槽位，不挤占历史（评审 C3）
            return
        }
        // 以下赋值全部带等值守卫（P1）：值不变不发布，避免每拍 ~12 次无效写入引发 SwiftUI/AppKit 失效风暴
        if let r = s.reading {
            if detail != r.detail { detail = r.detail }
            if external != r.external { external = r.external }
        } else if detail != "电池数据不可用" {
            detail = "电池数据不可用"
        }
        let newSoc = s.battery?.percent.map { "\($0)%" } ?? "--"
        if socText != newSoc { socText = newSoc }
        if cpuTemp != s.cpuTemp { cpuTemp = s.cpuTemp }
        if gpuTemp != s.gpuTemp { gpuTemp = s.gpuTemp }
        if battTemp != s.battTemp { battTemp = s.battTemp }
        if ambient != s.ambient { ambient = s.ambient }
        if top != s.top { top = s.top }                 // ProcUsage 已 Equatable

        // 显示层：EMA + 兽状态机（瞬时值不动，只影响趋势与台词）
        if let w = s.reading?.systemWatts {
            ema = (ema ?? w) + (w - (ema ?? w)) * 0.18
        }
        if let e = ema {
            let wasHot = isHot
            if isHot {
                if e < Self.calmWatts { setIsHot(false); hotTicks = 0 }
            } else if e >= Self.hotWatts {
                hotTicks += 1
                if hotTicks >= Self.hotSustainTicks { setIsHot(true) }
            } else {
                hotTicks = 0
            }
            updatePetState(ema: e)
            let line = Self.makeSpeech(state: petState, ema: e, feeder: s.top.first?.name)
            if speech != line { speech = line }         // 台词逐字不变则不发布（P1）
            // F9：进入喘气态瞬间投递高功耗通知（冷却/开关/授权由 notifier 自查）
            if !wasHot && isHot {
                notifier.notifyHighPower(
                    watts: Int(e.rounded()),
                    feeder: Self.displayName(s.top.first?.name))
            }
        }

        // 注意：trend 绝不加等值守卫——趋势线每 10s 必须滑动并触发重绘（含 nil 占位）
        if tick % 5 == 0 {                              // 10s 一个趋势点（均值线）
            pushTrend(ema)
        }
        if tick % 5 == 3 {                              // 10s 一行 CSV（原始值，与显示层无关）
            history.append(s)
        }
    }

    // MARK: - 带守卫的状态写入（P1：面板 @Published 与菜单栏轻量源同步，均只在值变化时发布）

    private func setPetState(_ v: PetState) {
        guard petState != v else { return }
        petState = v
        menu.petState = v
    }

    private func setIsHot(_ v: Bool) {
        guard isHot != v else { return }
        isHot = v
        menu.isHot = v
    }

    private func pushTrend(_ v: Double?) {
        trend.removeFirst()
        trend.append(v)
    }

    /// 兽状态迁移（各边界带 ±1W 滞回，防阈值附近图标来回抖，评审 C2）
    private func updatePetState(ema e: Double) {
        if isHot {
            setPetState(.pant)
            return
        }
        switch petState {
        case .pant:                                     // 从喘气恢复
            setPetState(e >= Self.calmWatts ? .run : .walk)
        case .sleep:
            setPetState(e >= Self.sleepWatts + 1 ? .walk : .sleep)
        case .walk:
            setPetState(e >= Self.calmWatts ? .run : (e < Self.sleepWatts ? .sleep : .walk))
        case .run:
            setPetState(e < Self.calmWatts - 1 ? .walk : .run)
        }
    }

    /// 台词：按状态生成，均含均值瓦数；高载台词点名添柴人（Top1 进程，词典中文化优先）
    static func makeSpeech(state: PetState, ema: Double, feeder: String?) -> String {
        let who = displayName(feeder)
        let w = Int(ema.rounded())
        switch state {
        case .sleep: return "zzz… 全体安静，才 \(w)W"
        case .walk: return "散个步，\(w)W，挺舒服"
        case .run: return "\(who) 点的火，冲到 \(w)W！"
        case .pant: return "救命，\(who) 把我烤到 \(w)W 了！！"
        }
    }

    /// 统一显示名：词典中文优先，未命中走英文清洗名（台词与 F9 通知共用，评审 C5 口径一致）
    static func displayName(_ raw: String?) -> String {
        ProcessNameLocalizer.chineseName(for: raw ?? "") ?? feederName(raw)
    }

    /// "Google Chrome Helper (Renderer)" → "Google Chrome"；"com.apple.WebKit.WebContent" → "WebContent"
    /// 清洗链与 ProcessNameLocalizer.baseName 共用（评审 B1：不再重复维护两份正则）
    static func feederName(_ raw: String?) -> String {
        var n = ProcessNameLocalizer.baseName(raw ?? "")
        if n.isEmpty { n = "神秘进程" }
        return String(n.prefix(24))
    }
}
