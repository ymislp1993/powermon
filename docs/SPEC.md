# powermon v1.0 产品规格与验收标准（SPEC）

> 本文件是 M2/M3 实现、自测、评审的唯一依据。任何验收争议以本文为准。
> 定稿人：leader（ZCode）· 2026-10-18 · 目标版本 v1.0

## 产品定位

MacBook M3 菜单栏功耗监控。随时回答三个问题：现在整机多少瓦 / 电被谁吃了 / 趋势如何。
自用、本地、免 sudo、不发布。

## v1.0 功能清单（全部必做）

| # | 功能 | 说明 |
|---|---|---|
| F1 | 菜单栏耗电兽（v1.1 修订，替代数字版） | 显示 10s EMA 均值驱动的状态图标（SF Symbols 单色）：`<10W` 睡（`zzz`）、`<20W` 走（`figure.walk`）、`<25W` 跑（`figure.run`）；**持续 ≥5s ≥25W** 进入异常喘气（`lungs.fill`）并追加 `!`，EMA 回落 `<20W` 解除（滞回）。菜单栏不出现数字。原始瞬时值仍 2s 采样并全量落 CSV |
| F2 | 下拉面板·功率区 | 耗电兽大图标 + 台词气泡：每句台词含均值瓦数；跑/喘两态点名 Top1"添柴人"（如"救命，Chrome 把我烤到 31W 了！！"）+ 口径小字（电池供电 电压×电流 / 插电 PDTR−充电）|
| F3 | 下拉面板·温度区 | CPU / GPU / 电池 / 环境 四路温度，读不到显示 `--`，不得崩溃 |
| F4 | 下拉面板·大户榜 | "添柴榜"：CPU 占用 Top5（进程名 + 百分比横条），约 4s 刷新；Top1 同时作为台词点名的添柴人。v1.4：进程名经本地词典中文化（Sources/core/ProcessNameLocalizer.swift，80 条人工条目），悬浮显示英文原名，未命中保留原名；CSV 仍记原始名 |
| F5 | 下拉面板·趋势曲线 | 过去 60 分钟**10s EMA 均值线**（标注为均值线的最大/最小，非瞬时极值；瞬时值只在 CSV）。v1.5.3：默认折叠为一行摘要（min/max 常显），点开展开折线 |
| F6 | 历史落盘 | CSV 追加至 `~/Library/Application Support/powermon/record.csv`，列与 CLI `record` 完全一致；超 20MB 轮转为 `.1` |
| F7 | 退出入口 | 面板内"退出"按钮，点击后进程干净退出 |
| F8 | 降级可用 | SMC/电池任一数据源失败：对应项显示 `--`，其余照常，绝不崩溃退出 |
| F9 | 高功耗通知（v1.2） | 进入兽喘气态（即 F1 滞回判定成立）时投递**无声横幅**：「持续高功耗 XW · 添柴人在添柴」；10 分钟冷却（投递成功才起算）；面板开关（默认开，UserDefaults 持久化）；授权实时查询——用户事后在系统设置打开授权无需重启生效；固定标识符，后一条顶替前一条（通知中心最多保留一条）|
| F10 | 登录自启（v1.3） | 面板开关（默认关）；SMAppService.mainApp 注册/注销；建议在 app 装入 /Applications 后使用 |
| F12 | GLM 额度显示（v1.5，可选联网） | 面板显示 GLM Coding Plan 剩余额度（5 小时窗口/每周窗口/月度，Pro 档实测）；
数据源 `bigmodel.cn/api/monitor/usage/quota/limit`（Bearer = 用户自己的 Coding Plan API Key）；
Key 手动粘贴、存本机 0600 文件、面板可清除；面板打开或手动刷新时才请求，默认不配置则零外发 |
| F11 | 正式安装形态（v1.3） | 自带应用图标；`make install` 装入 /Applications（Spotlight/Launchpad 可见），并自动迁移运行实例 |

## 非目标（明确不做）

powermetrics 二级精确采集、**日/周报表窗口（2026-10-19 用户明确砍掉）**、多语言、偏好设置界面（面板内通知/登录自启开关除外）。登录自启已于 v1.3 实现（F10）。

## 性能标准

| 指标 | 门槛 |
|---|---|
| 常驻内存（RSS） | < 100MB（2026-10-19 leader 修订：实测本机 SwiftUI MenuBarExtra 平台基线 ≈83MB，原 80MB 门槛低于平台底噪，无判别力；防泄漏意图由下条承接）|
| 内存稳定性 | 运行 5 分钟内 RSS 漂移 < 20%，且无单调增长趋势 |
| 空闲 CPU | < 3%（面板关闭时，2s 采样节奏下）|
| 面板打开响应 | 点击后 200ms 内可见内容 |

## 可靠性标准

- 连续运行 ≥ 5 分钟无崩溃、无内存持续增长（RSS 波动 < 15%）
- 采样循环任何单次失败不得终止定时器
- 进程退出码 0（用户主动退出时）

## 代码标准

- Swift 6.4 + SwiftUI，`swiftc` + CLT 可构建，不依赖 Xcode 工程
- 不携带 GPL 代码（SMC 布局为自写，参考实现仅作格式对照）
- 中文注释，风格与 M1 现有代码一致；SMCSensor 80 字节布局**不许改动**
- 目录结构：`Sources/core/`（共享：SMCSensor/BatterySource/PowerModel/ProcessRanker）、
  `Sources/cli/`（main.swift 原样迁入）、`Sources/app/`（菜单栏 app）、`packaging/Info.plist`
- 构建：`make` = CLI powermon（行为不变）；`make app` = build/PowerMon.app；ad-hoc 签名

## 验收清单（leader 逐项打勾，全绿才交付）

| Gate | 方法 | 通过条件 |
|---|---|---|
| G1 构建 | `make && make app` | 零 error；app bundle 结构完整（Info.plist + 可执行文件）|
| G2 启动 | `open build/PowerMon.app`，5s 后 `ps` | 进程存活，菜单栏出现瓦数（人工/截图确认）|
| G3 性能 | `ps -o pcpu,rss` 连测两次（间隔 60s）| RSS < 80MB 且波动 < 15%；CPU < 3% |
| G4 落盘 | 检查 record.csv | 行数随时间增长，表头与 CLI schema 一致 |
| G5 退出 | `pkill -x PowerMon` 前先点退出按钮或 `osascript quit` | 进程消失，无残留 |
| G6 复审 | code-reviewer 对照本 SPEC | 无 A 级问题；B 级修复或经 leader 书面豁免 |
| G7 CLI 回归 | `./powermon now` | 输出字段与 M1 验收一致 |

## 已知口径（实现时引用，不要重新发明）

- 双态瓦数公式、PDTR 含义、温度键名：见 docs/RECON.md「PDTR 校准记录」
- 拔电时 Amperage 为负（注册表可能存补码），BatterySource 已处理
