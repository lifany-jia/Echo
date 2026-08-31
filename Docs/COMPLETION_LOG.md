# COMPLETION_LOG.md — 完成日志

> 用于记录“做完了什么、验证了什么、现在推进到哪”。每次 Codex 完成一个逻辑任务后必须追加，不覆盖历史。

## 状态枚举

- `DONE`
- `IN PROGRESS`
- `BLOCKED`
- `NOT STARTED`
- `NOT RUN`

---

## 当前阶段总览

| Stage | 内容 | 状态 | 最近验证 |
|---|---|---|---|
| 0 | Build Baseline | DONE | `swift build --package-path EchoForest.swiftpm` PASS x2 |
| 1 | Static Experience | DONE | `swift build` PASS + flow self-test PASS |
| 2 | Audio Input | DONE | 模拟器实测 PASS（权限允许/拒绝、真实 buffer）；真机 NOT RUN |
| 3 | Audio Metrics | DONE（代码层） | build PASS + 确定性 DSP 自测 PASS；真机音频集成 NOT RUN |
| 4 | Growth Engine | DONE（代码层） | build PASS + generator 自测 PASS；实时耦合 NOT STARTED |
| 5 | Real-time Coupling | DONE | 模拟器实测 PASS（声音驱动生长、频率响应、Result 真实 DNA）；真机耦合 NOT RUN |
| 6 | Forest Persistence | DONE | build PASS + 持久化自测 PASS + kill/relaunch 实测 PASS |
| 7 | Presentation Polish | NOT STARTED | NOT RUN |
| 8 | Submission Hardening | NOT STARTED | NOT RUN |

---

## 日志模板

复制以下区块追加：

```md
## YYYY-MM-DD HH:mm — <任务标题>

**Status:** DONE / IN PROGRESS / BLOCKED

### 完成
- 

### 验证
- Command: `<实际命令>`
- Result: PASS / FAIL / NOT RUN
- Notes: 

### 未完成 / 风险
- 

### Commit
- `<hash> <type(scope): subject>`
```

---

## 2026-08-31 — 项目治理文档初始化

**Status:** DONE

### 完成
- 定义 Echo Forest 核心创意与 MVP 边界。
- 写入参赛硬约束、三分钟体验与离线/25MB 限制。
- 定义渐进式实现 Stage 0–8。
- 定义 Conventional Commit 强制规范。
- 建立测试计划、代码日志与新对话交接模板。

### 验证
- Command: `文档人工检查`
- Result: PASS
- Notes: 当前仅为项目治理文档，尚未创建或验证 Swift Playground 代码。

### 未完成 / 风险
- SwiftPM App Playground 尚未创建。
- 音频分析与植物生成尚未实现。
- 真机麦克风能力尚未验证。

### Commit
- `待 Codex 在真实仓库初始化后填写`

## 2026-08-31 10:50 — Stage 0 Build Baseline

**Status:** DONE

### 完成
- 初始化 Git 仓库。
- 创建 `EchoForest.swiftpm` App Playground 基线包。
- 新增最小 SwiftUI App 入口、`AppStage.forest` 和 Forest 首屏。
- 新增 `.gitignore`，排除 `.build`、DerivedData 与本机状态文件。

### 验证
- Command: `swift build --package-path EchoForest.swiftpm`
- Result: PASS
- Notes: 连续执行 2 次均成功。当前环境只有 Command Line Tools，`xcodebuild` 无法运行；App Playground 手动打开验证为 NOT RUN。

### 未完成 / 风险
- Stage 1 静态导航闭环尚未开始。
- 麦克风、音频分析、植物生成和持久化均尚未开始。
- Xcode/App Playground 图形化打开未在当前命令行环境验证。

### Commit
- `37269c1 build(app): add SwiftPM baseline`

## 2026-08-31 11:24 — Stage 1 Static Experience

**Status:** DONE

