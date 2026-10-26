// PlanQuota.swift — GLM Coding Plan 剩余额度（SPEC F12，可选联网功能）
// 口径：用户手动粘贴自己的 API Key（存本机文件 0600，不入仓库），面板打开或手动刷新时
// 访问 bigmodel.cn 官方接口查询额度。未配置时完全不发请求——默认仍为全本地。
// 数据源：GET https://bigmodel.cn/api/monitor/usage/quota/limit（Bearer <key>，2026-10 实测）

import Foundation

struct QuotaLimitRow: Identifiable, Equatable {
    let id: String
    let label: String
    let percentRemaining: Double       // 剩余百分比 0-100
    let detail: String                 // 重置时间 / 剩余量说明
}

struct QuotaSnapshot: Equatable {
    let level: String?
    let rows: [QuotaLimitRow]
}

enum PlanQuotaError: Error, CustomStringConvertible {
    case notConfigured
    case http(Int)
    case badPayload

    var description: String {
        switch self {
        case .notConfigured: return "未配置 API Key"
        case .http(let code): return "接口返回 \(code)"
        case .badPayload: return "返回数据无法解析"
        }
    }
}

enum PlanQuotaService {
    static let endpoint = URL(string: "https://bigmodel.cn/api/monitor/usage/quota/limit")!
    static let keyFileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("powermon/plan-key")

    static func loadKey() -> String? {
        guard let data = try? Data(contentsOf: keyFileURL),
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else { return nil }
        return key
    }

    static func saveKey(_ key: String) {
        let dir = keyFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? key.data(using: .utf8)?.write(to: keyFileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFileURL.path)
    }

    static func deleteKey() {
        try? FileManager.default.removeItem(at: keyFileURL)
    }

    /// 拉取额度快照。网络/HTTP/解析失败均抛错，由调用方决定展示。
    static func fetch(key: String) async throws -> QuotaSnapshot {
        var req = URLRequest(url: endpoint)
        req.timeoutInterval = 15
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlanQuotaError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try Self.decode(data)
    }

    /// 纯函数解码（便于离线测试）：字段语义基于 M3 + Pro 档 2026-10 实测
    static func decode(_ data: Data) throws -> QuotaSnapshot {
        struct Payload: Decodable {
            struct Limit: Decodable {
                let type: String
                let unit: Int?
                let number: Int?
                let percentage: Int?
                let usage: Int?
                let currentValue: Int?
                let remaining: Int?
                let nextResetTime: Double?
            }
            struct Data_: Decodable {
                let limits: [Limit]
                let level: String?
            }
            let data: Data_?
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let limits = payload.data?.limits else { throw PlanQuotaError.badPayload }

        let rows = limits.map { lim -> QuotaLimitRow in
            let id = "\(lim.type)-\(lim.unit ?? -1)-\(lim.number ?? -1)"
            // unit 语义（实测）：3=小时、5=月、6=周
            let unitName = ["", "", "", "小时", "", "月", "周"][min(lim.unit ?? 0, 6)]
            let reset: String = {
                guard let ms = lim.nextResetTime else { return "" }
                let d = Date(timeIntervalSince1970: ms / 1000)
                let fmt = DateFormatter()
                fmt.dateFormat = "MM-dd HH:mm"
                return fmt.string(from: d)
            }()
            if lim.type == "TIME_LIMIT", let used = lim.currentValue, let total = lim.usage {
                let remain = lim.remaining ?? max(total - used, 0)
                let pct = lim.percentage.map { Double($0) }
                    ?? (total > 0 ? Double(remain) / Double(total) * 100 : 0)
                return QuotaLimitRow(id: id, label: "月度额度",
                                     percentRemaining: min(max(pct, 0), 100),
                                     detail: "剩 \(remain)/\(total) · \(reset) 重置")
            }
            // 观测语义（M3 + Pro 档实测）：TOKENS_LIMIT(3,5)=5 小时窗口；TOKENS_LIMIT(6,1)=每周窗口
            let label: String
            switch (lim.unit ?? -1, lim.number ?? -1) {
            case (3, 5): label = "5 小时窗口"
            case (6, 1): label = "每周窗口"
            default: label = "\(lim.number ?? 1) \(unitName)窗口"
            }
            let pct = lim.percentage.map { Double($0) } ?? 0
            return QuotaLimitRow(id: id, label: label,
                                 percentRemaining: min(max(pct, 0), 100),
                                 detail: reset.isEmpty ? "" : "\(reset) 重置")
        }
        return QuotaSnapshot(level: payload.data?.level, rows: rows)
    }
}

// MARK: - 面板状态（面板打开/手动刷新时才查询；主采样循环不受影响）

@MainActor
final class PlanQuotaStore: ObservableObject {
    @Published var rows: [QuotaLimitRow] = []
    @Published var level: String?
    @Published var fetchedAt: Date?
    @Published var status = ""
    @Published var isLoading = false
    @Published var isConfigured = PlanQuotaService.loadKey() != nil
    @Published var keyInput = ""

    func refresh() {
        guard let key = PlanQuotaService.loadKey(), !key.isEmpty else {
            isConfigured = false
            return
        }
        isConfigured = true
        guard !isLoading else { return }
        isLoading = true
        status = "查询中…"
        Task {
            do {
                let snap = try await PlanQuotaService.fetch(key: key)
                rows = snap.rows
                level = snap.level
                fetchedAt = Date()
                status = ""
            } catch {
                status = "刷新失败：\(error)"
            }
            isLoading = false
        }
    }

    func saveKey() {
        let k = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard k.count >= 20 else {
            status = "Key 长度异常，请检查"
            return
        }
        PlanQuotaService.saveKey(k)
        isConfigured = true
        keyInput = ""
        refresh()
    }

    func clearKey() {
        PlanQuotaService.deleteKey()
        isConfigured = false
        rows = []
        level = nil
        status = ""
        keyInput = ""
    }
}
