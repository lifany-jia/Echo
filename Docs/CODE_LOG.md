# CODE_LOG.md — 代码与架构日志

> 用于记录代码结构、关键技术决策、重要变更和已知风险。目标是让新对话无需翻 Git 历史即可理解当前实现。

## 1. 当前架构状态

**代码状态：Stage 6 DONE（Forest Persistence；模拟器 kill/relaunch 实测 PASS）**

当前结构：

- `EchoForest.swiftpm/Package.swift`：SwiftPM 包配置，生成 `EchoForest` executable；无测试 target（本工具链无 Swift Testing / XCTest，改用零依赖自测）。
- `EchoForest.swiftpm/Sources/App/AppStage.swift`：`forest / seed / growing / result` 四状态，是唯一页面切换来源。
- `EchoForest.swiftpm/Sources/App/EchoForestFlow.swift`：内存流程状态机，持有 `stage / plantedPlants / currentPlant`，负责进入 Seed、开始/结束创作、种入森林、二次创作重置。
- `EchoForest.swiftpm/Sources/Audio/AudioInputState.swift`：纯状态模型（权限四态 + 会话阶段 + 轻量计数），独立于 AVFoundation，供零依赖自测。
- `EchoForest.swiftpm/Sources/Audio/AudioEngineController.swift`：AVAudioEngine 输入链路控制器（@MainActor @Observable）。UI 只观察其状态，不直接操作 engine。
- `EchoForest.swiftpm/Sources/Audio/SoundMetrics.swift`：SoundFrame（即时）+ SoundProfile（会话累计）指标模型。
- `EchoForest.swiftpm/Sources/Audio/SoundMath.swift`：纯 DSP 数学层（RMS / normalized energy / clamp），无 AVFoundation 依赖。
- `EchoForest.swiftpm/Sources/Audio/SpectralCentroid.swift`：Accelerate vDSP_DFT 频域重心（Frequency Proxy）。
- `EchoForest.swiftpm/Sources/Audio/OnsetDetector.swift`：能量域 transient 检测（threshold + jump + cooldown）。
- `EchoForest.swiftpm/Sources/Audio/AudioAnalyzer.swift`：分析层，AVAudioPCMBuffer → SoundFrame + SoundProfile。
- `EchoForest.swiftpm/Sources/Persistence/ForestModel.swift`：森林数据模型（去重 add / 快照 / Codable）。
- `EchoForest.swiftpm/Sources/Persistence/ForestStore.swift`：Codable + JSON 本地持久化（load / save / 损坏安全失败 / version 信封）。
- `EchoForest.swiftpm/Sources/Plant/BranchModel.swift`：枝条 / 事件节点 / PlantStructure / 元数据 / boundingBox / visibleCounts。
- `EchoForest.swiftpm/Sources/Plant/PlantModel.swift`：会话身份 + SoundProfile + PlantStructure。
- `EchoForest.swiftpm/Sources/Plant/GrowthState.swift`：生长步骤（模拟 progression）。
- `EchoForest.swiftpm/Sources/Plant/SeededRandom.swift`：SplitMix64 确定性 RNG。
- `EchoForest.swiftpm/Sources/Plant/PlantGenerator.swift`：SoundProfile + seed → PlantStructure 的五维确定性映射。
- `EchoForest.swiftpm/Sources/Plant/PlantGenerator.swift`（Stage 5）：新增 initialStructure / appendGrowthStep / appendFlower / normalizedCentroid01，支持增量生长。
- `EchoForest.swiftpm/Sources/Plant/GrowthSession.swift`：实时耦合纯核心（SoundFrame 序列 → 逐步生长 PlantModel）。
- `EchoForest.swiftpm/Sources/App/LiveGrowthController.swift`：@MainActor 协调层，150ms cadence 驱动 GrowthSession。
- `EchoForest.swiftpm/Sources/Rendering/PlantRenderer.swift`：PlantStructure → Canvas；不重算声音映射。
- `EchoForest.swiftpm/Sources/App/EchoForestRootView.swift`：持有 flow + audio；Seed “开始创作”异步执行权限 → startListening → 成功才进入 Growing；拒绝/失败弹 alert。
- `EchoForest.swiftpm/Sources/Views/SeedView.swift`：种子页；按钮“开始创作”，提示首次请求权限。
- `EchoForest.swiftpm/Sources/Views/GrowingView.swift`：Listening 徽标 + buffer 链路计数 + Live Metrics 面板（Energy / Spectral Centroid / Onset count / Duration）+ 取消按钮；植物视觉仍为 mock。
- `EchoForest.swiftpm/Sources/Views/ForestView.swift`：森林页，展示已种 PlantModel 缩略图。
- `EchoForest.swiftpm/Sources/Views/GrowingView.swift`：PlantRenderer + 实时 growthStep + Live Metrics 次要面板。
- `EchoForest.swiftpm/Sources/Views/ResultView.swift`：PlantRenderer + 会话 SoundProfile DNA（明确叫 Spectral Centroid）。
- `EchoForest.swiftpm/SelfTests/Stage1FlowSelfTest.swift` / `Stage2AudioSelfTest.swift` / `Stage3MetricsSelfTest.swift` / `Stage4PlantSelfTest.swift` / `Stage5CouplingSelfTest.swift`：零依赖自测。
- `EchoForest.swiftpm/SelfTests/Stage6ForestSelfTest.swift`：持久化确定性自测。
- `EchoForest.swiftpm/Info.plist`：NSMicrophoneUsageDescription（尽力配置；官方路径为 Xcode capability）。

