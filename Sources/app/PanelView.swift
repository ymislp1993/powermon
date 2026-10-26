// PanelView.swift — 菜单栏下拉面板（SPEC F2–F4、F5、F7、F8，v1.1 耗电兽版）
// 宽 320pt：功率区（兽 + 台词气泡 + 口径小字）/ 温度行 / 60 分钟趋势（EMA 线）/ 添柴榜 / 退出

import SwiftUI

/// 登录自启开关的本地状态壳（@State 的宏在裸 swiftc 下不可用，用 ObservableObject 顶替）
final class LoginToggleState: ObservableObject {
    @Published var enabled = false
}

/// 面板本地 UI 态（@State 的宏在裸 swiftc 下不可用，用 ObservableObject 壳替代）
final class PanelUiState: ObservableObject {
    @Published var settingsExpanded = false
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            tempRow
            Divider()
            trendSection
            Divider()
            topSection
            Divider()
            quotaSection
            Divider()
            // 设置行（v1.5.1 收纳）：折叠收纳低频开关与清除 Key；退出常驻右端（SPEC F7）
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { ui.settingsExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("设置")
                        Image(systemName: ui.settingsExpanded ? "chevron.down" : "chevron.right")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
            if ui.settingsExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("高功耗通知", isOn: Binding(
                        get: { store.notifier.isEnabled },
                        set: { store.notifier.setEnabled($0) }))
                        .font(.caption)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    Toggle("登录自启", isOn: Binding(
                        get: { loginToggle.enabled },
                        set: { loginToggle.enabled = $0; LoginItem.setEnabled($0) }))
                        .font(.caption)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    HStack {
                        Button("清除 Key") { quota.clearKey() }
                            .controlSize(.mini)
                            .buttonStyle(.borderless)
                        Spacer()
                        Text("Key 只存本机（0600），清除后恢复零联网")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear {
            loginToggle.enabled = LoginItem.isEnabled
            quota.refresh()
        }
    }

    // MARK: 功率区（F2）：兽 + 台词气泡 + 口径

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: store.petState.symbolName)
                    .font(.system(size: 30))
                    .frame(width: 44, height: 40)
                    .foregroundStyle(store.isHot ? Color.red : Color.primary)
                    .accessibilityLabel("耗电兽，当前\(store.isHot ? "高负载喘气" : "正常")")
                Text(store.speech)
                    .font(.callout)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                Spacer(minLength: 0)
            }
            Text("\(store.detail) · 电量 \(store.socText)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 温度行（F3）

    private var tempRow: some View {
        let item = { (label: String, v: Double?) in
            "\(label) \(v.map { String(format: "%.1f", $0) } ?? "--")°"
        }
        return Text([
            item("CPU", store.cpuTemp),
            item("GPU", store.gpuTemp),
            item("电池", store.battTemp),
            item("环境", store.ambient),
        ].joined(separator: " · "))
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: 趋势（F5，画的是 10s EMA 均值线）

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("过去 60 分钟（均值）").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let mm = store.trendMinMax {
                    Text(String(format: "↓%.1f ↑%.1f W", mm.min, mm.max))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            SparklineView(values: store.trend)
        }
    }

    // MARK: GLM 额度（F12，可选联网；布局对齐智谱控制台「剩余额度」卡片）

    private var quotaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("剩余额度")
                    .font(.system(size: 13, weight: .semibold))
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
                        .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            if !quota.isConfigured {
                HStack(spacing: 6) {
                    SecureField("粘贴 Coding Plan API Key", text: $quota.keyInput)
                        .font(.caption)
                    Button("保存") { quota.saveKey() }
                        .controlSize(.small)
                        .disabled(quota.keyInput.trimmingCharacters(in: .whitespaces).count < 20)
                }
                Text("开启后查询额度时将访问 bigmodel.cn 官方接口；Key 只存本机，可随时清除")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if quota.rows.isEmpty {
                Text(quota.isLoading ? "查询中…" : (quota.status.isEmpty ? "暂无数据" : quota.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(quota.rows) { row in
                        QuotaColumn(row: row)
                    }
                    Spacer(minLength: 0)
                }
                if !quota.status.isEmpty {
                    Text(quota.status).font(.caption2).foregroundStyle(.secondary)
                }
                HStack {
                    Text(fetchedCaption).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("清除 Key") { quota.clearKey() }
                        .controlSize(.mini)
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private var fetchedCaption: String {
        quota.fetchedAt.map { "查询于 \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
    }

    /// 单列额度（控制台同款：小标签 / 大字百分比 · 重置点 / 彩色细进度条）
    private struct QuotaColumn: View {
        let row: QuotaLimitRow

        var tint: Color {
            [Color.blue, Color.green, Color.purple][min(row.tintIndex, 2)]
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(row.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(row.percentRemaining))%")
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(row.percentRemaining < 15 ? Color.red : Color.primary)
                    if !row.resetDisplay.isEmpty {
                        Text("· \(row.resetDisplay)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                ProgressView(value: min(row.percentRemaining, 100) / 100)
                    .tint(tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(row.percentRemaining >= 0
                  ? "\(row.label)：剩余 \(Int(row.percentRemaining))%" + (row.resetDisplay.isEmpty ? "" : "，\(row.resetDisplay) 重置")
                  : row.label)
        }
    }


    // MARK: 添柴榜（F4）

    private var topSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("添柴榜（CPU%）").font(.caption).foregroundStyle(.secondary)
            if store.top.isEmpty {
                Text("暂无数据").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.top, id: \.pid) { p in
                    HStack(spacing: 8) {
                        Text(ProcessNameLocalizer.chineseName(for: p.name) ?? p.name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: 150, alignment: .leading)
                        ProgressView(value: min(p.cpuPercent, 100) / 100)
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.1f", p.cpuPercent))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                    .help("原始进程名：\(p.name)")
                }
            }
        }
    }
}
