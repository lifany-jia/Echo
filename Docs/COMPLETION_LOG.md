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
| 4 | Growth Engine | DONE | build PASS + generator 自测 PASS + Stage 6.5 tree grammar |
| 5 | Real-time Coupling | DONE | 模拟器实测 PASS（声音驱动生长、频率响应、Result 真实 DNA）；真机耦合 NOT RUN |
| 6 | Forest Persistence | DONE | build PASS + 持久化自测 PASS + kill/relaunch 实测 PASS |
| 6.5 | Sound Tree Redesign & Audio Memory | DONE | Stage 6.5 自测 PASS + 模拟器录音/保存/重启/详情播放 PASS |
| 6.5+ | Wild Mode + Tree Grammar 2.0 渲染 + PlantRecord v2 | DONE | Stage 6.5 wild 自测 PASS + 模拟器 Normal/Wild runtime PASS |
| 7 | Presentation Polish | PAUSED / NOT STARTED | 按用户要求暂停，未继续 |
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
- `4463b39 feat(persistence): save and restore forest locally`

## 2026-08-31 17:10 — Stage 6.5 Sound Tree Redesign & Audio Memory

**Status:** DONE（Stage 7 / Presentation Polish 暂停，未继续）

### 完成
- Tree Grammar 重做为自然树拓扑：1 trunk + primary branches + secondary branches + terminal twigs；硬上限为 primary 7、secondary 20、terminal twigs 45、总分枝 72。
- 声音规则真实进入生长核心：
  - silence：不推进结构。
  - soft / medium / loud energy：控制增长速度与新枝粗细。
  - recent energy slope：下降向左，升高向右。
  - spectral centroid：低频更横向，高频更向上。
  - variation：低变化更直，高变化更弯、更容易形成丰富分支。
  - onset：只在 terminal twigs 上生成 blossom；连续 onset 形成小花簇。
  - duration：控制主干成熟度、总体 scale 和静态生成预算（30s cap）。
- Renderer 保持程序化 PlantModel / PlantRenderer：枝条骨架仍可见，主干粗、子枝逐级变细，花朵为 5 瓣程序化 blossom，未使用参考图贴图。
- Audio Memory：
  - 新增 `AudioMemoryController`，用 `AVAudioRecorder` 写 AAC/M4A，不在 audio callback 写文件。
  - 单次录制最大 30s。
  - 音频文件路径：`Application Support/EchoForest/Audio/<plantUUID>.m4a`。
  - 保存失败 / audio 缺失安全处理；JSON 成功但音频不存在时详情不崩溃。
- PlantRecord persistence：
  - `ForestModel` 改为保存 `[PlantRecord]`，保留 `plants` 计算属性兼容旧调用。
  - `forest.json` version 升至 2，只存 metadata + 相对 `audioFilename`，不 base64 音频。
  - 支持 v1 `plants` archive 温和迁移为无音频 PlantRecord。
- Plant Detail：
  - Forest 中可点植物进入详情。
  - 展示最终植物、Sound DNA、创建时间、Play/Pause。
  - 播放使用 `AVAudioPlayer`；播放时植物轻微 breathing/highlight，不重新运行 Growth Engine。
- 测试：
  - 新增 `SelfTests/Stage65SoundTreeAudioSelfTest.swift` 覆盖 slope left/right、centroid vertical、variation curvature、onset blossom/cluster、silence no-growth、same frames+seed determinism、branch hierarchy/hard limits、flower valid twigs、audio file fixture、PlantRecord save/load、relaunch persistence、playback prepare、second plant different audio file、clean install empty forest。
  - 更新 Stage 4 onset 断言：onset 语义改为 blossom events，不再要求增加 leaf events。
  - 更新 Stage 5 growth cap 断言为新硬上限。

### 验证
- `swift build --package-path EchoForest.swiftpm` → PASS
- Stage 1 flow self-test → PASS
- Stage 2 audio state self-test → PASS
- Stage 3 metrics self-test → PASS
- Stage 4 plant generator self-test → PASS
- Stage 5 coupling self-test → PASS
- Stage 6 persistence self-test → PASS
- Stage 6.5 sound tree + audio memory self-test → PASS
- `xcodebuild -scheme EchoForest -destination 'platform=iOS Simulator,name=iPhone 17' build` → PASS