Stage 6 持久化尚未实现；PitchDetector 未实现（以 Spectral Centroid 代理）。旧的 MockPlantModel / MockSoundProfile / MockPlantCanvas 已删除。

---

## 2. 核心数据流

预期：

```text
AVAudioEngine
  -> PCM Buffer
  -> AudioAnalyzer
  -> SoundFrame / SoundProfile
  -> PlantGenerator / GrowthEngine
  -> GrowthState
  -> PlantRenderer
  -> SwiftUI UI
```

原则：

- DSP 不放在 View 内。
- Audio callback 与 UI 刷新解耦。
- 随机数用于细节，不替代声音映射。
- 结果页所展示的 Sound DNA 必须能追溯到真实分析指标。

---

## 3. 关键决策记录模板

```md
### ADR-XXX — <标题>
Date: YYYY-MM-DD
Status: Accepted / Superseded / Rejected

Context:
- 

Decision:
- 

Why:
- 

Consequences:
- 
```

---

## 4. 代码变更日志模板

```md
## YYYY-MM-DD — <commit hash>

Commit: `<type(scope): subject>`

### Files
- `path/to/file.swift`: 新增 / 修改 / 删除；用途

### Behavior change
- 

### Design notes
- 

### Tests
- 

### Known risks
- 
```

---

## 5. 首批建议 ADR

### ADR-001 — 核心植物必须程序化生成
Date: 2026-08-31
Status: Accepted

Context:
- 创意评分依赖“声音改变植物结构”的可信度。

Decision:
- 植物主结构必须由 Branch/Leaf 等模型按声音参数生成，不以预制图片随机切换作为核心。

Why:
- 保证声音到视觉的可解释性。
- 提升技术难度与展示价值。

Consequences:
- 需要控制算法复杂度与实时性能。

### ADR-002 — 首版完全离线
Date: 2026-08-31
Status: Accepted

Decision:
- 不使用任何核心网络服务。

Why:
- 比赛离线评审硬性要求。

### ADR-003 — 非 AR 项目
Date: 2026-08-31
Status: Accepted

Decision:
- 当前项目不集成 ARKit。

Why:
- 用户已要求此创意先按非 AR 方向完整实现；团队级 AR 数量约束由其他作品满足。

## 2026-08-31 — 37269c1

Commit: `build(app): add SwiftPM baseline`

### Files
- `.gitignore`: 新增；排除本地与构建产物。
- `EchoForest.swiftpm/Package.swift`: 新增；定义可编译的 SwiftPM App Playground 基线。
- `EchoForest.swiftpm/Sources/App/EchoForestApp.swift`: 新增；提供 SwiftUI `@main` 入口。
- `EchoForest.swiftpm/Sources/App/AppStage.swift`: 新增；建立 Stage 0 的最小状态枚举。
- `EchoForest.swiftpm/Sources/Views/ForestView.swift`: 新增；提供首屏 Forest 视觉基线。

