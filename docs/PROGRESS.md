# powermon PROGRESS

> 项目一句话：MacBook M3 功耗监控菜单栏 app（SwiftUI），随时回答三个问题——
> ① 现在整机多少瓦 ② 电被谁吃了 ③ 趋势如何。
> 自用、本地、不发布。会话中断后从这里恢复。
> ⚠️ 2026-10-18 项目目录随工作区改名归类，现在位于 `~/Documents/Code/硬件-M3功耗监控/`。

## 已拍板的决策

- 形态：**菜单栏 app + 报表**（SwiftUI MenuBarExtra）
- 技术栈：**Swift/SwiftUI**（M0 侦察工具用 C，M1 起全部 Swift）
- 精度口径：**两级方案**——日常免 sudo（电池口 + SMC + ps 排行）；看精确 CPU/GPU 分项时手动跑 sudo powermetrics（M2.5 再接）
- 项目名 powermon 为代号；app 名 PowerMon
- 节奏定稿：瓦数/温度 2s、Top5 约 4s、趋势点 10s、CSV 10s/行（v1.0 曾写 5s，实测对齐后改文案）

## 里程碑

- [x] **M0 数据侦察**（2026-10-18）：三条数据路验证完毕，结论见 [docs/RECON.md](docs/RECON.md)。
- [x] **M1 采集核心**（2026-10-18）：SMCSensor（80 字节布局）/ BatterySource（补码处理）/
      PowerModel（双态瓦数公式）/ ProcessRanker + CLI `now`/`record`。
- [x] **M2 菜单栏 app**（2026-10-19）：SwiftUI MenuBarExtra（.window 样式）交付，v1.0 门禁全绿。
  - 目录：`Sources/core/`（共享）、`Sources/cli/`、`Sources/app/`（6 文件）、`packaging/Info.plist`
  - 构建：`make` = CLI；`make app` = build/PowerMon.app（ad-hoc 签名，LSUIElement）
  - 面板：瓦数大字（>25W 变红+菜单栏加!）/ 四路温度 / 60 分钟趋势曲线 / Top5 大户 / 退出
  - 验收（docs/SPEC.md G1–G7）：构建零警告、CPU 0.0%、RSS 83–85MB 稳定、CSV 10s/行且
    与 CLI schema 逐列一致、AppleScript 干净退出；菜单栏视觉由用户确认
  - 独立评审：code-reviewer 出 A1/B1–B5/C1–C8（报告要点见下），A/B 全修，C 修 3 条备 5 条
- [x] **M2.1 耗电兽改版**（2026-10-19，commit d85c0df）：交互层重设计，数字退居面板。
  - 菜单栏：4 态状态图标（zzz/figure.walk/figure.run/lungs.fill 单色模板），异常追加 `!`
  - 显示层：10s EMA（α=0.18）+ 状态机三重滞回（hotTicks=4 跨度 6s、<20W 解除、态间 ±1W 缓冲）
  - 面板：兽 + 台词气泡（跑/喘点名 Top1 添柴人，每句含均值瓦数）+ 温度 + 均值趋势线 + 添柴榜
  - 数据层不动：2s 采样、CSV 10s/行仍记原始瞬时值；趋势线改画均值线（SPEC F1/F2/F5 修订）
  - 评审：无 A 级；B1-B3（判定口径/SPEC 措辞）+ C2/C3/C4/C5 已修；实测 CPU 0.0%、RSS 稳定
  - ⚠️ RSS 有一次性的 ~96MB 瞬态峰（SF Symbols/渲染缓存），随后回落 83–84MB 基线——不是泄漏
- [x] **M2.2 性能优化轮**（2026-10-19，子代理评审→实现→实测闭环）：平均 CPU 1.89% → **0.22%**（-88%，10:32 仅用 1.39s CPU）。
  - 性能评审关键推翻：ps 子进程实测只占 ~0.005%（0.4–1ms/次），**真正大头是每 2s 拍 12 个 @Published 无条件写入的 SwiftUI/AppKit 失效风暴（~80%）**
  - P1 主攻：apply() 全字段等值守卫 + 菜单栏图标拆独立 MenuIconStore（App 层去 @StateObject），界面重算只由图标状态变化驱动
  - P2 SMC KeyInfo 缓存（mach 调用减半）；P3 CPU 温度键 9→2（TPDX 即最大值）+ 键表上收 core/SensorKeys.swift（消 C4）；P5 定时器 leeway 200ms；P6 电池源 5 键定向读取；P8 CLI formatter 单例/去重复 init
  - 评审反对项已记录：ps→libproc 无 CPU 收益不做（差分口径升级留 M3 另行立项，需同步 CSV top1_cpu 语义）；HistoryStore 不碰（A1 坑）；不拉长采样周期（破坏 F1/F5/F6）
  - 实测：10:32 运行 CPU TIME 1.39s（0.22%），RSS 80.7MB 稳定，CSV schema 不变