### Simulator Runtime（iPhone 17 / iOS 26.5）
- Clean install + microphone grant + autopilot Growing 路径：PASS。
- 创建植物 / 实际录制声音 / 结束 / 种进森林：PASS。
- 容器 `forest.json`：version 2，PlantRecord 记录存在。
- 本次验证产生 3 条有效记录（前两条为预期两轮，第三条来自最早一次未及时终止的长录制，验证 30s cap）；每条记录均指向自己的 UUID M4A：
  - `97370AD1...m4a`：metadata 12.07s，`afinfo` duration 12.072925s，AAC。
  - `F64B1ADB...m4a`：metadata 8.27s，`afinfo` duration 8.264853s，AAC。
  - `224F9ADB...m4a`：metadata 30.00s，30s cap。
- terminate/relaunch 后 detail playback hook：PASS（打开 Plant Detail，`playbackActive=true`，播放第一株记录自己的 M4A）。
- 两株植物关联不同 audio file：PASS。

### 未完成 / 风险
- 详情播放的“点击”路径通过同一 UI handler 与 runtime hook 验证；本次未用物理鼠标坐标手动点击。
- 模拟器录音为宿主麦克风/环境声；“播放声音与本次创作一致”按文件时长、UUID 关联、AAC 可播放验证，未做人耳听感人工判定。
- 音频中断（电话/媒体服务 reset）仍未实现。
- 目录中可能存在未引用的坏/旧 M4A；PlantRecord 不会指向它，详情页也不会崩溃。后续可加 orphan cleanup，但本阶段不实现删除/清理。
- Stage 7 仍为 NOT STARTED/PAUSED。

### Commit
- 已随下一阶段一并提交：`03c672b feat(plant): add wild mode and sound memory`（含 tree grammar + audio memory + wild mode）

## 2026-08-31 18:30 — Stage 6.5+ Wild Mode + Tree Grammar 2.0 渲染 + PlantRecord v2

**Status:** DONE（模拟器 runtime 实测 PASS；真机 / 真实拍手仍 NOT RUN）

### 完成
- `GrowthMode`（normal / wild）：Normal 保持原有诗意创作；Wild 是“驯服失控的声音树”的惊喜模式，两种模式共享同一套 PlantModel / PlantRenderer / persistence。
- `WildSession` 纯核心：确定性时间线约 28 秒（开场 2s → 3-2-1 倒计时 3s → 5 个挑战各 3.5s → 中间一次暴走 4s → 冷静 1.5s）。
  - 5 种 `WildChallenge`：growLeft（往左！让声音慢慢变小）/ growRight（往右！让声音越来越响）/ growUp（冲上去！更明亮/更高）/ branch（分叉！让声音变化起来）/ bloom（开花！拍手或敲桌）。
  - 识别只用现有 AudioAnalyzer 指标：Energy slope（持续 ≥6 tick ≈0.9s）、Spectral Centroid（≥0.48 ≈0.6s）、Variation（recent variability ≥0.32 ≈1.2s）、真实 Onset。
  - 无 Wrong / Failed / ❌ / 分数：挑战未达成不显示失败，树仍按真实声音继续生长；`challenge failure 不 crash` 有确定性测试。
  - 暴走窗口：growth sensitivity ×1.35、新枝长度 ×1.12、开花尺寸 ×1.25；不触碰 AudioAnalyzer 阈值，hard limits 由 PlantGenerator 保证（runtime 实测分支 ≤58 ≤ 72、花 ≤41 ≤ 64）。