### 完成
- 单一 `AppStage` 枚举（forest / seed / growing / result）驱动全部页面切换，无多个独立 Bool。
- 四个页面齐备：ForestView / SeedView / GrowingView / ResultView。
- Forest：程序化森林底色 + 空林地块，文案“每一种声音，都可以生长。”，主按钮“种下一段声音”进入 Seed。
- Seed：中央静态程序化种子（SeedMark），提示“给它一点声音。”，不请求麦克风权限，开始按钮进入 Growing。
- Growing：`MockPlantCanvas`（SwiftUI Canvas / Path）绘制 mock 植物，页面明确标注“静态模拟，不是真实声音驱动”，结束按钮进入 Result。
- Result：mock 最终植物 + Mock Sound DNA（Pitch / Energy / Rhythm / Variation），数值来自固定 mock profile，按钮“种进森林”返回 Forest。
- 回到 Forest 后显示“已种下 N 棵 mock 植物”与植物网格，闭环成立；再次创作清空当前植物，不残留上次 GrowthState。
- 日志文件迁入 `Docs/`（CODE_LOG / COMPLETION_LOG / HANDOFF / TEST_PLAN），与 AGENTS.md 目录规范一致。
- `.gitignore` 忽略 `EchoForest.swiftpm/.swiftpm/` 本机状态目录。

### 验证
- Command: `swift build --package-path EchoForest.swiftpm`
- Result: PASS
- Notes: Apple Swift 6.3.3（swiftlang-6.3.3.1.3），arm64 macOS；“Build complete!”。
- Command: `swiftc <AppStage/EchoForestFlow/MockSoundProfile/MockPlantModel 源文件> SelfTests/Stage1FlowSelfTest.swift -o /tmp/stage1_flow_self_test && /tmp/stage1_flow_self_test`
- Result: PASS
- Notes: 输出 “Stage 1 flow self-test PASS”；断言覆盖 Forest → Seed → Growing → Result → Forest 闭环与二次创作重置。当前工具链缺少 Swift Testing 与 XCTest 模块，`swift test` 不可用，故以零依赖自测代替，编译的是项目真实 flow/model 源文件。
- Command: `xcodebuild`
- Result: NOT RUN
- Notes: 当前 active developer directory 为 Command Line Tools，无完整 Xcode；App Playground 图形化构建/运行无法在当前命令行环境执行。

### 未完成 / 风险
- 麦克风输入、RMS、pitch、onset 均未实现，属于 Stage 2–3。
- Growing 页为静态 mock 视觉，无真实声音驱动与动画，属于 Stage 4–5 / 7。
- 森林状态仅存在于当前运行周期内存，无磁盘持久化，属于 Stage 6。
- App Playground 手动打开验证 NOT RUN。

### Commit
- `580e07a chore(docs): relocate project logs under Docs/`
- `fd9248f feat(flow): build static creation loop`

## 2026-08-31 11:39 — Stage 2 Audio Input

**Status:** DONE（代码层；真实麦克风运行时验证 NOT RUN）

### 完成
- 新增 `Sources/Audio/AudioInputState.swift`：纯状态模型。权限四态（notDetermined / authorized / denied / unavailable）+ 会话阶段（idle / requestingPermission / permissionDenied / starting / listening / failed / stopped），独立于 AVFoundation，供零依赖自测。
- 新增 `Sources/Audio/AudioEngineController.swift`：AVAudioEngine 输入链路控制器（@MainActor @Observable）。负责权限请求、AVAudioSession（iOS）、inputNode + installTap、start / stop、tap 清理、错误状态。
- Seed → Growing 接入真实权限流程：点击“开始创作”才请求权限；允许则启动 engine，成功后才进入 Growing；拒绝或启动失败不进入 Growing，显示明确提示，可返回 Forest 或留在 Seed。
- Growing 显示 “Listening · 麦克风输入已启动” 徽标与轻量链路验证计数（收到 buffer 数、最近 frameLength）；无 RMS / 频谱等 Stage 3 指标。
- 生命周期：结束创作 / 返回 / 取消均安全 stop engine、移除 tap、清理会话状态；再次创作可重新安装 tap 并启动，无 duplicate tap。
- 音频 callback 只更新 OSAllocatedUnfairLock 保护的轻量计数；UI 状态由 500ms 主线程定时任务同步，避免每个 buffer 触发 SwiftUI 刷新。
- 包根新增 `Info.plist`（NSMicrophoneUsageDescription）；记录 Xcode Signing & Capabilities 添加 Microphone capability 为官方路径。
- `EchoForestFlow`：`startMockGrowing` 更名为 `startGrowing`，新增 `cancelGrowing`，防重复进入 Growing。

