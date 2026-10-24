// powermon — MacBook M3 功耗监控 · M1 CLI
// 用法：powermon now
//       powermon record [--interval 秒] [--out 路径]

import Foundation

// M3 (Mac15,12) 实测有效的传感器键，见 docs/RECON.md；
// 常量上收至 Sources/core/SensorKeys.swift 与 app 共用（消掉双份手工同步，评审 C4）
// ISO8601 格式化器提为单例（对齐 HistoryStore.swift 写法），避免每行 CSV 新建（P8）
let isoFormatter = ISO8601DateFormatter()

struct Sample {
    let time: Date
    let reading: PowerReading
    let cpuTemp: Double?
    let gpuTemp: Double?
    let ambient: Double?
    let battTemp: Double?
    let battery: BatterySnapshot
    let top: [ProcUsage]
}

func collect(smc: SMCSensor) -> Sample? {
    guard let battery = BatterySource.snapshot() else { return nil }
    return Sample(
        time: Date(),
        reading: PowerModel.compute(battery: battery, smc: smc),
        cpuTemp: smc.maxDouble(SensorKeys.cpuTempKeys),
        gpuTemp: smc.maxDouble(SensorKeys.gpuTempKeys),
        ambient: smc.double(SensorKeys.ambientKey),
        battTemp: smc.double(SensorKeys.batteryTempKey) ?? battery.tempC,
        battery: battery,
        top: ProcessRanker.topCPU())
}

func fmtOpt(_ v: Double?, _ suffix: String) -> String {
    guard let v else { return "--" + suffix }
    return String(format: "%.1f%@", v, suffix)
}

func renderNow(_ s: Sample) -> String {
    var lines: [String] = []
    lines.append(String(format: "整机功率  %.1f W   （%@）", s.reading.systemWatts, s.reading.detail))
    let temps = "CPU \(fmtOpt(s.cpuTemp, "°C")) · GPU \(fmtOpt(s.gpuTemp, "°C")) · 电池 \(fmtOpt(s.battTemp, "°C")) · 环境 \(fmtOpt(s.ambient, "°C"))"
    lines.append(temps)
    var soc = "--"
    if let p = s.battery.percent { soc = "\(p)%" }
    lines.append(String(format: "电池      %@ · %.2fV × %.3fA", soc, s.battery.volts, s.battery.amps))
    lines.append("耗电大户（CPU%）")
    for (i, p) in s.top.enumerated() {
        let name = p.name.padding(toLength: 24, withPad: " ", startingAt: 0)
        lines.append(String(format: "  %d. %@ %5.1f%%", i + 1, name, p.cpuPercent))
    }
    return lines.joined(separator: "\n")
}

func csvHeader() -> String {
    "time,state,watts,pdtr_w,batt_w,cpu_temp,gpu_temp,batt_temp,ambient,soc,top1,top1_cpu"
}

func csvRow(_ s: Sample) -> String {
    let iso = isoFormatter.string(from: s.time)
    let state = s.reading.external ? "ac" : "battery"
    let top1 = s.top.first
    return [
        iso, state,
        String(format: "%.2f", s.reading.systemWatts),
        s.reading.pdtrWatts.map { String(format: "%.2f", $0) } ?? "",
        String(format: "%.2f", s.reading.batteryTermW),
        s.cpuTemp.map { String(format: "%.2f", $0) } ?? "",
        s.gpuTemp.map { String(format: "%.2f", $0) } ?? "",
        s.battTemp.map { String(format: "%.2f", $0) } ?? "",
        s.ambient.map { String(format: "%.2f", $0) } ?? "",
        s.battery.percent.map(String.init) ?? "",
        top1?.name ?? "",
        top1.map { String(format: "%.1f", $0.cpuPercent) } ?? "",
    ].joined(separator: ",")
}

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "now"

do {
    let smc = SMCSensor()
    try smc.open()
    defer { smc.close() }

    switch cmd {
    case "now":
        guard let s = collect(smc: smc) else {
            FileHandle.standardError.write("电池数据读取失败\n".data(using: .utf8)!)
            exit(1)
        }
        print(renderNow(s))

    case "record":
        var interval = 1.0
        var out = "powermon-data.csv"
        var i = 1
        while i < args.count - 1 {
            if args[i] == "--interval", let v = Double(args[i + 1]) { interval = max(0.5, v) }
            if args[i] == "--out" { out = args[i + 1] }
            i += 2
        }
        let needHeader = !FileManager.default.fileExists(atPath: out)
        let fh = FileHandle(forWritingAtPath: out) ?? {
            FileManager.default.createFile(atPath: out, contents: nil)
            return FileHandle(forWritingAtPath: out)!
        }()
        defer { try? fh.close() }
        if needHeader { fh.write((csvHeader() + "\n").data(using: .utf8)!) }
        print("记录中 → \(out)（每 \(interval)s 一行，Ctrl-C 结束）")
        while true {
            if let s = collect(smc: smc) {
                fh.write((csvRow(s) + "\n").data(using: .utf8)!)
            }
            usleep(useconds_t(interval * 1_000_000))
        }

    default:
        print("用法: powermon now | powermon record [--interval 秒] [--out 路径]")
    }
} catch {
    FileHandle.standardError.write("错误: \(error)\n".data(using: .utf8)!)
    exit(1)
}