- 用户主动声音手势：变小→左、变大→右（recent energy slope，8 帧窗口 ≈1.2s，±0.012 阈值 + EMA smoothing）；低 centroid→横向、高 centroid→向上；变化多→更弯更分叉（新增 recentVariation，最近能量窗口标准差）；拍手→末梢开花，连续 onset→花簇；静音不生长。
- Tree Grammar 2.0 渲染：PlantRenderer 改为“从粗到细”的二次曲线填充枝条（trunk 端粗 1.0→0.18，分支 1.0→0.42），主干底部粗向上收细、一级/二级/末梢层级分明、花只长在末梢与树冠外围；仍是纯程序化 Canvas，无固定 PNG。
- Forest 双入口：主入口“种下一段声音”，次入口“⚡ 让它暴走”（surprise mode，不做复杂 mode selection）；Wild 植物在森林格与详情页带 ⚡ 标记。
- Result / Detail 展示模式（Normal / Wild），Wild 增加“你驯服了一棵失控的声音树。”。
- PlantRecord 新增 `growthMode`；旧 v1 plants 存档迁移为 normal/无音频；旧 v2（无 growthMode 键）decode 默认 normal，不 crash。
- Wild Burst 后“呼……它冷静下来了。”只出现一次；结束后自动进入 Result。
- 测试：新增 `Stage65WildModeSelfTest`；扩展 `Stage65SoundTreeAudioSelfTest`（trunk taper、parent>child thickness、branch hierarchy、terminal twig 识别、blossom 不落 trunk 中间、geometry finite、migration、missing audio safe、growthMode round-trip）。
- Runtime：新增 `ECHO_FOREST_AUTOPILOT_WILD=1`（真实 App 路径 + 确定性脚本帧，与 self-test 同源）与 detail autopilot 多记录播放验证。

### 验证
- Command: `xcrun swift build --package-path EchoForest.swiftpm`（DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer）
- Result: PASS（无警告）
- Command: Stage 1 / 2 / 3 / 4 / 5 / 6 / 6.5 sound tree+audio / 6.5 wild self-tests
- Result: 全部 PASS（8 个零依赖自测）
- Command: `xcodebuild -scheme EchoForest -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build`
- Result: PASS（BUILD SUCCEEDED）
- Simulator runtime（iPhone 17 Pro / iOS 26.5）：
  - Normal 完整闭环：真实麦克风 2 次录音（12.2s / 7.9s）→ Growing（steps 0→6/5）→ Result → 种进森林 → terminate → relaunch → Plant Detail → 两棵各自播放自己的 M4A：PASS（`AUTOPILOT_DETAIL record 1/2 ... playbackActive=true`，文件各不相同，无串音频）。
  - Wild 实际进入：Seed（“它正在暴走……/开始驯服”）→ 倒计时 → growLeft/growRight/growUp/branch/bloom 全部 `succeeded=true`（OCR：往左/往右/冲上去/分叉/开花 + “好，它……”成功文案）→ 暴走（OCR：`暴走！ 别让它失控！`，steps 在暴走窗口加速 23→37）→ 冷静（“呼……它冷静下来了。”）→ Result → 种进森林 → forest.json `growthMode=wild` + 自己的 M4A → relaunch → Detail 播放 wild 录音 PASS。
  - REAL CLAP：NOT RUN（扬声器→模拟器麦克风路径峰值 energy≈0.31 < onset 阈值 0.35；确定性 onset / bloom 测试 PASS，真实拍手待真机）。
- 截图 OCR（Vision）：Wild Seed / 挑战 / 暴走 / 冷静 / Result / Forest 文案均正确渲染。

### 未完成 / 风险
- 真机（iPhone）未验证；REAL CLAP NOT RUN。
- Wild 挑战输入在模拟器用确定性脚本帧驱动（真实 App 路径）；真实麦克风下的 challenge 识别手感需真机确认。
- 音频中断（电话 / 媒体服务 reset）仍未实现。
- 容器中仍可能有孤儿 M4A（不做删除/清理，详情页不引用即不崩溃）。
- 仓库根出现未跟踪的 `Design/`（并行工作产物），未纳入本次提交；除它外 git status 保持 clean。

### Commit
- `03c672b feat(plant): add wild mode and sound memory`

---

## 并行交付：Design 主页 UI 设计稿与树的表达（2026-08-31）

**Status:** DONE（视觉资源与设计板已生成并质检；未改动 App 代码）

### 完成
- `Design/figma-design-draft.html`：Figma 风格主页 UI 设计稿（浏览器直接打开），含 4 个主页状态画板（空森林 / 已有森林 / 新植物高亮 / 暴走模式）、概念主视觉、树的表达画廊、设计令牌（色彩 / 字体 / 圆角 / 间距 / 动效 / SwiftUI 映射）。
- `Design/assets/trees/`：7 幅树的表达（SVG + 1200×1500 PNG）：概念声音树、低音厚土根、高音向光枝、节奏拍手花、长音绵长冠、旋律蜿蜒脉、暴走电光树。
- `Design/assets/plants/`：6 棵主页森林小植物（SVG + 240×300 PNG）：低语杉 / 风铃藤 / 琥珀花 / 夜莺柳 / 云冠榆 / 电光棘。
- `Design/scripts/generate_trees.py`：纯标准库程序化生成器，确定性随机种子，可重复生成全部 SVG。
- `Design/README.md`：设计方向、文件结构、Figma 导入方式、声音→树映射表。

