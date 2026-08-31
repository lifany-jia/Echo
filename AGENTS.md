# AGENTS.md — Echo Forest / 声音森林

> 本文件是 Codex 在本仓库中的最高优先级项目执行规范。除系统级指令外，所有实现、重构、测试、提交、文档与交接工作必须遵守本文件。

## 1. 项目目标

项目名称：**Echo Forest / 声音森林**

一句话定义：

> 用声音种下一棵树。用户通过说话、哼唱、拍手等声音输入，让声音特征实时转化为植物的生长行为，最终形成一株独一无二的植物并种入自己的声音森林。

本项目不是普通录音器、频谱仪或静态随机树生成器。其核心必须始终是：

**声音特征 → 生长规则 → 可解释的植物形态 → 森林收藏**

任何功能若不能加强上述核心体验，应默认不做。

---

## 2. 参赛硬性规则

Codex 在实现任何功能、依赖、资源或打包逻辑前，必须检查其是否违反以下规则：

1. 作品类型必须为 **App Playground (`.swiftpm`)**。
2. 作品须可在 **3 分钟内完成主要体验**。
3. 需提交一份 **PDF 作品文字说明，200 字以内**。
4. App 将被 **离线评审**，不可依赖网络连接。
5. 所有运行所需资源必须位于项目本地，并包含在最终 ZIP 中。
6. 最终 ZIP **不得超过 25 MB**。
7. 比赛总规则要求所有主题作品中至少 2 个使用 ARKit；**本项目当前明确为非 AR 作品**，不要为了满足团队级 AR 数量要求强行加入 ARKit。
8. 主题分类优先归入 **音乐**；如主办方允许，也可兼容“创作/生活”叙事，但开发过程中不要为了多分类牺牲核心一致性。
9. 评分维度：
   - 功能完整性：3 分
   - 技术难度：3 分
   - 创意性：2 分
   - 呈现效果：2 分
   - 单作品评委评分满分 10 分
10. 作品可随时提交，当前 DDL：**2026-09-02 22:00**。

### 项目评分目标

- 功能完整性：目标 3/3
- 技术难度：目标 3/3
- 创意性：目标 2/2
- 呈现效果：目标 2/2

任何新增功能都必须能说明自己主要提升上述哪一项，否则默认进入 backlog 而不是当前实现。

---

## 3. 核心体验闭环

首个完整版本必须完成以下闭环：

1. 进入森林（Forest）
2. 开始一次声音创作（Seed）
3. 获取麦克风输入
4. 实时分析声音
5. 植物随声音实时生长（Growing）
6. 结束录制后生成最终植物（Result）
7. 展示声音画像 / Sound DNA
8. 将植物种入森林
9. 可再次创作一棵植物

未经明确要求，不得优先开发登录、账户、云同步、网络社区、排行榜、商店、复杂成就系统、远程 AI、歌曲联网识别、3D 场景、AR、广告或支付。

---

## 4. 三分钟体验设计

目标体验节奏：

### 0:00–0:15 — Forest
- 显示已有森林或初始空地。
- 一句话建立概念：`每一种声音，都可以生长。`
- 明确主操作：`种下一段声音`。

### 0:15–0:30 — Seed
- 中央出现种子。
- 首次使用时请求麦克风权限。
- 用最少文字提示：`给它一点声音。`

### 0:30–1:15 — Growing
- 输入声音时必须有实时视觉反馈。
- 不允许“录完后长时间分析，再突然生成整棵树”作为主体验。
- 生长过程应体现至少：音量、音高/频率变化、声音突发/节奏、持续时间。

### 1:15–1:45 — Result
- 展示植物名称或类型。
- 展示 Sound DNA：Pitch / Energy / Rhythm / Variation / Duration 中至少 4 项。
- 让评委理解植物不是纯随机生成。

### 1:45–2:30 — Forest Return
- 植物回到森林。
- 用户可点击查看该植物。
- 若已保存原始录音，可支持本地回放；如果大小或时间风险较高，先做可选功能。

