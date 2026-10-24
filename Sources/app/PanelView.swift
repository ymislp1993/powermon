// PanelView.swift — 菜单栏下拉面板（SPEC F2–F4、F5、F7、F8，v1.1 耗电兽版）
// 宽 320pt：功率区（兽 + 台词气泡 + 口径小字）/ 温度行 / 60 分钟趋势（EMA 线）/ 添柴榜 / 退出

import SwiftUI

/// 登录自启开关的本地状态壳（@State 的宏在裸 swiftc 下不可用，用 ObservableObject 顶替）
final class LoginToggleState: ObservableObject {
    @Published var enabled = false
}

struct PanelView: View {
    @ObservedObject var store: PowerStore
    // 登录自启状态只在面板出现时查一次系统（评审 B3：SMAppService.status 是 XPC 调用，
    // 不放进 Binding get 里随 2s 节拍反复打）。
    // 注意：这里故意不用 @State——新 SDK 里它是外部宏，裸 swiftc 构建找不到 SwiftUIMacros 插件
    @StateObject private var loginToggle = LoginToggleState()

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
            HStack(spacing: 8) {
                Toggle("通知", isOn: Binding(
                    get: { store.notifier.isEnabled },
                    set: { store.notifier.setEnabled($0) }))
                    .font(.caption2)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Toggle("登录自启", isOn: Binding(
                    get: { loginToggle.enabled },
                    set: { loginToggle.enabled = $0; LoginItem.setEnabled($0) }))
                    .font(.caption2)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
            HStack {
                Text("采样 2s · 记录 10s · 曲线 10s/点")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { loginToggle.enabled = LoginItem.isEnabled }
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