### 验证
- Command: `swift build --package-path EchoForest.swiftpm`
- Result: PASS
- Notes: Swift 6.3.3 / arm64 macOS；Build complete，无警告。
- Command: `swiftc <Stage1 源文件> SelfTests/Stage1FlowSelfTest.swift -o /tmp/stage1_flow_self_test && /tmp/stage1_flow_self_test`
- Result: PASS（Stage 1 flow self-test PASS，Stage 1 回归通过）
- Command: `swiftc <Stage1 + AudioInputState 源文件> SelfTests/Stage2AudioSelfTest.swift -o /tmp/stage2_audio_self_test && /tmp/stage2_audio_self_test`
- Result: PASS（Stage 2 audio state self-test PASS）
- Notes: 覆盖 permission state transition、denied path、engine failure path、失败后重试恢复、start / stop 生命周期、第二次创作状态重置。
- Command: 真实麦克风 buffer 验证（App Playground 图形运行 + 授权麦克风）
- Result: NOT RUN
- Notes: 当前环境只有 Command Line Tools，无法启动 App Playground、无法授权麦克风；不得声称“麦克风输入已验证正常”。

### 未完成 / 风险
- 真实 AVAudioEngine 运行时验证 NOT RUN（需 Xcode + 真机/模拟器授权麦克风）。
- Info.plist / Microphone capability 在最终 App Playground 的生效需在 Xcode 中确认。
- 音频会话中断（媒体服务重置、进入后台）未处理，属于后续 Stage。
- RMS / pitch / onset / Sound DNA 真实计算 / 生长映射 / 持久化均未实现（Stage 3+）。

### Commit
- `fe6142d feat(audio): add microphone input pipeline`

## 2026-08-31 11:47 — Stage 3 Audio Metrics

**Status:** DONE（代码层；真实麦克风 → analyzer 集成运行时 NOT RUN）

### 完成
- 建立指标模型：`SoundFrame`（即时 / 当前帧指标）+ `SoundProfile`（会话累计指标：duration / energy / peakEnergy / spectralCentroidHz / onsetCount / variation）。区分 instantaneous 与 accumulated。
- 建立独立分析层 `AudioAnalyzer`（AVAudioPCMBuffer → SoundFrame + SoundProfile）；AudioEngineController 不再承担 DSP。
- Step A — RMS / Energy：从 PCM float sample 真实计算 RMS（跳过 NaN / infinity，空 / 全非法返回 0），noiseFloor 以下能量为 0，sqrt 塑形后 clamp 到 0...1。
- Step B — Frequency Proxy：用 Accelerate `vDSP_DFT` 实现 Spectral Centroid（频域重心），明确命名为 frequency proxy，不冒充 Pitch；跳过 DC 避免低频偏置；静音返回 nil。
- Step C — Onset：能量域 transient 检测（threshold + jumpThreshold + cooldown），稳定音不持续乱触发，单次爆音不重复触发。
- Growing 页展示真实 Live Metrics（Energy / Spectral Centroid / Onset count / Duration），并明确标注 “Plant growth is still mock（Stage 3）”；植物视觉不随指标变化。
- 实时线程安全：tap callback 在锁内做轻量 DSP 并写线程安全 snapshot；主线程 500ms 低频同步到 SwiftUI，无每 buffer 高频刷新、无文件 IO、无 JSON、无植物逻辑。
- Result 页继续使用 MockSoundProfile 并明确标注 mock；未提前接真实 summary。
- tap 格式固定为标准 float32 mono 44.1k，分析层无需每帧格式转换。