### Behavior change
- App 启动后显示 Echo Forest 首屏，不包含导航、音频或植物生成行为。

### Design notes
- Stage 0 严格限制在“可编译运行 + 首屏显示”，没有加入 Forest → Seed 导航闭环。
- 暂不引入第三方依赖、网络资源或大体积本地资源。
- SwiftUI `#Preview` 未保留，因为当前 Command Line Tools 构建环境缺少 Preview 宏插件。

### Tests
- `swift build --package-path EchoForest.swiftpm` PASS x2。
- `xcodebuild` NOT RUN：当前 active developer directory 是 Command Line Tools，不是完整 Xcode。

### Known risks
- App Playground 手动打开未在当前环境验证。
- 首屏之后的核心体验仍全部等待后续 Stage。

## 2026-08-31 — fd9248f

Commit: `feat(flow): build static creation loop`

### Files
- `Docs/CODE_LOG.md`、`Docs/COMPLETION_LOG.md`、`Docs/HANDOFF.md`、`Docs/TEST_PLAN.md`：由仓库根目录迁入 `Docs/`。
- `.gitignore`：新增 `EchoForest.swiftpm/.swiftpm/` 忽略。
- `Sources/App/AppStage.swift`：新增 `seed / growing / result` 三个 case。
- `Sources/App/EchoForestApp.swift`：入口改为展示 `EchoForestRootView`。
- `Sources/App/EchoForestFlow.swift`：新增；内存流程状态机。
- `Sources/App/EchoForestRootView.swift`：新增；按 `AppStage` 分发四页。
- `Sources/Models/MockSoundProfile.swift`：新增；mock 四维声音画像。
- `Sources/Models/MockPlantModel.swift`：新增；mock 植物模型。
- `Sources/Rendering/MockPlantCanvas.swift`：新增；Canvas 程序化 mock 植物。
- `Sources/Views/ForestView.swift`：重写；空地块 + 已种植物网格 + 主按钮。
- `Sources/Views/SeedView.swift`、`GrowingView.swift`、`ResultView.swift`：新增。
- `SelfTests/Stage1FlowSelfTest.swift`：新增；零依赖流程断言。

### Behavior change
- 启动后可在 Forest → Seed → Growing → Result → Forest 完成静态闭环。
- 回到 Forest 可看到本次运行中已种下的 mock 植物；再次创作不残留上次 GrowthState。
- 本阶段不请求麦克风权限、不引入任何音频依赖。

### Design notes
- 页面切换只有一个来源：`EchoForestFlow.stage`，符合 AGENTS.md “不要用多个 Bool 控制跳转”。
- 所有声音数值均为固定 mock 常量，UI 文案明确带 “Mock / 静态模拟” 标识，避免暗示真实声音驱动。
- 程序化视觉只依赖 SwiftUI Shape/Canvas/Path，无第三方库。
- 森林状态仅保存在 `EchoForestFlow` 内存中，属于当前运行周期，符合 Stage 1 边界。
- SwiftPM 测试 target 被移除：当前工具链缺少 Swift Testing 与 XCTest 模块，`swift test` 无法运行；采用 `swiftc` 直接编译真实源文件 + 断言的方式替代，待有完整 Xcode 环境后再恢复标准测试目标。

### Tests
- `swift build --package-path EchoForest.swiftpm` PASS。
- `swiftc ... Stage1FlowSelfTest.swift` + 执行 PASS（“Stage 1 flow self-test PASS”）。
- `xcodebuild` NOT RUN：Command Line Tools 环境。

### Known risks
- 静态闭环未在真机/模拟器图形化运行中验证（NOT RUN）。
- Growing 为静态 mock 视觉，真实声音耦合需 Stage 2–5。

## 2026-08-31 — fe6142d

Commit: `feat(audio): add microphone input pipeline`

