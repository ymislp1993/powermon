// Sampler.swift — 采集封装：SMC 生命周期管理 + Top5 缓存 + 组装快照
// 所有内部状态（smc/topCache）只在自有序列队列上触碰：sample/shutdown 用 queue.sync 串行化，
// 保证退出时 in-flight 的 SMC 调用与 IOServiceClose 不会并发（评审 B1）。
// 温度键名统一引用 Sources/core/SensorKeys.swift（与 CLI 共用一份，不再手工同步）

import Foundation

struct AppSample {
    let time: Date
    let reading: PowerReading?      // 电池源不可用时为 nil（评审 B4：温度等其余项照常）
    let cpuTemp: Double?
    let gpuTemp: Double?
    let ambient: Double?
    let battTemp: Double?
    let battery: BatterySnapshot?
    let top: [ProcUsage]
}

final class Sampler {
    private let queue = DispatchQueue(label: "powermon.sampler.state")
    private var smc: SMCSensor?
    private var topCache: (items: [ProcUsage], at: Date) = ([], .distantPast)

    /// 单次采样。任何源失败返回 nil 或对应字段 nil，绝不抛出。
    func sample() -> AppSample? {
        queue.sync { sampleLocked() }
    }

    /// 退出时同步关闭 SMC：sync 会等 in-flight 采样结束，杜绝关闭与读写并发
    func shutdown() {
        queue.sync {
            smc?.close()
            smc = nil
        }
    }

    // MARK: - 以下均在 queue 上执行

    private func sampleLocked() -> AppSample? {
        guard let smc = ensureSMC() else { return nil }

        let now = Date()
        // 2s 采样网格上 TTL 3.5 → 约 4s 刷新一轮 Top5（评审 B3：覆盖 F4 的 5s 要求）
        if now.timeIntervalSince(topCache.at) > 3.5 {
            topCache = (ProcessRanker.topCPU(), now)
        }

        let battery = BatterySource.snapshot()
        let reading = battery.map { PowerModel.compute(battery: $0, smc: smc) }

        return AppSample(
            time: now,
            reading: reading,
            cpuTemp: smc.maxDouble(SensorKeys.cpuTempKeys),
            gpuTemp: smc.maxDouble(SensorKeys.gpuTempKeys),
            ambient: smc.double(SensorKeys.ambientKey),
            battTemp: smc.double(SensorKeys.batteryTempKey) ?? battery?.tempC,
            battery: battery,
            top: topCache.items)
    }

    /// SMC 打开失败时每个采样周期静默重试（SPEC F8 降级要求）
    private func ensureSMC() -> SMCSensor? {
        if smc != nil { return smc }
        let s = SMCSensor()
        if (try? s.open()) != nil { smc = s }
        return smc
    }
}