### 验证
- Command: `swift build --package-path EchoForest.swiftpm`
- Result: PASS
- Notes: Swift 6.3.3 / arm64 macOS；Build complete，无警告。
- Command: `swiftc -framework Accelerate <SoundMath/SoundMetrics/SpectralCentroid/OnsetDetector> SelfTests/Stage3MetricsSelfTest.swift -o /tmp/stage3_metrics_self_test && 执行`
- Result: PASS（Stage 3 metrics self-test PASS）
- Notes: 覆盖 Energy（silence / 固定幅值 / 低幅值 / 高幅值 / clamp / noise floor / NaN 稳定性 / 空 buffer）、Frequency（低频 / 中频 / 高频 bin 对齐正弦，重心误差 < 2 Hz；静音返回 nil）、Onset（silence / steady / transient / cooldown 内与 cooldown 后）、Session profile 累计、输出无 NaN / infinity。
- Command: Stage 1 regression（Stage1FlowSelfTest）
- Result: PASS
- Command: Stage 2 regression（Stage2AudioSelfTest）
- Result: PASS
- Notes: permission denied path、start / stop、二次 start、状态重置均未破坏。
- Command: 真实麦克风 → analyzer 集成（App Playground 图形运行 + 授权麦克风）
- Result: NOT RUN
- Notes: 当前环境只有 Command Line Tools，无法运行 App Playground / 授权麦克风。确定性 DSP 测试 PASS 不代表真实声音分析已验证。

### 未完成 / 风险
- 真实麦克风 → analyzer 集成运行时 NOT RUN。
- 频率代理是 Spectral Centroid，不是 pitch；后续如需要真实音高，Stage 3 方案需替换或补充。
- 音频会话中断（后台、媒体服务重置）仍未处理。
- 植物生长映射、PlantGenerator、BranchModel、Growth Engine、持久化均未实现（Stage 4+）。

### Commit
- `ae524df feat(audio): add real-time sound metrics`

## 2026-08-31 12:03 — Stage 4 Growth Engine

**Status:** DONE（代码层）；Real-time microphone coupling: NOT STARTED

### 完成
- 建立 Plant 模块（纯数据，无 SwiftUI View / Path）：
  - `BranchModel`（起点 / 终点 / 二次曲线控制点 / 粗细 / 深度 / 父引用 / 弯曲度）
  - `PlantEvent`（leaf / flower 事件节点，含位置 / 尺寸 / 出现深度）
  - `PlantStructure`（主干 + 分枝 + 事件 + 元数据 + boundingBox + visibleCounts）
  - `PlantModel`（id / name / profile / structure）
  - `GrowthState`（当前步骤 / 总步骤 / advance / reset，模拟 progression）
  - `PlantGenerator`（SoundProfile + seed → PlantStructure）
- 五维映射（一句话可解释）：
  - Energy → 枝干粗细 / 生命力（trunk = (5 + 15·energy) × scale × slim）
  - Spectral Centroid → 生长方向 / 高度 / 分支张角（高 centroid → 更高、更向上、更纤长；低 → 更横向舒展）
  - Variation → 弯曲程度 / 分叉倾向（子分支数 1–3 阈值 + 弯曲系数）
  - Onset → 叶片 / 花事件（0 onset 无花；onset 越多事件越多，有上限）
  - Duration → 总体尺度 / 生长深度 / 节点预算
- 确定性：SplitMix64 seeded RNG 只作用于角度 / 位置 / 曲线等装饰细节；相同 profile + seed 结构完全一致。
- 输入规范化：clamp / normalize / fallback；NaN / infinity 不传播；硬上限（分支 ≤ 40、深度 ≤ 6、叶 ≤ 28、花 ≤ 8、onset ≤ 24）；无无限递归（深度有界）。
- 新渲染层 `PlantRenderer`：PlantStructure → SwiftUI Canvas（quad 曲线枝条 + 椭圆叶片 + 程序化花瓣），不重算声音映射；Growing / Result / Forest 共用。
- Growing 页由模拟 SoundProfile 驱动并逐步显现（GrowthState 模拟 progression，不接音频 callback）；Result 展示真实 PlantModel + 确定性模拟 SoundProfile DNA，明确标注“由模拟 SoundProfile 生成 · 未接麦克风”。
- 删除旧的 MockPlantModel / MockSoundProfile / MockPlantCanvas。

### 验证
- Command: `swift build --package-path EchoForest.swiftpm`
- Result: PASS（无警告）
- Command: `swiftc <SoundMetrics + Plant 模块源文件> SelfTests/Stage4PlantSelfTest.swift && 执行`
- Result: PASS（Stage 4 plant generator self-test PASS）
- Notes: 覆盖 Profile A/B/C 综合形态、same profile + same seed 完全一致、不同 seed 只变细节、Energy / Centroid / Variation / Onset / Duration 单变量、极端输入 clamp、NaN 不传播、数量硬上限、几何有限且在合理范围、GrowthState、visibleCounts 单调。
- Command: Stage 1 / Stage 2 / Stage 3 regression
- Result: 全部 PASS（Stage 1 flow / Stage 2 audio state / Stage 3 metrics）
- Command: 真实 App Playground / microphone runtime
- Result: NOT RUN（Command Line Tools 环境）