### Files
- `Sources/Audio/AudioInputState.swift`：新增；纯状态模型（权限 + 阶段 + 轻量计数）。
- `Sources/Audio/AudioEngineController.swift`：新增；AVAudioEngine 输入链路控制器。
- `EchoForest.swiftpm/Info.plist`：新增；NSMicrophoneUsageDescription（尽力配置，官方路径为 Xcode capability）。
- `Sources/App/EchoForestFlow.swift`：`startMockGrowing` → `startGrowing`；新增 `cancelGrowing`；防重复进入 Growing。
- `Sources/App/EchoForestRootView.swift`：持有 AudioEngineController，接入权限 → 启动 → Growing 流程；alert 处理拒绝/失败。
- `Sources/Views/SeedView.swift`：按钮改为“开始创作”，文案“首次开始会请求麦克风权限。”。
- `Sources/Views/GrowingView.swift`：Listening 徽标 + buffer 链路计数 + 取消按钮。
- `SelfTests/Stage2AudioSelfTest.swift`：新增；零依赖状态/生命周期断言。
- `SelfTests/Stage1FlowSelfTest.swift`：适配 `startGrowing` 更名。

### Behavior change
- 首次点击“开始创作”才请求麦克风权限；拒绝或启动失败不进入 Growing，可返回 Forest 或留在 Seed。
- Growing 明确反映“麦克风输入已启动”，并显示收到 buffer 的轻量验证计数。
- 结束 / 取消 / 返回都会停止 engine、移除 tap、清理会话状态；可再次创作且不产生 duplicate tap。

### Design notes
- 权限与 engine 启动分离：权限允许 ≠ engine 一定启动成功，两条路径有独立错误状态；失败后 permission 标记 `.unavailable`，重试成功恢复 `.authorized`。
- 音频 callback 零分配、零 IO、零 DSP，只更新 OSAllocatedUnfairLock 保护的计数；UI 由 500ms 主线程定时任务同步，避免每个 buffer 高频刷新 SwiftUI。
- tap 安装用 `hasTapInstalled` 防护，`removeTap` 仅在已安装时调用，避免 NSException；start / stop 幂等。
- App Playground 无公开 Info.plist 编辑入口：官方方式是 Xcode Signing & Capabilities 添加 Microphone capability；包根 Info.plist 为尽力补充，需在 Xcode 验证。

### Tests
- `swift build --package-path EchoForest.swiftpm` PASS。
- Stage 1 flow self-test PASS（回归）。
- Stage 2 audio state self-test PASS。
- 真实麦克风 callback：NOT RUN（Command Line Tools 环境无法运行 App Playground / 授权麦克风）。

### Known risks
- 真机/模拟器上 engine 启动、buffer 到达、权限弹窗行为未实测。
- Info.plist / capability 生效未验证。
- 音频会话中断（后台、媒体服务重置）处理未实现。

## 2026-08-31 — ae524df

Commit: `feat(audio): add real-time sound metrics`

### Files
- `Sources/Audio/SoundMetrics.swift`：新增；SoundFrame（即时指标）+ SoundProfile（会话累计指标）。
- `Sources/Audio/SoundMath.swift`：新增；RMS / normalized energy / clamp 纯函数层。
- `Sources/Audio/SpectralCentroid.swift`：新增；Accelerate vDSP_DFT 频域重心（Frequency Proxy）。
- `Sources/Audio/OnsetDetector.swift`：新增；能量域 onset 检测。
- `Sources/Audio/AudioAnalyzer.swift`：新增；AVAudioPCMBuffer → SoundFrame + SoundProfile 分析层。
- `Sources/Audio/AudioEngineController.swift`：tap 固定标准 float32 mono 44.1k；callback 内运行 analyzer 并写锁保护 snapshot；暴露 latestFrame / profile 供 UI 低频读取。
- `Sources/Views/GrowingView.swift`：MockGrowthMeter 替换为 Live Metrics 面板；明确标注植物仍为 mock。
- `Sources/App/EchoForestRootView.swift`：向 GrowingView 传入实时指标。
- `SelfTests/Stage3MetricsSelfTest.swift`：新增；确定性 DSP 自测。

### Behavior change
- Growing 页展示真实 Energy / Spectral Centroid / Onset count / Duration；植物视觉与 Result Sound DNA 保持 mock。