- [x] **v1.2 高功耗通知**（2026-10-19，commit e798850）：M3 范围修订——**报表明确砍掉（用户拍板），只做通知**。
  - F9：进入喘气态（与 F1 滞回共用判定）投递无声横幅「持续高功耗 XW · 添柴人在添柴」；
    10 分钟冷却（投递成功才起算，评审 B1）；固定标识符顶替旧通知；面板开关默认开
  - 授权：启动请求一次 + 每次通知前实时查系统状态——用户事后在系统设置补授权**无需重启生效**
  - 已知事项：早期授权弹框被误点拒绝且 tccutil 重置失败 → 需到 系统设置→通知→PowerMon 手动打开；
    合成负载（10×yes）实测最高 21W（PDTR 平均口径+热节流），25W 门槛的真实触发留日常场景闭环
- [x] **v1.3 正式安装形态**（2026-10-19）：F10 登录自启 + F11 图标/安装。
  - 图标：packaging/gen_icon.swift（CoreGraphics 画圆角底+琥珀闪电）→ sips/iconutil → AppIcon.icns
  - `make install`：装入 /Applications + 自动迁移运行实例；Spotlight/Launchpad 可见
  - 面板新增"登录自启"开关（SMAppService.mainApp，默认关）；启动时路径自愈重注册（评审 B2：
    注册绑定路径，从 build/ 开自启后搬家会失效，launch 时对 enabled/requiresApproval 重注册一次）
  - 已知坑：**@State 在新 SDK 是外部宏，裸 swiftc 找不到 SwiftUIMacros 插件**——View 里用
    ObservableObject 壳（LoginToggleState）替代；评审 B1/B3/B4 已修（requiresApproval 注销、
    status XPC 不进 Binding get、PROGRESS 同步）
- [x] **v1.5 GLM 额度显示**（2026-10-26，F12）：面板新增 GLM Coding Plan 剩余额度（Pro 档实测：5h 窗口/每周窗口/月度三条）。
  - 数据源：bigmodel.cn/api/monitor/usage/quota/limit（Bearer = Coding Plan 专用 key，用户手动粘贴）
  - key 存 ~/Library/Application Support/powermon/plan-key（0600）；面板打开/手动刷新才请求；可清除
  - baseName 归一化 Unicode 空格（NBSP 等，防进程名匹配失败）；隐私声明更新为"默认全本地，额度查询为可选联网"
  - 侦察记录：推理响应头无额度字段（Claude 惯例不适用）；/api/biz/plan/usage 需控制台登录态而非 api-key；
    最终数据源 = 前端懒加载 chunk 1540/3808/1361 里挖出的 /api/monitor/usage/quota/limit
  - v1.5.2 额度区重开发（用户给控制台截图参考）：三列横排对齐智谱控制台——小标签 +
    大字百分比（<15% 变红）+ 重置点（今天 HH:mm / 跨天 M月d日）+ 三色进度条（蓝/绿/紫）；
    语义修正：TIME_LIMIT 官方叫法"工具调用"（计数 search-prime/web-reader/zread）；
    标题行加"更多 >"跳控制台用量页；"重置次数"徽章接口无字段，未实现
- [x] **公开发布**（2026-10-24，用户拍板）：https://github.com/ymislp1993/powermon （MIT）
  - 发布副本流程：/tmp 干净副本——**剔除 recon/（GPL 参考代码隔离）**、.mimosa、图标中间产物，
    文档清理后单 commit 首发式推送；本地开发仓库继续在原位滚动
  - README（功能/构建/功耗口径/隐私/致谢）+ LICENSE(MIT) + gh repo create --push
  - ⚠️ 提交作者邮箱为 android_ym@163.com（公开可见）；后续提交如需隐私可换 GitHub noreply
- [x] **v1.5.1 面板收纳改版**（2026-10-26，方案 A 落地，commit 4cc2bc4）：用户反馈元素过多。
  - ui-designer 子代理出三方案视觉稿（可视化目录 ui-collapse-proposals.html），用户拍板 A「分区折叠」
  - footer 重构：通知/登录自启开关 + 清除 Key + 隐私说明收进「设置」折叠区（默认收起，gearshape 行）；
    退出常驻设置行右端；采样参数小字行删除
  - 额度区压缩：查询时间并入标题行、重置时间改 .help() 悬浮、原底部"查询时间+清除 Key"行删除
  - 面板高度 505→约 465pt；常看区（兽/台词/瓦数/温度/趋势/添柴榜）一字未动
- [x] **v1.5.3 趋势折叠**（2026-10-26，用户反馈趋势优先级低）：趋势区默认折叠为一行摘要
  （chevron + 标题 + ↓min ↑max 常显），点开展开折线图；SPEC F5 同步修订
- [x] **v2 视觉语言落地**（2026-10-26，commit 9c21e6c）：DesignTokens.swift（深浅双态色源+字体四级+间距）+
  PanelView 全面换装（瓦数 32pt 琥珀主角、tempCell 上下结构、灰阶添柴榜、hairline 分隔、
  额度三列 PM 色条）。SF Symbols 兽形暂用（手绘 SVG 四态兽见 pending/ 待查——SVGPathParser
  在 glyph 函数触发诡异类型推断错误，疑似编译器对该文件上下文的推断异常，待日后再战）