### 验证
- Command: `python3 Design/scripts/generate_trees.py` → 13 个 SVG 全部生成，`xmllint --noout` 校验通过。
- Command: Chrome headless 渲染 → 7 幅树 PNG + 6 棵植物 PNG + 设计板整板预览（1680×6500）成功，尺寸符合设计（1200×1500 / 240×300）。
- 像素抽样校验：7 幅树非空白，色调符合各自设计意图（低音最暗绿、暴走偏琥珀暖色）。
- 设计板探针质检：HTML 标签配对无错；23 处图片引用全部加载成功（broken=0）；画板/标注坐标符合预期；无横向溢出。

### 未完成 / 风险
- AI 位图插画（如梦幻森林油画）未生成：当前会话无内置 image_gen 工具且未配置 `OPENAI_API_KEY`；如需可通过 CLI 备选路径生成（见 imagegen 技能）。
- 设计稿为高保真规格板而非 `.fig` 原生文件；SVG/PNG 可拖入 Figma 直接使用。
- 未改动 `ForestView.swift` 等实现代码；设计令牌区提供 SwiftUI 映射，供 Stage 7 恢复时对照。

### Commit
- `docs(design): add homepage UI design draft and procedural tree artwork`（仅含 `Design/`，未混入其他未提交改动）

---

## Stage 7 主页视觉落地（2026-08-31，用户明确要求把设计稿写进项目）

**Status:** DONE（Forest 主页按 `Design/figma-design-draft.html` Frame A/B/C 重做；模拟器截图验证 PASS）

### 完成
- `Sources/Views/ForestView.swift` 重写，对外接口不变（plantedRecords / highlightedPlantID / onStart / onStartWild / onSelectRecord），不触碰 Seed / Growing / Result / Detail 流程。
- 深夜森林背景：墨夜绿 `#0B1512` → 林间 `#1C3A2C` → 琥珀地平线 `#3A3120` 渐变 + 右上月光 + 3 条模糊雾带 + 5 颗萤火点（轻量 pulse，尊重 `accessibilityReduceMotion`）。
- 空森林：150pt 种子 + 三圈声音波纹（easeOut 3.2s 循环、错峰 1.07s）+ 主题句「每一种声音，都可以生长。」29pt bold + 副文案。
- 已有森林：28pt 圆角深色「林中空地」面板 + 「森林里有 N 棵植物」琥珀计数胶囊 + LazyVGrid(adaptive min 100) 植物网格；植物块 18pt 圆角、玻璃底、月白名字、暴走 ⚡ 标记。
- 新植物高亮：琥珀边框/光环 + 面板顶部悬浮铭牌「新种下 · 名称」+ Sound DNA 一行（Energy / 频率 Hz / 时长 s），1.8s 后随既有逻辑淡出。
- 底部操作区：56pt 琥珀渐变胶囊主按钮「种下一段声音」（深色文字 #211500、柔光阴影）+ 描边次按钮「⚡ 让它暴走」+ 小字「拍手会开花 · 高音会长高」。
- `Design/PROMPTS.md`：可复用提示词库（设计稿 / 7 幅树的图像 / SwiftUI 实现 / 整包复刻）。
- `Design/runtime-forest-*.png`：模拟器实拍截图（空森林 / 已有森林+高亮），压缩后约 180KB 各。

