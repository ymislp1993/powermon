// ProcessRanker.swift — CPU 占用排行（ps 采样，相对能耗排行）
// 进程级绝对瓦数系统不提供，需 powermetrics（M2.5 二级方案）

import Foundation

struct ProcUsage: Equatable {
    let pid: Int
    let cpuPercent: Double
    let name: String
}

enum ProcessRanker {
    static func topCPU(limit: Int = 5) -> [ProcUsage] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["axo", "pid=,pcpu=,comm=", "-r"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line -> ProcUsage? in
            let parts = line.trimmingCharacters(in: .whitespaces)
                .split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]) else { return nil }
            return ProcUsage(pid: pid, cpuPercent: cpu, name: shortName(String(parts[2])))
        }
        .sorted { $0.cpuPercent > $1.cpuPercent }
        .prefix(limit)
        .map { $0 }
    }

    /// 去掉可执行文件全路径，只留尾部名
    private static func shortName(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }
}
