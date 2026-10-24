// HistoryStore.swift — CSV 历史落盘（SPEC F6）
// 路径 ~/Library/Application Support/powermon/record.csv
// 列格式必须与 Sources/cli/main.swift 的 csvRow 完全一致（同一份文件两类工具共用）
// 超过 20MB 轮转为 record.csv.1（旧轮转直接覆盖）。
// 评审 A1：轮转必须发生在写之前，且轮转后重新开句柄——绝不能向已关闭的 FileHandle 写入。

import Foundation

final class HistoryStore {
    private let dir: URL
    private let currentURL: URL
    private let backupURL: URL
    private let maxBytes = 20 * 1024 * 1024
    private var fh: FileHandle?
    private var bytesWritten = 0        // 自累计，避免每行一次 stat（评审 C3）
    private var warnedOnce = false

    private static let isoFormatter = ISO8601DateFormatter()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("powermon", isDirectory: true)
        currentURL = dir.appendingPathComponent("record.csv")
        backupURL = dir.appendingPathComponent("record.csv.1")
    }

    func append(_ s: AppSample) {
        prepare()
        if bytesWritten > maxBytes {
            rotate()
            prepare()
        }
        guard let fh else {
            warnOnce("record.csv 打不开，本轮放弃写入")
            return
        }
        let line = Data((csvRow(s) + "\n").utf8)
        fh.write(line)
        bytesWritten += line.count
    }

    func closeFile() {
        if let fh { try? fh.close() }
        fh = nil
    }

    // MARK: - 内部

    /// 确保目录/文件/句柄就绪。幂等：句柄已开则直接返回。
    private func prepare() {
        guard fh == nil else { return }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: currentURL.path) {
            FileManager.default.createFile(atPath: currentURL.path, contents: Data((csvHeader() + "\n").utf8))
        }
        fh = FileHandle(forWritingAtPath: currentURL.path)
        _ = try? fh?.seekToEnd()
        bytesWritten = (try? FileManager.default.attributesOfItem(atPath: currentURL.path)[.size] as? Int) ?? 0
    }

    /// 调用前提：句柄已关闭（append 中先 closeFile 再 prepare）
    private func rotate() {
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: currentURL, to: backupURL)
        FileManager.default.createFile(atPath: currentURL.path, contents: Data((csvHeader() + "\n").utf8))
    }

    private func warnOnce(_ msg: String) {
        guard !warnedOnce else { return }
        warnedOnce = true
        FileHandle.standardError.write(Data((msg + "\n").utf8))
    }

    // 以下两函数与 Sources/cli/main.swift 的 csvHeader/csvRow 逐列同步（AppSample 与 CLI Sample 字段一致）
    private func csvHeader() -> String {
        "time,state,watts,pdtr_w,batt_w,cpu_temp,gpu_temp,batt_temp,ambient,soc,top1,top1_cpu"
    }

    private func csvRow(_ s: AppSample) -> String {
        let iso = Self.isoFormatter.string(from: s.time)
        let state = s.reading.map { $0.external ? "ac" : "battery" } ?? ""
        let top1 = s.top.first

        // 逐列构造（整包数组字面量会让类型检查超时，拆开写）
        var cols: [String] = [iso, state]
        if let r = s.reading {
            cols.append(String(format: "%.2f", r.systemWatts))
            cols.append(r.pdtrWatts.map { String(format: "%.2f", $0) } ?? "")
            cols.append(String(format: "%.2f", r.batteryTermW))
        } else {
            cols.append(contentsOf: ["", "", ""])
        }
        cols.append(fmt2(s.cpuTemp))
        cols.append(fmt2(s.gpuTemp))
        cols.append(fmt2(s.battTemp))
        cols.append(fmt2(s.ambient))
        cols.append(s.battery?.percent.map(String.init) ?? "")
        cols.append(top1?.name ?? "")
        cols.append(top1.map { String(format: "%.1f", $0.cpuPercent) } ?? "")
        return cols.joined(separator: ",")
    }

    private func fmt2(_ v: Double?) -> String {
        v.map { String(format: "%.2f", $0) } ?? ""
    }
}
