# CODE_LOG.md — 代码与架构日志

> 用于记录代码结构、关键技术决策、重要变更和已知风险。目标是让新对话无需翻 Git 历史即可理解当前实现。

## 1. 当前架构状态

**代码状态：Stage 0 DONE**

当前已创建最小 App Playground：

- `EchoForest.swiftpm/Package.swift`：SwiftPM 包配置，生成 `EchoForest` executable。
- `EchoForest.swiftpm/Sources/App/EchoForestApp.swift`：SwiftUI App 入口。
- `EchoForest.swiftpm/Sources/App/AppStage.swift`：当前仅包含 Stage 0 所需的 `forest` 状态。
- `EchoForest.swiftpm/Sources/Views/ForestView.swift`：首屏 Forest 基线视图。

后续仍按推荐模块推进：

- `Audio`：麦克风输入、RMS、频域/Pitch、Onset
- `Plant`：程序化植物模型与生长规则
- `Rendering`：枝条绘制、生长动画、粒子/叶片/花朵
- `Models`：SoundProfile / ForestModel
- `Persistence`：轻量本地保存
- `Views`：Forest / Seed / Growing / Result

实际实现后，以仓库代码为准，并更新本文件。

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
