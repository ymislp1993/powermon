// BatterySource.swift — AppleSmartBattery 注册表：电压/电流/电量/温度
// 注意：拔电时 Amperage 为负（放电），注册表可能以无符号形式存储，必须按 Int32 截断还原符号

import Foundation
import IOKit

struct BatterySnapshot {
    let external: Bool
    let volts: Double        // V
    let amps: Double         // A，负 = 放电
    let percent: Int?
    let tempC: Double?

    /// 电池口功率（W）：充电为正、放电为负
    var powerW: Double { volts * amps }
}

enum BatterySource {
    static func snapshot() -> BatterySnapshot? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        // 定向读取 5 个键，替代全量字典展开+转换（性能优化 P6）。
        // Create 系列返回 retained 引用，必须 takeRetainedValue 释放
        func num(_ key: String) -> Double? {
            guard let ref = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() else { return nil }
            return (ref as? NSNumber)?.doubleValue
        }
        func amps() -> Double? {
            guard let ref = IORegistryEntryCreateCFProperty(service, "Amperage" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue(),
                  let n = ref as? NSNumber else { return nil }
            return Double(Int32(truncatingIfNeeded: n.int64Value)) / 1000.0
        }

        guard let volts = num("Voltage"), let a = amps() else { return nil }
        return BatterySnapshot(
            external: num("ExternalConnected").map { $0 != 0 } ?? false,
            volts: volts / 1000.0,
            amps: a,
            percent: num("CurrentCapacity").map { Int($0) },
            tempC: num("Temperature").map { $0 / 100.0 })
    }
}