### 未完成 / 风险
- 真实麦克风 → 植物耦合属于 Stage 5，NOT STARTED；本阶段植物完全由模拟 SoundProfile 驱动。
- Growing 的“生长”是模拟 progression（定时逐步显现），不是动画 polish，也不是音频驱动。
- Result Sound DNA 展示的是确定性模拟 profile，不是真实会话 summary。
- Xcode / 真机图形运行仍未验证（NOT RUN）。

### Commit
- `c26e338 feat(plant): add deterministic growth engine`

## 2026-08-31 12:15 — Stage 5 Real-time Coupling

**Status:** DONE（代码层）；REAL MICROPHONE COUPLING NOT RUN

### 完成
- 建立实时耦合层：
  - `Sources/Plant/GrowthSession.swift`：纯核心，SoundFrame 序列 → 逐步生长的 PlantModel（可零依赖确定性自测）。
  - `Sources/App/LiveGrowthController.swift`：@MainActor @Observable 协调层，持有 GrowthSession，按固定 cadence 读取 metrics 并推进；View 不承担耦合逻辑。
- 增量生长：每 tick 只追加新枝 / 新事件，不每 buffer 重建整棵树；映射公式仍集中在 PlantGenerator（新增 initialStructure / appendGrowthStep / appendFlower，与 Stage 4 共享 normalize + makeTrunk）。
- 实时映射：
  - Energy → 新枝粗细 / 生长速度（growthAccumulator 随 energy·dt 累积）
  - Spectral Centroid → 新增长方向 / 张角（不叫 Pitch）
  - Variation → 后续弯曲（基于会话 / 平滑稳定值）
  - Onset → 每帧一次开花事件（analyzer cooldown 防重复）
  - Duration → 生长预算 / 最大步骤上限（maxSteps = 16）
- 平滑与门控：EMA（Energy / Centroid / Variation）；平滑 energy 低于 activationThreshold（0.06）时完全不推进，静音时势能缓慢衰减。
- 解耦：audio callback 仍只做 DSP + 线程安全 snapshot；RootView 以 150ms（约 6.7Hz）cadence 读取 latestFrame / profile 驱动 GrowthSession；UI 通过 @Observable 低频刷新。
- Growing：植物主视觉为实时生长模型（PlantRenderer + growthStep），Live Metrics 压缩为次要面板。
- Result：冻结 Growing 阶段的最终 PlantModel（不重新生成），Sound DNA 切换为真实会话 SoundProfile（Energy / Spectral Centroid / Onset / Duration / Variation，明确叫 Spectral Centroid 而非 Pitch）。
- 第二次创作：新 GrowthSession（植物 / GrowthState / 平滑值 / onset 计数 / 步骤全部重置），flow 使用 startGrowing(plant:) / finishGrowing(plant:) 保证同一棵植物贯通。

### 验证
- Command: `swift build --package-path EchoForest.swiftpm`
- Result: PASS（无警告）
- Command: `swiftc <SoundMetrics + Plant 模块源文件> SelfTests/Stage5CouplingSelfTest.swift && 执行`
- Result: PASS（Stage 5 coupling self-test PASS）
- Notes: Scenario A 静音不增长；B 大声比小声长更多且第一代新枝更粗；C 高低 centroid 后续方向明显不同；D onset 增加花事件、无 onset 不加；E expressive 比 steady 弯曲更多；F 相同帧序列 + 相同 seed 最终结构一致；步骤 / 分支 / 花数量有上限；新 session 干净重置。
- Command: Stage 1 / Stage 2 / Stage 3 / Stage 4 regression
- Result: 全部 PASS
- Command: 真实 App Playground / microphone runtime
- Result: NOT RUN（Command Line Tools 环境）

### 未完成 / 风险
- 真实麦克风 → 实时生长耦合 NOT RUN（需 Xcode + 设备）。
- 生长 cadence（150ms）与 smoothing 参数需真机手感验证。
- 持久化、录音回放、动画 polish 均未实现（Stage 6+）。

