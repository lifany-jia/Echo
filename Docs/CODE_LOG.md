# CODE_LOG.md — 代码与架构日志

> 用于记录代码结构、关键技术决策、重要变更和已知风险。目标是让新对话无需翻 Git 历史即可理解当前实现。

## 1. 当前架构状态

**代码状态：Stage 3 DONE（Audio Metrics；真实麦克风 → analyzer 集成 NOT RUN）**

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
- `EchoForest.swiftpm/Sources/App/EchoForestRootView.swift`：持有 flow + audio；Seed “开始创作”异步执行权限 → startListening → 成功才进入 Growing；拒绝/失败弹 alert。
- `EchoForest.swiftpm/Sources/Views/SeedView.swift`：种子页；按钮“开始创作”，提示首次请求权限。
- `EchoForest.swiftpm/Sources/Views/GrowingView.swift`：Listening 徽标 + buffer 链路计数 + Live Metrics 面板（Energy / Spectral Centroid / Onset count / Duration）+ 取消按钮；植物视觉仍为 mock。
- `EchoForest.swiftpm/Sources/Models/MockSoundProfile.swift` / `MockPlantModel.swift`：mock 数据（Stage 1 保留）。
- `EchoForest.swiftpm/Sources/Rendering/MockPlantCanvas.swift`：Canvas 程序化 mock 植物（Stage 1 保留）。
- `EchoForest.swiftpm/Sources/Views/ForestView.swift` / `ResultView.swift`：森林 / 结果页（Stage 1 保留，Result 继续展示 Mock Sound DNA）。
- `EchoForest.swiftpm/SelfTests/Stage1FlowSelfTest.swift` / `Stage2AudioSelfTest.swift` / `Stage3MetricsSelfTest.swift`：零依赖自测。
- `EchoForest.swiftpm/Info.plist`：NSMicrophoneUsageDescription（尽力配置；官方路径为 Xcode capability）。

Stage 4+ 模块（Plant / Persistence）尚未创建；PitchDetector 未实现（以 Spectral Centroid 代理）。

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

## 2026-08-31 — pending

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