### Design notes
- 指标分两层：SoundFrame（instantaneous）与 SoundProfile（accumulated / session），Result 暂不接真实 summary，避免 Stage 4 越界。
- 频率维度选择 Spectral Centroid（频域重心）而非 pitch detector：成本低、稳定、可解释，符合 AGENTS.md 允许的降级路径；代码与 UI 一律叫 Spectral Centroid / 频域重心，不冒充 Pitch。
- RMS 手动遍历（跳过 NaN / infinity，空 buffer 返回 0）；FFT 用 vDSP_DFT（Accelerate），工作缓冲 init 一次性分配、callback 零分配。
- Energy = clamp01(sqrt((rms - noiseFloor) / (1 - noiseFloor)))；noiseFloor 以下为 0。
- Onset 需同时满足 energy threshold、相对上一帧 jump、cooldown，避免稳定音乱触发与单爆音重复触发。
- 线程安全：tap callback 在 OSAllocatedUnfairLock 内做轻量 DSP 并写入 snapshot；主线程 500ms 定时任务把 snapshot 同步到 @Observable 属性，保持 “callback 高频 → snapshot → 低频 UI 刷新”。
- SpectralCentroid / AudioAnalyzer 标为 @unchecked Sendable：只从单一音频线程访问，由调用方锁保护。

### Tests
- `swift build --package-path EchoForest.swiftpm` PASS。
- Stage 3 metrics self-test PASS（Energy / Frequency / Onset / Session profile / 稳定性）。
- Stage 1 / Stage 2 regression PASS。
- 真实麦克风 → analyzer 集成：NOT RUN（Command Line Tools 环境）。

### Known risks
- 真实音频集成未实测；Spectral Centroid 不是真实 pitch。
- 音频会话中断处理未实现。

## 2026-08-31 — e466444

Commit: `feat(plant): couple live audio metrics to growth`

### Files
- `Sources/Plant/GrowthSession.swift`：新增；实时耦合纯核心。
- `Sources/App/LiveGrowthController.swift`：新增；@MainActor @Observable 协调层。
- `Sources/Plant/PlantGenerator.swift`：新增增量 API（initialStructure / appendGrowthStep / appendFlower / normalizedCentroid01 / LiveGrowthParams / seedlingProfile）；normalize + makeTrunk 与 Stage 4 共享。
- `Sources/Plant/PlantModel.swift`：profile / structure 改为 var（实时更新）。
- `Sources/App/EchoForestFlow.swift`：新增 startGrowing(plant:) / finishGrowing(plant:)。
- `Sources/App/EchoForestRootView.swift`：持有 LiveGrowthController；150ms coupling task；Seed 成功后创建新会话；Result 冻结 growth.plant；取消 / 种进森林时 reset。
- `Sources/Audio/AudioEngineController.swift`：metrics snapshot 同步从 500ms 调整为 150ms（耦合 + UI 共用 cadence）。
- `Sources/Views/GrowingView.swift`：移除 320ms 模拟计时器，改用实时 growthStep。
- `Sources/Views/ResultView.swift`：DNA 切换为会话 SoundProfile，明确 Spectral Centroid (Frequency)。
- `SelfTests/Stage5CouplingSelfTest.swift`：新增；录音回放式确定性耦合自测。

### Behavior change
- Growing 由真实（或回放）SoundFrame 序列驱动：静音不增长，有声才长，大声长得更多更粗，onset 开花。
- Result 展示与 Growing 完全相同的最终 PlantModel，Sound DNA 为会话 SoundProfile。

### Design notes
- 链路：callback → DSP → 锁保护 snapshot → 150ms coupling（EMA + activity gate + 能量累积预算）→ GrowthState / PlantModel → PlantRenderer。
- 不每 buffer 重建整棵树：每次 update 最多追加若干新枝（受 maxSteps / maxBranchCount 上限）。
- 平滑用 EMA（alpha 0.35）；静音时 growthAccumulator 缓慢衰减；onset 保持离散事件。
- 同一帧序列 + 同 seed → 最终结构一致（GrowthSession 纯确定性）。
- PlantModel.profile 每 tick 同步会话 profile，保证 Result DNA 是真实 session summary。

### Tests
- `swift build --package-path EchoForest.swiftpm` PASS。
- Stage 5 coupling self-test PASS（Scenario A–F + 上限 + 二次创作重置）。
- Stage 1 / Stage 2 / Stage 3 / Stage 4 regression PASS。
- 真实麦克风耦合：NOT RUN。