### 2:30–3:00 — Second Try / Discovery
- 鼓励第二次尝试不同声音。
- 推荐隐藏反馈：拍手或明显 onset 可触发“开花”行为。
- 目标是让用户主动产生：`换一种声音会长成什么？`

---

## 5. 声音 → 植物映射规范

必须保证映射**稳定、可解释、有差异**。首版不要堆太多参数。

| 声音特征 | 推荐植物映射 | 首版要求 |
|---|---|---|
| RMS / 能量 | 树干或枝条粗细、生命力 | 必须 |
| Pitch / 主频 | 生长方向、整体高度趋势 | 必须，若可靠性不足则先降级为频谱重心 |
| Pitch Variation | 枝条弯曲、分叉倾向 | 推荐 |
| Onset / 突发声音 | 长叶、开花、分枝事件 | 必须至少一种 |
| Duration | 总体尺度、可生长节点数量 | 必须 |

### 映射原则

- 不允许简单写死“高音=红花、低音=蓝花”后随机生成整棵树。
- 相同输入在相同随机种子下应产生近似一致的结构。
- 随机性只能用于细节丰富，不得盖过声音特征本身。
- 对过小、过大、无效音频值做 clamp / normalize。
- 对麦克风噪声设置 noise floor，避免静音时疯狂生长。
- 音频分析必须在本地完成，不允许调用网络 API。

---

## 6. 技术建议与边界

优先技术：

- Swift / SwiftUI
- AVFoundation / AVAudioEngine
- Accelerate / vDSP（如用于 FFT / 频谱处理）
- Canvas / Shape / Path / TimelineView / SpriteKit（二选一或少量组合）
- 本地 Codable / FileManager / SwiftData 仅在确有必要时使用

### 不要过度设计

默认不要：

- 引入第三方依赖，除非可以证明必要且不会增加离线/体积/兼容风险。
- 在 MVP 阶段引入复杂 MVVM/Clean Architecture 层级。
- 为“未来扩展”预先抽象大量协议。
- 先做设置页、教程页、成就页等外围页面。

首选原则：**少依赖、少页面、强闭环、强反馈。**

---

## 7. 推荐模块边界

建议目录，不强制逐字一致，但职责必须清晰：

```text
EchoForest.swiftpm/
├── Package.swift
├── Sources/
│   ├── App/
│   │   └── EchoForestApp.swift
│   ├── Audio/
│   │   ├── AudioEngineController.swift
│   │   ├── AudioAnalyzer.swift
│   │   ├── PitchDetector.swift
│   │   └── OnsetDetector.swift
│   ├── Plant/
│   │   ├── PlantModel.swift
│   │   ├── BranchModel.swift
│   │   ├── PlantGenerator.swift
│   │   └── GrowthState.swift
│   ├── Rendering/
│   │   ├── PlantCanvas.swift
│   │   ├── GrowthAnimator.swift
│   │   └── ParticleLayer.swift
│   ├── Models/
│   │   ├── SoundProfile.swift
│   │   └── ForestModel.swift
│   ├── Persistence/
│   │   └── ForestStore.swift
│   └── Views/
│       ├── ForestView.swift
│       ├── SeedView.swift
│       ├── GrowingView.swift
│       └── ResultView.swift
├── Tests/
├── Docs/
│   ├── TEST_PLAN.md
│   ├── COMPLETION_LOG.md
│   ├── CODE_LOG.md
│   └── HANDOFF.md
└── AGENTS.md
```

---

## 8. 状态设计

首版优先用一个明确的 AppFlow / enum 管理：

```swift
enum AppStage {
    case forest
    case seed
    case growing
    case result
}
```

不要在多个 View 中用大量互相独立的 Bool 控制页面跳转。

核心数据建议：

- `SoundProfile`
- `PlantModel`
- `ForestModel`
- `GrowthState`

UI 不应直接承担 DSP 或植物生成算法。

---

## 9. 质量门槛

### 功能