### Commit
- `e466444 feat(plant): couple live audio metrics to growth`

## 2026-08-31 13:12 — Runtime Gate — Stage 0–5

**Status:** DONE（iOS 模拟器实测；真实设备仍 NOT RUN）

### 环境
- active developer directory 原本指向 Command Line Tools；完整 Xcode 26.6（/Applications/Xcode.app）已安装，但 `sudo xcode-select` 需要密码不可用，改用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 会话级覆盖，未修改系统其他配置。
- 测试环境：iOS Simulator — iPhone 17 Pro / iOS 26.5；模拟器麦克风使用宿主 Mac 麦克风。

### Runtime Gate 发现的真实 bug 与修复
1. tap 闭包继承 @MainActor 隔离导致崩溃：AVAudioEngine 在 `RealtimeMessenger.mServiceQueue` 调用我们的 tap 闭包时，Swift 运行时做主执行器检查，触发 libdispatch `BUG IN CLIENT OF LIBDISPATCH: Assertion failed: Block was expected to execute on queue [com.apple.main-thread]`（lldb 断点定位到 `closure #1 in AudioEngineController.startListening`）。修复：tap 安装移到 `nonisolated static` 函数（`installInputTap`），闭包不再继承 MainActor 隔离。
2. Result DNA 竞态：停止引擎后，耦合任务最后一 tick 把已清空的 session profile 写回 `growth.plant`，而 ResultView 优先取 `growth.plant` → 屏幕显示全 0。修复：ResultView 优先取冻结的 `flow.currentPlant`；autopilot 顺序与真实 UI 路径一致（先 `finishGrowing` 冻结，再 `stopListening`）。
3. Forest 页残留 “mock 植物” 文案 → 改为 “棵植物”。

### 实测结果（截图 / 日志证据）
| 项目 | 结果 |
|---|---|
| App Playground 打开 / build | PASS（Xcode 26.6 进程运行并打开包；CLI 侧 `xcodebuild -scheme EchoForest` 识别并 BUILD SUCCEEDED） |
| App launch / Forest 首屏 | PASS（截图 OCR：声音森林 / 每一种声音，都可以生长。/ 种下一段声音） |
| 首次“开始创作”系统麦克风权限弹窗 | PASS（截图 OCR 显示系统弹窗 + NSMicrophoneUsageDescription 文案） |
| 权限允许路径 | PASS（simctl privacy grant → engine 启动 → Growing；buffer 计数 9→122，frameLength 4410） |
| 权限拒绝路径 | PASS（simctl privacy revoke → “需要麦克风权限”弹窗，可返回森林/留在 Seed，不崩溃、无假 Listening） |
| 真实 AVAudioPCMBuffer callback | PASS（收到 buffer 持续增长，frameLength=4410） |
| 真实 AudioAnalyzer metrics | PASS（Energy / Spectral Centroid / Variation 实时变化） |
| 静音门控 | PASS（Stage 5 Scenario A 确定性验证；模拟器房间存在环境底噪 energy≈0.1–0.2，未取得真正静音样本） |
| 声音驱动生长 | PASS（steps 0→3；播放测试音频后能量 0.13–0.43） |
| 频率代理响应 | PASS（220 Hz 播放 → centroid 226 Hz；880 Hz 播放 → 543 Hz；日志范围 332–1292 Hz） |
| 拍手 / onset 事件 | NOT RUN（扬声器→麦克风路径峰值能量≈0.29 < onset 阈值 0.35；逻辑由 Stage 5 Scenario D 覆盖，真机拍手待验证） |
| Result 植物与 Growing 一致 | PASS（冻结 flow.currentPlant，无重新生成） |
| Result Sound DNA 真实 session profile | PASS（截图：Energy 0.17 / Spectral Centroid 522 Hz / Duration 12.1s / Variation 0.04） |
| 第二次会话重置 | PASS（plantID 2070B1B1 → F0C39FC5；buffers/steps/duration 全部重置；engine 重启、tap 重新安装成功） |
| 后台 / 前台 | PASS（无崩溃，回前台后生长从 0 继续到 2；interruption 处理仍为已知风险） |
| 3 分钟流程 | PASS（单会话约 19s，双会话约 34s） |