### Known risks
- 150ms cadence 与平滑参数的观感需真机验证。
- 真机首次真实音频 → 生长链路未实测（NOT RUN）。

## 2026-08-31 — pending

Commit: `feat(persistence): save and restore forest locally`

### Files
- `Sources/Persistence/ForestModel.swift`：新增；森林模型（plants / 去重 add / adding 快照 / Codable）。
- `Sources/Persistence/ForestStore.swift`：新增；Codable + JSON（load / save / 空文件 / 损坏 / version）。
- `Sources/Plant/PlantModel.swift`：Codable。
- `Sources/Plant/BranchModel.swift`：BranchModel / PlantEvent / PlantStructure / GenerationMetadata / PlantEventType Codable（CGPoint 使用 SDK 自带 Codable）。
- `Sources/Audio/SoundMetrics.swift`：SoundProfile Codable（只编码公开 summary 字段，私有累计字段不持久化）。
- `Sources/App/EchoForestFlow.swift`：forest 模型化（plantedPlants 改为 forest.plants 计算属性；adoptForest 采用已保存快照）。
- `Sources/App/EchoForestRootView.swift`：init 加载森林；plantCurrentInForest() 先保存成功再采用快照，失败弹提示停留 Result；autopilot 支持 ECHO_FOREST_AUTOPILOT_SESSIONS。
- `SelfTests/Stage6ForestSelfTest.swift`：新增；持久化确定性自测。

### Behavior change
- “种进森林”后植物写入本地 JSON；重启 App 森林恢复。
- 保存失败不假装成功（留在 Result 可重试）。

### Design notes
- 最小实现：只持久化 PlantModel 最终结构 + SoundProfile summary + version 信封；不保存 buffer / 音频 / 临时状态。
- CGPoint 在 SDK 中已 Codable，几何以 Double 精确往返。
- JSON 不允许 NaN / Infinity：编码失败即保存失败，保证磁盘数据合法（测试覆盖）。
- 保存失败策略 B：保存成功后才正式加入森林。

### Tests
- Stage 6 persistence self-test PASS（round trip / 多棵 / 空 / 损坏 / 去重 / 极端几何 / NaN 防护）。
- Stage 1–5 regression PASS；`swift build` PASS；xcodebuild simulator build PASS。
- 模拟器 kill/relaunch：Plant A 保存→terminate→relaunch 恢复；Plant B 追加→terminate→relaunch 显示 A+B；clean install 空森林。

### Known risks
- 无 schema migration（version 信封 + 安全失败兜底）。
- 真机未验证。

## 2026-08-31 — fc60fdf + 9b589dd（Runtime Gate 修复）

Commit: `fix(audio): isolate tap callback from main actor` + `fix(plant): freeze result plant and add runtime autopilot hook`

### Files
- `Sources/Audio/AudioEngineController.swift`：tap 安装移到 `nonisolated static func installInputTap`，修复闭包继承 @MainActor 隔离导致的模拟器运行时崩溃。
- `Sources/App/EchoForestRootView.swift`：ResultView 优先取冻结的 `flow.currentPlant`；autopilot 顺序改为先冻结再停引擎；autopilot 扩展为双会话并用 NSLog 输出证据；日志添加 plantID。
- `Sources/Views/ForestView.swift`：删除残留 “mock 植物” 文案。

### Behavior change
- 真实 runtime 链路（engine → tap → analyzer → growth → Result）在 iOS 模拟器上稳定运行，不再崩溃。
- Result DNA 显示真实会话 SoundProfile（不再被空 profile 竞态清零）。

### Design notes
- lldb 断点 `_dispatch_assert_queue_fail` 定位到 tap 闭包：Swift 6 下闭包继承创建上下文（@MainActor）的隔离，AVAudioEngine 在自身 service queue 调用时触发断言；在 nonisolated 上下文创建闭包即可。
- ResultView 优先展示冻结植物（flow.currentPlant），growth.plant 仅作回退，避免耦合层后续修改污染 Result。
- autopilot 钩子仅在 `ECHO_FOREST_AUTOPILOT=1` 时运行，用于无 UI 自动化环境做 runtime 验证，保留在代码中供真机复测。

