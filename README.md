# PowerMon · 耗电兽

**Mac 菜单栏功耗监控 · Apple Silicon 原生 SwiftUI · 全程免 sudo**

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](https://github.com/ymislp1993/powermon)
[![Swift](https://img.shields.io/badge/Swift-6.4-orange)](https://github.com/ymislp1993/powermon)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

> 回答三个问题：现在整机耗多少瓦？电被谁吃了？趋势长什么样？
> 菜单栏住着一只耗电兽——机器闲它睡觉，高载它狂奔，持续过载它会报警。

## 它能做什么

- **菜单栏常驻**：一只随负载变身的耗电兽（睡觉 → 散步 → 奔跑 → 喘气报警），不点开也能感知系统状态
- **点开面板**：整机瓦数（带口径说明）、CPU/GPU/电池/环境四路温度、过去 60 分钟功耗趋势线
- **添柴榜**：CPU 占用 Top5 进程排行，**进程名自动翻译成中文**（内置 280 条词典，覆盖 macOS 系统守护进程与常见应用，悬浮显示英文原名）
- **高功耗通知**：持续 6 秒超过 25W 阈值时投递系统通知（带滞回防抖 + 10 分钟冷却，面板可开关）
- **历史记录**：CSV 落盘，20MB 自动轮转，可用任何工具分析
- **登录自启**：面板内一键开关（SMAppService）

## 系统要求

- macOS 13.0+
- Apple Silicon（M1/M2/M3/M4；功耗口径在 M3 MacBook Pro 实测校准）
- [Xcode Command Line Tools](https://developer.apple.com/xcode/resources/)（`xcode-select --install`，**无需完整 Xcode**）

## 构建与安装

```bash
git clone https://github.com/ymislp1993/powermon.git
cd powermon

# CLI 快照工具：实时查看瓦数/温度/耗电大户
make

# 菜单栏应用（含应用图标）
make app

# 正式安装：装入 /Applications，Spotlight/Launchpad 可见
make install
```

CLI 用法：

```bash
./powermon now                        # 一次快照
./powermon record --interval 2        # 持续记录 CSV（Ctrl-C 结束）
```

## 功耗数据是怎么来的（技术核心）

Apple Silicon 没有公开的整机功耗 API，PowerMon 用三条免费（免 sudo）数据路拼出可信读数：

| 数据路 | 来源 | 说明 |
|---|---|---|
| 整机瓦数（电池供电） | `AppleSmartBattery` 电压 × 电流 | 唯一电源，精确 |
| 整机瓦数（插电） | SMC `PDTR` 键 − 充电功率 | 适配器输出侧功率扣掉充进电池的部分 |
| CPU/GPU 温度 | SMC 传感器（`TPDX`/`Tg0x` 等） | 免 sudo 直读，实测与系统报告一致 |

> 详细的传感器键位表、M3 实测校准数据与排查笔记见 [docs/RECON.md](docs/RECON.md)。
> 验收标准与功能清单见 [docs/SPEC.md](docs/SPEC.md)，开发日志见 [docs/PROGRESS.md](docs/PROGRESS.md)。

## 隐私

**全本地运行**：不联网、不上报、不采集任何数据。历史记录只写入本机
`~/Library/Application Support/powermon/`。

## 项目结构

```
Sources/
  core/   共享采集层（SMC 读取器 / 电池 / 功耗模型 / 进程排行 / 中英词典）
  cli/    命令行入口（now / record）
  app/    菜单栏应用（SwiftUI MenuBarExtra）
packaging/  图标生成脚本 + Info.plist
docs/      SPEC（验收标准）/ RECON（数据侦察与校准）/ PROGRESS（开发日志）
```

## 已知限制

- 插电且电池满时，瓦数为适配器侧读数，低负载下精度一般（约 ±1W）
- 进程级只有 CPU 占比排行，无逐进程瓦数（需 sudo 的 `powermetrics`，暂未接入）
- 风扇转速不在 SMC 枚举范围内，未显示

## 致谢

- SMC 读取接口（键值结构、两段式读取协议）参考了 2006 年 devnull 的经典 SMC 工具与
  [osx-cpu-temp](https://github.com/lavoiesl/osx-cpu-temp) 的公开实现（本项目 Swift 代码为独立重写）
- 灵感来自 [Stats](https://github.com/exelban/stats) 与 macOS 活动监视器

## License

[MIT](LICENSE)