### 验证
- Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path EchoForest.swiftpm`
- Result: PASS（Build complete，2.5s）
- Command: 8 个零依赖自测（swiftc 编译 Sources + SelfTests 逐个执行）
- Result: 全部 PASS（Stage1/2/3/4/5/6/6.5 sound tree/6.5 wild）
- Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme EchoForest -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Result: PASS（BUILD SUCCEEDED）
- Command: 模拟器安装 + `ECHO_FOREST_AUTOPILOT=1`（1 会话）真实流程
- Result: `[AUTOPILOT] session 1 planted; total=1`；截图像素校验：空森林深绿渐变 + 琥珀 CTA（CTA 区琥珀像素 39.7%）+ 月白标题；种植后中区出现琥珀高亮（754 像素），8s 后淡出（187 像素）。

### 未完成 / 风险
- 只落地了主页（Frame A/B/C）；Frame D 暴走模式变体为概念稿，主页保持普通流程 + ⚡ 次入口，未做暴走专属主页态。
- 其余 Stage 7 精修（Growing / Result / Detail 视觉）仍未开始，需用户明确恢复。
- 真机视觉效果与人耳听感仍未验证（模拟器 PASS）。

### Commit
- `feat(ui): apply dusk-forest homepage redesign from design draft`

---

## Stage 6.5 Creative Refactor（2026-08-31，Echo / Wild 双模式 + Sound Gesture + Free For All）

**Status:** DONE（确定性自测 9/9 PASS + 模拟器 Echo/Wild/持久化 runtime PASS；真实拍手 NOT RUN）

### 完成
- `GrowthMode` 从 `normal/wild` 改为正式双模式 `echo/wild`；旧存档 raw `"normal"` 解码自动迁移为 `.echo`，不 crash。
- 新增 `SoundGestureAnalyzer`（纯逻辑）：能量趋势（持续判定，单帧抖动不横跳）、停顿/silence 手势、attack 突发、onset isolated/cluster、节奏 regular/irregular（inter-onset interval，不做 BPM）、变化度分级。
- Echo：自由创作；Growing 页加入一次性声音手势提示（渐弱→左、渐强→右、明亮→上、变化→分叉、停顿→换枝、恢复→新一笔、敲击→开花）；Forest 入口改为「种一棵声音树 / ⚡ 暴走森林」并带副文案。
- 停顿 = 结束这一笔：`GrowthSession` 静音 >= 1s 记为停顿，恢复后下一次生长强制开启新主枝（`justResumedFromPause` 以约 0.9s 闪光窗口暴露给 UI）。
- Wild 重写：开场（别吵醒它）→ 3-2-1 倒计时 → 种子抽动（糟了）→ 4–6 个挑战（seed 确定性洗牌；silence/louder/softer/high/chaos/bloom/rhythm）→ Free For All（随便来点什么！！8s，全映射开放，灵敏度 ×1.35，硬上限仍由 PlantGenerator 保证）→ 结尾（嗯……确实很像你）→ Result。总时长约 36.5s（30–45 区间内）。
- Wild 挑战语义：silence 出声只触发“它听见了。”（不失败不 Wrong）；bloom 第一朵“就这？”，第二次 onset 成花簇；rhythm 按 inter-onset regularity 开花。
- 录音上限 30s → 45s（覆盖 Wild 完整时长）。
- Result / Plant Detail：新增确定性声音画像（Echo：安静/柔和/有力 + 低沉/舒展/明亮 + 多变 + 有节奏；Wild：吵闹/躁动 + 多变 + 爆发力强 + 极度不安分）；Detail 播放按钮改为「听听它的声音 / 暂停」；SoundDNA 频率行改为「频率特性」，不虚构 Pitch。
- Seed：首次创作前展示本地录音隐私说明（不上传、不联网、可关闭）。

### 验证
- `swift build --package-path EchoForest.swiftpm`：PASS（无警告）。
- 9 个零依赖自测全部 PASS（新增 `Stage65SoundGestureSelfTest`；`Stage65WildModeSelfTest` 覆盖新时间线/7 类挑战/Free For All 硬上限/迁移）。
- `xcodebuild -scheme EchoForest -destination 'platform=iOS Simulator,name=iPhone 17' build`：PASS。
- 模拟器 Echo runtime（真实麦克风 + 宿主扬声器音调输入）：real buffers（0→123）/ frame 4410 / real metrics（energy 0.253、centroid 波动、onset 5）/ real growth（steps>0）/ Result / Save / relaunch / Detail / playback PASS。
- 模拟器 Wild runtime（真实 App 路径 + 确定性脚本帧，与 self-test 同源）：opening → countdown → jerk → silence/louder/softer/high/chaos/bloom 全部 succeeded=true → Free For All（branches 38→65、flowers 6→21）→ ending → done → 种进森林 PASS。
- 持久化 A/B：Echo Plant A（EFED4119…m4a，12.2s）+ Wild Plant B（A10FE468…m4a，39.4s），terminate/relaunch 后分别 playbackActive=true，A→Audio A、B→Audio B 无串音 PASS。
- 权限拒绝：revoke 麦克风后 autopilot `creation started: false`，无崩溃 PASS；随后恢复授权。
- 像素抽样：Wild 森林截图含 2 棵植物（greenish 342k / amber 28k）；权限拒绝截图正常。

### 未完成 / 风险
- `PHYSICAL CLAP: NOT RUN`（模拟器扬声器→麦克风路径无法稳定触发真实拍手；确定性 onset/bloom/rhythm 测试 PASS）。
- 真机（iPhone）整体体验未验证；Wild 真实麦克风下的挑战手感（非脚本帧）需真机确认。
- Wild 挑战失败没有失败态（符合设计）；Free For All 结束后直接进入 Result，无“再来一次”快捷入口。
- 音频中断（电话 / 媒体服务 reset）仍未实现。

### Commit
- `feat(plant): add creative refactor with sound gestures and wild free-for-all`

---

## 真机修复（2026-08-31，iPhone 17 / iOS 26.6.1 实测）

**Status:** DONE（真机安装运行；修复点经代码与自测验证，视觉由用户真机确认）

### 修复
- 真机“点开始创作闪退”：`AudioEngineController` 之前把输入 tap 强制装成 44.1kHz，真机硬件采样率通常为 48kHz，`engine.start()` 触发 AVAEInternal 断言崩溃。改为使用输入节点硬件原生格式，`AudioAnalyzer` 按每帧 buffer 真实 sampleRate 计算时长与频域重心（模拟器硬件格式恰好匹配所以此前未暴露）。
- 树“不是从底部生长”：`PlantRenderer` 之前按包围盒居中缩放，树干基部悬空。改为以树干基部为锚点贴底居中、向上生长，并让主干随 `revealSteps` 从约 35% 小苗逐步拔高到完整。
- 树与设计稿不一致：渲染配色从棕色“算法线条树”改为深夜森林深绿（主干 #263F30 / 枝条 #335440）+ 鼠尾叶 + 琥珀花，并加基部地面柔光，对齐 `Design/assets/trees` 参考。

### 验证
- `swift build` PASS；9 个零依赖自测 PASS。
- 真机（iPhone 17 / iOS 26.6.1）：构建 → 安装（com.echoforest.playground，Xcode 托管描述文件 + Apple Development 证书）→ 启动 → 进程持续存活，未再闪退。
- 模拟器：Wild 脚本帧长出满叶大树（branches/flowers 正常），Result/森林渲染正常。
- 说明：当前环境不支持人工目检图片，最终视觉效果以真机确认为准。

### Commit
- `fix(audio): use hardware input format to prevent real-device crash`
- `fix(rendering): anchor plant base at bottom and align palette with design`

---

## App 图标（2026-08-31）

**Status:** DONE（像素级几何校验通过；未人工目检，视觉以用户确认为准）

### 完成
- 基于主页概念主视觉 `Design/assets/trees/tree-hero.svg` 生成 App 图标：
  `Design/AppIcon/app-icon.svg`（源）+ `app-icon-1024.png`（主图）+
  `app-icon-512.png` / `app-icon-256.png`。
- 构图：源图 1200×1500 裁出正方形（y∈[240,1440]），缩放到 1024²；
  墨夜绿渐变、右上月光、雾带、树根声音波纹、琥珀花与萤火全部保留，无文字。
- 新增可复现生成器 `Design/scripts/generate_appicon.py`
  （读取 tree-hero.svg → 包装为 1024² 画布 → qlmanage 渲染 PNG → sips 出多尺寸）。
- `Design/README.md` 增加 AppIcon 用法（Swift Playgrounds App Settings 设置路径）。

### 验证
- 三个尺寸 PNG 像素尺寸校验 PASS（1024² / 512² / 256²）。
- 几何保真：1024 渲染图与 tree-hero.png 同区域裁切缩放后逐点比对，
  mean abs diff = 1.44 / 255（p95 = 3.0），几乎像素级一致。
- 无内置 image_gen 工具（本会话），未走 CLI 图像模型路径；图标由既有程序化
  资产直接生成，与设计体系完全一致。

### 未完成 / 风险
- 未人工目检（本环境无图像输入），最终视觉效果以真机 / 用户确认为准。
- Swift Playgrounds App Icon 由 App Settings 配置，代码内无 icon 字段可改。

### Commit
- `feat(design): add echo forest app icon`