- 首次启动不崩溃。
- 麦克风允许与拒绝两条路径都可正常处理。
- 静音输入不会异常生成巨型植物。
- 高频/低频/大声/小声/拍手之间能观察到至少部分明显差异。
- 结束录制后能得到结果。
- 结果能加入森林。
- 再次创作不会污染上一棵植物的数据。

### 性能

- 音频 callback 中禁止做重 UI 工作、文件 IO、大量分配。
- 音频分析与 UI 更新频率应解耦；UI 不需要跟随每一个采样点刷新。
- 动画目标以评审设备稳定为先，避免无意义的粒子数量堆叠。

### 包体

- 最终 ZIP < 25 MB。
- 禁止加入不使用的大体积音视频、字体、模型或图片。
- 优先程序化图形和系统字体。

### 离线

- 飞行模式下可以完成完整主流程。
- 任何核心体验不得依赖 URLSession / WebView / 远程 CDN / 远程字体 / 远程模型。

---

## 10. 渐进式实现策略

Codex 每次工作必须尽量只推进一个可验证层级，不允许跨越多个层级后再统一修错。

### Stage 0 — Build Baseline
目标：项目可编译运行。

### Stage 1 — Static Experience
目标：Forest → Seed → Growing → Result → Forest 的静态导航闭环成立，先不接真实音频。

### Stage 2 — Audio Input
目标：AVAudioEngine 可稳定获取音频 buffer；权限拒绝路径完整。

### Stage 3 — Audio Metrics
目标：实时得到 RMS / 能量；再增加 pitch 或频域指标；最后增加 onset。

### Stage 4 — Growth Engine
目标：用模拟参数先生成植物，再连接真实声音数据。

### Stage 5 — Real-time Coupling
目标：真实音频驱动实时生长，验证响应性和稳定性。

### Stage 6 — Forest Persistence
目标：结果可加入森林，本地保存必要的轻量数据。

### Stage 7 — Presentation Polish
目标：发芽、生长、叶片、开花、回到森林的动画与文字收敛。

### Stage 8 — Submission Hardening
目标：离线、包体、权限、异常、3 分钟体验、PDF 文案、ZIP 验收。

每完成一个 Stage：
1. 执行对应测试。
2. 更新 `Docs/COMPLETION_LOG.md`。
3. 更新 `Docs/CODE_LOG.md`。
4. 使用 Conventional Commit 提交。
5. 不允许未测试就标记完成。

---

## 11. 测试原则

详细测试见 `Docs/TEST_PLAN.md`。

核心原则：

- 先单元验证算法，再接 UI。
- 先模拟 SoundProfile，再接麦克风。
- 每加入一个声音维度，只验证该维度是否改变植物，不同时加入多个不可解释变量。
- 每次视觉升级后，都重新验证 3 分钟主流程与性能。
- 对“无权限、无声音、极大声音、短促爆音、连续高音、连续低音”设置固定回归场景。

---

## 12. Conventional Commit — 强制 Git 规则

所有提交必须符合 **Conventional Commits**。

格式：

```text
<type>(<scope>): <subject>
```

允许的主要 type：

- `feat`: 新功能
- `fix`: bug 修复
- `refactor`: 不改变外部行为的重构
- `perf`: 性能优化
- `test`: 测试新增或修改
- `docs`: 文档
- `style`: 仅格式、排版，不改变逻辑
- `build`: 构建系统/依赖/包配置
- `ci`: CI 相关
- `chore`: 其他维护任务
- `revert`: 回滚

推荐 scope：

- `audio`
- `plant`
- `rendering`
- `forest`
- `flow`
- `persistence`
- `tests`
- `docs`
- `submission`

示例：

```text
feat(audio): add real-time RMS analysis
feat(plant): map audio energy to branch thickness
fix(audio): ignore buffers below noise floor
perf(rendering): throttle plant canvas refresh rate
test(plant): add deterministic growth mapping cases
docs(handoff): update stage 4 implementation status
```

### 提交纪律

