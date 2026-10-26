// PanelView.swift — 菜单栏下拉面板（v2 视觉语言：精密仪器 × 一只活着的兽）
// 色彩与字体一律取自 DesignTokens.swift（PM），禁止散落写色值。
// 结构（从上到下）：兽区（瓦数主角+台词）→ 四路温度 → 趋势折叠 → 添柴榜 → GLM 额度 → 设置折叠行+退出

import SwiftUI

/// 登录自启开关的本地状态壳（@State 的宏在裸 swiftc 下不可用，用 ObservableObject 顶替）
final class LoginToggleState: ObservableObject {
    @Published var enabled = false
}

/// 面板本地 UI 态（@State 的宏在裸 swiftc 下不可用，用 ObservableObject 壳替代）
final class PanelUiState: ObservableObject {
    @Published var settingsExpanded = false
    @Published var trendExpanded = false
}

struct PanelView: View {
    @ObservedObject var store: PowerStore
    @StateObject private var quota = PlanQuotaStore()
    // 登录自启状态只在面板出现时查一次系统（评审 B3：SMAppService.status 是 XPC 调用，
    // 不放进 Binding get 里随 2s 节拍反复打）。
    // 注意：这里故意不用 @State——新 SDK 里它是外部宏，裸 swiftc 构建找不到 SwiftUIMacros 插件
    @StateObject private var loginToggle = LoginToggleState()
    // 设置区折叠态（v1.5.1 UI 收纳：低频开关与危险操作收起，默认不展开）
    @StateObject private var ui = PanelUiState()

    /// 发丝分隔线（v2 组件语言：替代满屏 Divider）
    private var hairline: some View {
        Rectangle()
            .fill(PM.hairline)
            .frame(height: 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PM.gapSection) {
            header
            hairline
            tempRow
            hairline
            trendSection
            hairline
            topSection
            hairline
            quotaSection
            hairline
            settingsRow
        }
        .padding(PM.insetPanel)
        .frame(width: 320)
        .onAppear {
            loginToggle.enabled = LoginItem.isEnabled
            quota.refresh()
        }
    }

    // MARK: 兽区（三问之一：现在多少瓦——瓦数是全面板主角，琥珀 T1）