### Tests
- `xcodebuild -scheme EchoForest -destination 'platform=iOS Simulator,name=iPhone 17' build` PASS。
- iOS 模拟器实测：权限允许/拒绝、真实 buffer、真实 metrics、声音驱动生长、频率响应、Result 真实 DNA、二次会话重置、后台/前台、双会话 3 分钟流程。
- `swift build --package-path EchoForest.swiftpm` PASS；Stage 1–5 self-test 全部 PASS。

### Known risks
- 真机未测；拍手/onset 真机验证 NOT RUN；音频中断处理未实现。

## 2026-08-31 — c26e338

Commit: `feat(plant): add deterministic growth engine`

### Files
- `Sources/Plant/SeededRandom.swift`：新增；SplitMix64 确定性 RNG。
- `Sources/Plant/BranchModel.swift`：新增；BranchModel / PlantEvent / PlantStructure / GenerationMetadata / visibleCounts。
- `Sources/Plant/PlantModel.swift`：新增；PlantModel（id / name / profile / structure）。
- `Sources/Plant/GrowthState.swift`：新增；生长步骤状态。
- `Sources/Plant/PlantGenerator.swift`：新增；五维确定性映射 + 输入规范化 + 硬上限。
- `Sources/Rendering/PlantRenderer.swift`：新增；PlantStructure → Canvas。
- `Sources/Models/MockPlantModel.swift` / `MockSoundProfile.swift`：删除；由 PlantModel / SoundProfile 替代。
- `Sources/Rendering/MockPlantCanvas.swift`：删除；由 PlantRenderer 替代。
- `Sources/Audio/SoundMetrics.swift`：新增显式构造 init；更新过期注释。
- `Sources/App/EchoForestFlow.swift`：plantedPlants / currentPlant 改用 PlantModel，由 PlantGenerator 生成模拟植物。
- `Sources/Views/ForestView.swift` / `GrowingView.swift` / `ResultView.swift`：改用 PlantRenderer + PlantModel。
- `Sources/App/EchoForestRootView.swift`：fallback 使用 PlantGenerator。
- `SelfTests/Stage4PlantSelfTest.swift`：新增；确定性生成器自测。
- `SelfTests/Stage1FlowSelfTest.swift`：断言改为“模拟植物 1”。

### Behavior change
- Growing / Result / Forest 展示由 PlantModel 程序化生成的植物；Growing 通过 GrowthState 模拟逐步生长。
- Result Sound DNA 展示确定性模拟 SoundProfile（Energy / Spectral Centroid / Onset / Duration / Variation），明确标注 mock。

### Design notes
- 模型为纯数据（CGPoint + 数值），不持有 SwiftUI View / Path；Renderer 只做 PlantStructure → Visual。
- 映射集中且可解释：Energy→粗细，Centroid→方向/高度/张角，Variation→弯曲/分叉，Onset→叶/花事件，Duration→尺度/深度/预算。
- 随机性只用 SplitMix64（seed 可控），只影响装饰细节；计数与主要结构由 profile 决定。
- 防御性输入：clamp / fallback / 硬上限；`Double(Int.max)` 先 clamp 再转 Int，避免溢出崩溃；递归深度有界，无无限递归。
- 坐标使用单位空间（约 0...1），Renderer 按 boundingBox 自适应画布；Growing 的可见分支/事件由 `visibleCounts(upTo:)` 派生。
- 音频层（AudioEngineController / AudioAnalyzer）不引用 PlantGenerator，实时耦合未实现（Stage 5 边界）。

### Tests
- `swift build --package-path EchoForest.swiftpm` PASS。
- Stage 4 plant generator self-test PASS（确定性 / 单变量 / 极端输入 / 上限 / 有限几何 / GrowthState）。
- Stage 1 / Stage 2 / Stage 3 regression PASS。
- Xcode / microphone runtime：NOT RUN。

### Known risks
- 真实音频尚未驱动植物（Stage 5）；当前植物由模拟 SoundProfile 驱动。
- 生成的几何在单位空间外延可达约 ±3 单位，Renderer 依赖 boundingBox 自适应；需真机目检。