- [x] **v1.4 添柴榜中文化**（2026-10-19，commit 185a8e6）：本地词典方案（用户拍板，不做联网 AI）。
  - Sources/core/ProcessNameLocalizer.swift：**280 条**人工条目（系统守护进程+常见 App+开发运行时）
  - 词条来源：record.csv 历史 top1 全量去重（279 个）逐条翻译，**回放验证 0 未命中**
  - 面板主显中文、悬浮看英文原名；未命中保留原名；CSV 仍记原始名（数据层不动）
  - 台词与 F9 通知的添柴人共用 displayName（词典优先）——清洗链合并进 Localizer.baseName（评审 B1）
  - 排查教训：这轮"词典漏网"排查烧了一小时，真凶=**词典键拼写错误**（DoubaoWork 误拆成
    doubao work）。期间 /tmp 测试文件被自己后续调试互相覆盖，多次回放结果互相矛盾全是
    陈旧二进制假信号——**每次重测必须重编 + 显式 echo 编译退出码 + 重新生成输入文件**
  - 评审：无 A 级；714 个本机进程回放验证命中路径；C 级 6 条修 5 备 1（electron 死键标注）
- [ ] **M2.5 可选**：sudoers 免密 powermetrics 精确采集器。
- [ ] **M3 候选（重新定义）**：添柴榜差分口径升级（ps 生命周期平均 → 区间瞬时，需同步 CSV top1_cpu 语义）；ps 换系统 API 的语义立项。**登录自启已做（v1.3 F10）；报表不做（用户明确砍掉）**。

## M2 评审遗留（下轮可捡）

- C1 CLI `record` 输出文件创建失败会强解崩溃（M1 遗留，SPEC 原样迁入范围）
- C4 温度键常量在 cli/main.swift 与 app/Sampler.swift 两处手工同步（可上收 core）
- C2 maxDouble 过滤 ≤0 后，CLI 温度 ≤0 时显示 `--`（行为改进，非回归）
- PDTR 低载读数 0.7–1.3W 存疑（传感器平均窗口？），负载下已验证可信（9→32W 动态）
- 内存门槛修订记录：80MB→100MB（平台基线 ≈83MB，防泄漏意图改由"5 分钟漂移<20%"承接）

## 下一步（M3 开工清单）

1. 日/周汇总窗口（数据已有：record.csv，直接聚合）
2. 高功耗系统通知（UNUserNotificationCenter，需处理通知授权）
3. 登录自启（SMAppService）——v1.1 候选

## 已知坑（会话恢复必读）

- **SMC 结构体 80 字节，vers 段 6 字节**——手算 84 会全盘失败；偏移固化在
  Sources/core/SMCSensor.swift 头注释，别再重算
- **CSV 轮转必须先关句柄→rotate→重新 prepare**（评审 A1：向已关闭 FileHandle 写入 = ObjC 异常崩溃，try/catch 接不住）
- **applicationWillTerminate 里不能走异步清理**——terminate 不等异步任务，用 MainActor.assumeIsolated 同步执行
- Sampler 状态只能在其自有队列碰，shutdown 用 queue.sync 等 in-flight 采样结束（评审 B1）
- GitHub 取物走 `gh api`（curl 直连超时）；SMC 键总数读 `#KEY`；温度是 `flt` 不是 sp78
- 风扇键不在 SMC 枚举里（待查 IOReport）；注册表顶层没有电池 Temperature，电池温度走 `TB0T`
- ioreg 拔电时 Amperage 是 2^64 补码负数，按 Int32 截断还原
- Swift String(format:) 的 `%s` 不吃 Swift 字符串；对齐用 `.padding(toLength:)`
- CFMutableDictionary 转 Swift 字典过 `NSDictionary` 再 `as? [String: Any]`
- 大数组字面量混合 map/`??` 会让 swiftc 类型检查超时，拆成逐列 append
- GPU 空闲时 Tg0x 回读 0.0，温度取最大值时过滤 ≤0

## 环境

- macOS 27.2，Swift 6.4（CLT，无完整 Xcode）
- CLI：`make && ./powermon now`
- App：`make app && open build/PowerMon.app`（退出：面板"退出"按钮）
- 数据：`~/Library/Application Support/powermon/record.csv`（20MB 轮转 .1）

## 运维坑（系统级）

- **菜单栏整体点不动 ≠ app 的锅，凶手常是 MenuBarAgent 卡死**（2026-10-19 实战：反复
  pkill/重装 app 十几次后触发，连苹果菜单都点不动，窗口扫描无遮挡、主线程健康）。
  修复：`killall MenuBarAgent SystemUIServer ControlCenter`（launchd 秒级自动拉起，
  菜单栏闪一下重建，不影响任何 app）。预防：尽量用面板"退出"而非 pkill。