    private var header: some View {
        VStack(alignment: .leading, spacing: PM.gapElement) {
            HStack(alignment: .top, spacing: PM.gapElement) {
                PetArtView(state: store.petState, height: 40, tint: PM.amber, isHot: store.isHot)
                    .accessibilityLabel("耗电兽，当前\(store.isHot ? "高负载喘气" : "正常")")
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(wattsText)
                            .font(PM.pmT1)
                            .foregroundStyle(PM.amber)
                        Text("W")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PM.text2)
                    }
                    Text("整机功率").font(PM.pmT4).foregroundStyle(PM.text3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.external ? "插电" : "电池供电")
                        .font(PM.pmT4).foregroundStyle(PM.text2)
                    Text("电量 \(store.socText)")
                        .font(PM.pmT4).foregroundStyle(PM.text3)
                }
            }
            Text(store.speech)
                .font(.system(size: 13))
                .foregroundStyle(PM.text1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PM.raised, in: RoundedRectangle(cornerRadius: 8))
            Text(store.detail)
                .font(PM.pmT4)
                .foregroundStyle(PM.text3)
        }
    }

    private var wattsText: String {
        guard let w = store.watts else { return "--" }
        return String(format: "%.1f", w)
    }

    // MARK: 四路温度（F3）：label 上 / 数值下，等宽数字

    private var tempRow: some View {
        HStack(spacing: 0) {
            tempCell("CPU", store.cpuTemp)
            tempCell("GPU", store.gpuTemp)
            tempCell("电池", store.battTemp)
            tempCell("环境", store.ambient)
        }
    }

    private func tempCell(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(PM.pmT4).foregroundStyle(PM.text3)
            Text(value.map { String(format: "%.1f°", $0) } ?? "--")
                .font(PM.pmT3)
                .foregroundStyle(PM.text1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 趋势折叠（F5：收起=一行摘要 min/max 常显，点开显示折线）

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: PM.gapElement) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { ui.trendExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: ui.trendExpanded ? "chevron.down" : "chevron.right")
                    Text("过去 60 分钟（均值）")
                    Spacer()
                    if let mm = store.trendMinMax {
                        Text(String(format: "↓%.1f ↑%.1f W", mm.min, mm.max))
                    }
                }
                .font(PM.pmT4)
                .foregroundStyle(PM.text3)
            }
            .buttonStyle(.borderless)
            if ui.trendExpanded {
                SparklineView(values: store.trend)
            }
        }
    }

    // MARK: 添柴榜（F4：谁在吃——灰阶条，排序与条长已表达信息）

    private var topSection: some View {
        VStack(alignment: .leading, spacing: PM.gapElement) {
            Text("添柴榜（CPU%）").font(PM.pmT4).foregroundStyle(PM.text3)
            if store.top.isEmpty {
                Text("暂无数据").font(PM.pmT4).foregroundStyle(PM.text3)
            } else {
                ForEach(store.top, id: \.pid) { p in
                    HStack(spacing: 8) {
                        Text(ProcessNameLocalizer.chineseName(for: p.name) ?? p.name)
                            .font(PM.pmT4)
                            .foregroundStyle(PM.text1)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: 124, alignment: .leading)
                        progressBar(fraction: min(p.cpuPercent, 100) / 100, tint: PM.barGray)
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.1f", p.cpuPercent))
                            .font(PM.pmT3)
                            .foregroundStyle(PM.text2)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .help("原始进程名：\(p.name)")
                }
            }
        }
    }

    // MARK: GLM 额度（F12，可选联网；布局对齐智谱控制台「剩余额度」卡片）

    private var quotaSection: some View {
        VStack(alignment: .leading, spacing: PM.gapElement) {
            HStack {
                Text("剩余额度")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PM.text1)
                    .accessibilityLabel("GLM Coding Plan 剩余额度，\(quota.level.map { $0.uppercased() + " 档" } ?? "未配置")")
                Spacer()
                if quota.isConfigured {
                    Button {
                        if let url = URL(string: "https://bigmodel.cn/coding-plan/personal/usage") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text("更多")
                            Image(systemName: "chevron.right")
                        }
                        .font(PM.pmT4)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(PM.text3)
                }
            }
            if !quota.isConfigured {
                HStack(spacing: 6) {
                    SecureField("粘贴 Coding Plan API Key", text: $quota.keyInput)
                        .font(PM.pmT4)
                    Button("保存") { quota.saveKey() }
                        .controlSize(.small)
                        .disabled(quota.keyInput.trimmingCharacters(in: .whitespaces).count < 20)
                }
                Text("开启后查询额度时将访问 bigmodel.cn 官方接口；Key 只存本机，可随时清除")
                    .font(PM.pmT4)
                    .foregroundStyle(PM.text3)
            } else if quota.rows.isEmpty {
                Text(quota.isLoading ? "查询中…" : (quota.status.isEmpty ? "暂无数据" : quota.status))
                    .font(PM.pmT4)
                    .foregroundStyle(PM.text3)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(quota.rows) { row in
                        quotaColumn(row)
                    }
                    Spacer(minLength: 0)
                }
                if !quota.status.isEmpty {
                    Text(quota.status).font(PM.pmT4).foregroundStyle(PM.text3)
                }
                HStack {
                    Text(fetchedCaption).font(PM.pmT4).foregroundStyle(PM.text3)
                    Spacer()
                    Button("清除 Key") { quota.clearKey() }
                        .controlSize(.mini)
                        .buttonStyle(.borderless)
                        .foregroundStyle(PM.text3)
                }
            }
        }
    }

    private func quotaColumn(_ row: QuotaLimitRow) -> some View {
        let tint: Color = [PM.quotaBlue, PM.quotaGreen, PM.quotaPurple][min(row.tintIndex, 2)]
        return VStack(alignment: .leading, spacing: 5) {
            Text(row.label)
                .font(PM.pmT4)
                .foregroundStyle(PM.text3)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(row.percentRemaining))%")
                    .font(PM.pmT2)
                    .foregroundStyle(PM.text1)
                if !row.resetDisplay.isEmpty {
                    Text("· \(row.resetDisplay)")
                        .font(PM.pmT4)
                        .foregroundStyle(PM.text3)
                        .lineLimit(1)
                }
            }
            progressBar(fraction: min(row.percentRemaining, 100) / 100, tint: tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(row.resetDisplay.isEmpty ? "\(row.label)：剩余 \(Int(row.percentRemaining))%"
              : "\(row.label)：剩余 \(Int(row.percentRemaining))%，\(row.resetDisplay) 重置")
    }

    private var fetchedCaption: String {
        quota.fetchedAt.map { "查询于 \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
    }

    // MARK: 设置折叠行 + 退出（F7：退出常驻右端）

    private var settingsRow: some View {
        VStack(alignment: .leading, spacing: PM.gapElement) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { ui.settingsExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("设置")
                        Image(systemName: ui.settingsExpanded ? "chevron.down" : "chevron.right")
                    }
                    .font(PM.pmT4)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(PM.text3)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
            if ui.settingsExpanded {
                VStack(alignment: .leading, spacing: PM.gapElement) {
                    Toggle("高功耗通知", isOn: Binding(
                        get: { store.notifier.isEnabled },
                        set: { store.notifier.setEnabled($0) }))
                        .font(PM.pmT4)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    Toggle("登录自启", isOn: Binding(
                        get: { loginToggle.enabled },
                        set: { loginToggle.enabled = $0; LoginItem.setEnabled($0) }))
                        .font(PM.pmT4)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    HStack {
                        Button("清除 Key") { quota.clearKey() }
                            .controlSize(.mini)
                            .buttonStyle(.borderless)
                            .foregroundStyle(PM.text3)
                        Spacer()
                        Text("Key 只存本机（0600），清除后恢复零联网")
                            .font(PM.pmT4)
                            .foregroundStyle(PM.text3)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: 底层组件

    /// 统一细进度条：条轨 = hairline，条芯 = tint（v2 组件语言）
    private func progressBar(fraction: Double, tint: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PM.hairline)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(fraction, 1)) * geo.size.width)
            }
        }
        .frame(height: 4)
    }
}