### 验证命令（实际执行）
- `xcodebuild -scheme EchoForest -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/ef-derived build` → PASS
- `xcrun simctl boot / install / launch / privacy grant|revoke / io screenshot / spawn log show` → 实测（见上表）
- `swift build --package-path EchoForest.swiftpm` → PASS
- Stage 1 / 2 / 3 / 4 / 5 self-test → 全部 PASS
- `open -a Xcode <EchoForest.swiftpm>` → 已执行（进程运行；窗口级验证受系统自动化权限限制）

### 未完成 / 风险
- 真实 iPhone 设备未测试（仅 iOS 模拟器 + 宿主麦克风）。
- 拍手 / onset 真机验证 NOT RUN。
- 音频中断处理（后台长时间、媒体服务重置）未实现。
- autopilot 测试钩子（环境变量 `ECHO_FOREST_AUTOPILOT=1` 激活）保留在 App 内；未设置时无任何行为。

### Commit
- `fc60fdf fix(audio): isolate tap callback from main actor`
- `9b589dd fix(plant): freeze result plant and add runtime autopilot hook`

## 2026-08-31 13:44 — Stage 6 Forest Persistence

**Status:** DONE（PASS，含模拟器 kill/relaunch 实测）

### 完成
- `Sources/Persistence/ForestModel.swift`：森林数据模型（plants 集合、按 UUID 去重 add、adding 快照、空森林）。
- `Sources/Persistence/ForestStore.swift`：Codable + JSON 本地持久化（load / save / 文件缺失→空森林 / 损坏→安全失败 / version 信封）。
- Codable：PlantModel / PlantStructure / BranchModel / PlantEvent / GenerationMetadata / PlantEventType / SoundProfile（只存公开 summary 字段）；CGPoint 使用 SDK 自带 Codable（编译期确认，无需自定义）。
- 保存时机：只在“种进森林”点击时保存（先保存成功→采用森林快照→返回 Forest）；不在 Growing / 150ms / callback 保存。
- 保存失败：弹“保存失败 / 本次未能保存到设备”，停留在 Result，不假装已保存（策略 B）。
- 启动加载：RootView init 读取 ForestStore；首次启动 / 文件缺失→空森林，不弹错误。
- 损坏数据：invalid JSON / truncated / incompatible version 均安全失败，不 crash。
- 防重复：ForestModel.add 按 UUID 去重 + isSaving 防双击。
- Forest 渲染继续复用 PlantRenderer。

### 验证
- Command: `swift build --package-path EchoForest.swiftpm`
- Result: PASS（无警告）
- Command: `swiftc ... SelfTests/Stage6ForestSelfTest.swift && 执行`
- Result: PASS（Stage 6 persistence self-test PASS）
- Notes: 覆盖 save/load round trip（id / profile / 结构 / 几何 / 事件一致）、多棵 + 顺序、空森林、invalid JSON / truncated / incompatible version、重复 UUID 去重、极端几何 encode/decode 后有限且一致、NaN profile 不允许进入 JSON。
- Command: Stage 1–5 regression
- Result: 全部 PASS
- Command: `xcodebuild -scheme EchoForest -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Result: PASS
- Command: 模拟器 kill/relaunch 实测（iPhone 17 Pro / iOS 26.5）
- Result: PASS
  - clean install → 首屏空森林“这里还没有植物”
  - 创建 Plant A → 种进森林（log: saved forest with 1 plants）→ `simctl terminate` → relaunch → 森林显示“已种下1棵植物 / 模拟植物1”
  - 创建 Plant B → 种进森林（log: saved forest with 2 plants）→ `simctl terminate` → relaunch → 森林显示“已种下2棵植物 / 模拟植物1 / 模拟植物 2”
  - 容器内 forest.json：version 1、plants=2、ID 唯一

### 未完成 / 风险
- 未实现 schema migration（有 version 信封，未来格式变化走安全失败）。
- 保存失败时植物停留在 Result 可重试；无复杂恢复系统（符合 Stage 6 最小边界）。
- 真机（iPhone）仍未验证；Stage 7+ 未开始。

### Commit
- `pending feat(persistence): save and restore forest locally`
- `pending docs(handoff): record stage 6 completion`
