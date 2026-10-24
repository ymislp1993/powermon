# powermon M0 数据侦察报告

> 侦察日期：2026-10-18 深夜
> 机器：MacBook Pro 14" M3（Mac15,12）/ macOS 27.2 / Swift 6.4（CommandLineTools，无需完整 Xcode）
> 目的：验证"电脑功耗软件"三条数据路的真实成色，再决定 M1 怎么写

## 结论速览

三条数据路：**电池接口 ✓、SMC 传感器 ✓（均免 sudo）、powermetrics 待接入（需 sudo，二级方案）**。
两级精度方案成立：日常免 sudo 可拿到整机瓦数 + 全套温度 + 系统功率候选键。

| 数据源 | sudo | 能拿到什么 | 验证结果 |
|---|---|---|---|
| `ioreg -rn AppleSmartBattery` | 否 | 电池电压/电流/充电功率/电量/电池温度 | ✓ 实测 13.06V × 0.39A（≈5.1W 充电中）；电池温度 36°C，与 SMC TB0T 一致 |
| SMC（AppleSMC user client） | 否 | 1852 个键可枚举：全套温度、电源轨功率/电流 | ✓ 自研 `recon/smc_scan`，见下 |
| `powermetrics`（/usr/bin） | 是 | CPU/GPU/ANE/进程级精确功耗 | 未测，M2.5 再接；命令在位 |

## SMC 关键发现（Mac15,12 实测）

- 键总数存在特殊键 **`#KEY`** 里（ui32 大端，本机 1852）。网传"KEYINFO 查询拿总数"在本机不成立。
- **温度格式已从 sp78 改为 `flt`（IEEE float）**——Intel 时代的 sp78 键全部消失，这就是
  osx-cpu-temp 在 M3 上读 0.0°C 的原因。温度键全表见 `recon/smc_sensors.txt`。
- 温度键地图（采样时刻，负载中等）：
  - `TPD0`–`TPD7`：CPU 性能核集群 61–67°C；`TPDX` = 其中最高温（做"CPU 温度"展示正合适）
  - `Te04`–`Te0P`：能效核 65–77°C
  - `Tg0C/D/O/P/W/X`：GPU 66–72°C
  - `TCMb`/`TCMz`/`TVD0`：约 74/83°C（内存/互联）
  - `TB0T`/`TB1T`/`TB2T`：电池 35–36°C；`TAOL`：环境 29°C
  - Intel 时代旧键（`TG0B` 等，ioft 类型）读出 0 或 nan，已死，忽略
- 功率键已定性（2026-10-18 拔电校准）：
  - **`PDTR` = 适配器输出侧总功率**：插电 18.51W，拔电 0.00W。不能单独当整机功率用。
  - **整机瓦数公式（M1 按此实现）**：
    - 电池供电：`整机 = 电压 × |电流|`（唯一电源，精确。校准样本：12.977V × 0.264A ≈ 3.43W）
    - 插电：`整机 ≈ PDTR − max(0, 电压×电流)`（减去充进电池的部分；样本：18.51 − 5.1 ≈ 13.4W）
  - `PPBR` 拔电 7.83W ≠ 电池输出 3.4W，口径不明，弃用观察。
  - 分轨功率 `PP0b`…、分轨电流 `IP0b`…（单位疑为 W/A，仅排行用，不做绝对值承诺）。
- **风扇键未出现在 1852 键枚举中**（全 dump 无 F 开头键）。遗留问题，非主线阻塞；
  备选：IOReport 或 powermetrics 的 fan 采样器。

## 数据口径提醒（写进产品逻辑）

- 电池放电时：整机功率 = 电压×电流，精确。
- 插电时：电池口只给充电功率，整机功率须靠 PDTR 或估算 —— M1 两条都要，按插电状态切换口径。

## 踩坑记录（下会话直接复用）

1. 本网络 curl 直连 raw.githubusercontent.com 超时、常见镜像失效；**取 GitHub 内容一律走 `gh api`**（已验证通）。
2. SMC 键总数：读 `#KEY`。
3. Apple Silicon 温度是 `flt`；解码格式参考 `smc_scan.c`（flt/fpe2/flt /ioft 四类）。
4. `SMCReadKey` 是两步：先 `SMC_CMD_READ_KEYINFO`(9) 拿 dataType/dataSize，再 `SMC_CMD_READ_BYTES`(5) 读值；
   IOConnectCallStructMethod 的 selector 固定 `KERNEL_INDEX_SMC=2`。
5. 源码参考：`recon/smc-ref.c|smc.h`（lavoiesl/osx-cpu-temp，GPLv2，原作者 devnull 2006）——
   仅作侦察参考，M1 产品代码将重写为 Swift，不携带 GPL 代码。

## PDTR 校准记录（2026-10-18 23:20，已完成）

| 状态 | PDTR | 电池电压 | 电池电流 | 电池功率 | 结论 |
|---|---|---|---|---|---|
| 插电充电（99%） | 18.51W | 13.067V | +392mA | 5.12W（充电中） | PDTR 含充电功率 |
| 拔电放电（100%） | **0.00W** | 12.977V | −264mA | **3.43W（整机）** | PDTR 归零，是适配器侧键 |

另：拔电时 `ioreg` 的 Amperage 以 2^64 补码显示（18446744073709551352 = −264），
解析必须按有符号整型处理，直接当无符号会算出天文数字。