- 一个 commit 只表达一个逻辑目的。
- 不允许 `update`, `changes`, `fix stuff`, `wip`, `final`, `aaa` 等无意义提交信息。
- 除非用户明确要求，不得使用 `git push --force`。
- 不得擅自改写已共享历史。
- 不得把编译失败状态作为阶段完成提交。
- 若实现与测试是同一功能的不可分割部分，可同一 feat commit；若测试是独立补充，使用 `test(...)`。
- 文档必须与对应实现同批更新，不要把日志长期拖欠到最后。

---

## 13. Codex 每次任务结束的强制动作

每次完成用户给出的实现任务后，Codex 必须：

1. 运行可执行的编译/测试检查。
2. 明确记录实际执行过的命令和结果。
3. 更新 `Docs/COMPLETION_LOG.md`：记录完成了什么、验证了什么、还剩什么。
4. 更新 `Docs/CODE_LOG.md`：记录重要代码结构、设计决策、文件变化、风险。
5. 更新 `Docs/HANDOFF.md`：保持为新对话可直接读取的“当前唯一真相”。
6. 按 Conventional Commit 规范提交。
7. 在最终回复中报告：
   - 完成内容
   - 测试结果
   - commit hash + commit message
   - 未完成项 / 风险

如果无法完成某项测试，必须明确写为 `NOT RUN`，说明原因；禁止假装测试已通过。

---

## 14. 文档同步原则

### `COMPLETION_LOG.md`
回答：**已经做完什么？现在推进到哪？**

### `CODE_LOG.md`
回答：**代码现在怎么组织？为什么这样设计？最近改了什么？**

### `HANDOFF.md`
回答：**一个完全没读过历史的新对话，现在只看这一个文件，应该知道什么？**

文档中禁止写模糊状态，例如“基本完成”“应该可以”。使用：

- DONE
- IN PROGRESS
- BLOCKED
- NOT STARTED
- NOT RUN

---

## 15. 当前 MVP Definition of Done

满足以下全部条件才可以把 MVP 标记为 DONE：

- [ ] `.swiftpm` App Playground 可正常打开并编译运行
- [ ] Forest / Seed / Growing / Result 四阶段闭环完成
- [ ] 麦克风权限允许路径正常
- [ ] 麦克风拒绝路径有清晰降级提示，不崩溃
- [ ] 本地实时音频输入正常
- [ ] 至少 RMS / Energy 实时计算正常
- [ ] 至少一个可靠的 Pitch 或频域代理指标正常
- [ ] 至少一个 Onset / 突发声音检测机制正常
- [ ] 声音变化能明显改变植物至少 3 个视觉特征
- [ ] 植物是程序化生成，不是从固定图片中随机抽取
- [ ] 植物能随声音实时生长
- [ ] 结果页显示可解释 Sound DNA
- [ ] 结果可加入森林
- [ ] 第二次创作不会污染第一次数据
- [ ] 飞行模式主流程可用
- [ ] 无远程资源依赖
- [ ] 最终 ZIP < 25 MB
- [ ] 典型体验可在 3 分钟内完成
- [ ] PDF 说明文案 <= 200 字
- [ ] Docs 日志与 Handoff 已更新
- [ ] Git 历史符合 Conventional Commit

---

## 16. 明确禁止的“伪完成”

以下情况不得声称功能已完成：

- UI 有按钮但按钮没有真实行为。
- 用随机数伪装音频分析，却没有在日志中明确标注为 mock。
- 只在 Preview 工作，真机麦克风链路未验证。
- 只测试自己设备上已授权路径，未考虑权限拒绝。
- 植物只是换几张预制图片。
- 录音结束后完全随机生成树，却宣称“声音决定植物”。
- 使用网络服务但因为当前有网所以看起来能运行。
- 没有实际运行测试就写 PASS。

---

## 17. 项目价值判断

当存在取舍时，优先级始终为：

1. **声音实时影响植物的可信度**
2. **三分钟内的完整闭环**
3. **生长动画和视觉反馈**
4. **离线稳定性与包体**
5. **代码清晰和可维护性**
6. 扩展功能

如 DDL 临近，应优先删功能，不允许牺牲核心流程稳定性。
