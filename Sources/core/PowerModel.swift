// PowerModel.swift — 整机瓦数双态公式（口径来源：docs/RECON.md「PDTR 校准记录」）
//   电池供电：整机 = 电压 × |电流|（电池是唯一电源，精确）
//   插电：    整机 ≈ PDTR − max(0, 电池口功率)（PDTR=适配器输出，减去充进电池的部分）

import Foundation

struct PowerReading {
    let external: Bool
    let systemWatts: Double
    let pdtrWatts: Double?
    let batteryTermW: Double
    let detail: String       // 口径说明，给人看
}

enum PowerModel {
    static func compute(battery: BatterySnapshot, smc: SMCSensor) -> PowerReading {
        let battW = battery.powerW
        if !battery.external {
            return PowerReading(external: false, systemWatts: abs(battW),
                                pdtrWatts: nil, batteryTermW: battW,
                                detail: "电池供电 电压×电流")
        }
        let chargeW = max(0, battW)
        if let pdtr = smc.double("PDTR") {
            return PowerReading(external: true, systemWatts: pdtr - chargeW,
                                pdtrWatts: pdtr, batteryTermW: battW,
                                detail: "插电 PDTR \(fmt(pdtr)) − 充电 \(fmt(chargeW))")
        }
        // PDTR 读取失败时只能显示电池口口径，明确标注不可信
        return PowerReading(external: true, systemWatts: chargeW,
                            pdtrWatts: nil, batteryTermW: battW,
                            detail: "插电但 PDTR 不可用，此值为充电功率非整机")
    }

    static func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
}
