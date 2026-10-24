// SensorKeys.swift — 温度传感器键名共享常量（M3 实测有效，来源 docs/RECON.md）
// 上收为唯一出处：Sources/cli/main.swift 与 Sources/app/Sampler.swift 统一引用，
// 消掉此前两处手工同步的隐患（评审 C4 / 性能优化 P3）

enum SensorKeys {
    /// CPU 温度候选键：TPDX 即 TPD0–7 的合成最大值（RECON 实测），TPD0 兜底；
    /// 9 键降 2 键后读数口径不变（max(TPDX, TPD0) = TPDX）
    static let cpuTempKeys = ["TPDX", "TPD0"]
    /// GPU 温度候选键：逐核心读最大值（显示精度优先，保持 6 键）
    static let gpuTempKeys = ["Tg0C", "Tg0D", "Tg0O", "Tg0P", "Tg0W", "Tg0X"]
    /// 环境温度
    static let ambientKey = "TAOL"
    /// 电池温度（注册表顶层没有电池 Temperature，走 SMC 的 TB0T）
    static let batteryTempKey = "TB0T"
}
