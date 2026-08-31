# HANDOFF.md — 新对话快速接手

> 新的 Codex / ChatGPT 对话应先读 `AGENTS.md`，再读本文件，然后根据当前任务读取 `TEST_PLAN.md`、`COMPLETION_LOG.md`、`CODE_LOG.md`。

## 项目

**Echo Forest / 声音森林**

核心概念：

> 用户的声音不是被画成普通波形，而是成为植物的“生长基因”。音量、音高/频域、变化、节奏/突发和持续时间映射到枝条、方向、弯曲、叶片/花朵和总体尺度，最终生成独一无二的植物并种入森林。

## 当前目标

先完成非 AR MVP，优先保证：

1. 三分钟内可完成体验
2. 完全离线
3. ZIP < 25 MB
4. 声音真实影响植物
5. 实时生长有视觉反馈
6. Forest → Seed → Growing → Result → Forest 闭环

## 当前状态

截至 2026-08-31：

- 项目治理与测试文档：DONE
- Git 仓库：DONE
- SwiftPM App Playground：DONE
- Stage 1 静态体验闭环（Forest → Seed → Growing → Result → Forest）：DONE
- 音频输入（Stage 2）：DONE（代码层；真实麦克风运行时 NOT RUN）
- 声音分析（Stage 3）：DONE（代码层；真实麦克风 → analyzer 集成 NOT RUN）
- 植物生成（Stage 4）：DONE（确定性生成 + Stage 6.5 tree grammar）
- 实时耦合（Stage 5）：DONE（真实麦克风 runtime PASS）
- 森林保存（Stage 6）：DONE（模拟器 kill/relaunch 实测 PASS）
- Stage 6.5 Sound Tree Redesign & Audio Memory：DONE（模拟器录音/保存/重启/详情播放 PASS）
- Stage 6.5+ Wild Mode + Tree Grammar 2.0 渲染 + PlantRecord v2：DONE（模拟器 Normal/Wild runtime PASS；真机/真实拍手 NOT RUN）
- Stage 6.5 Creative Refactor（Echo/Wild 双模式 + SoundGestureAnalyzer + Wild Free For All）：DONE（确定性自测 9/9 + 模拟器 Echo/Wild/持久化 runtime PASS；PHYSICAL CLAP NOT RUN）
- 真机验证（iPhone 17 / iOS 26.6.1）：DONE（修复真机 48kHz 输入崩溃 + 树底部锚定 + 设计稿配色；真机安装运行 PASS）
- Design 主页 UI 设计稿与树的表达（并行交付物，`Design/`）：DONE
- Stage 7 主页视觉落地（Forest 主页按设计稿重做）：DONE（模拟器截图验证；用户已明确恢复主页部分）
- App 图标（`Design/AppIcon/`，基于 tree-hero 主视觉的正方形构图）：DONE
  （1024 主图 + 512/256 + SVG 源 + 可复现脚本 `Design/scripts/generate_appicon.py`；
  Swift Playgrounds 在 App Settings → App Icon 里设置）
- 视觉精修（Growing / Result / Detail）：PAUSED / NOT STARTED（Stage 7 其余部分仍等用户明确恢复）
- 提交包：NOT STARTED（Stage 8）

Stage 1–6.5 状态：Stage 2 已接入 AVAudioEngine 输入链路与权限流程；Stage 3 已实现真实指标 RMS / Energy、Spectral Centroid（频率代理，非 Pitch）、Onset；Stage 4/6.5 的 Plant 模块现在使用明确层级 tree grammar（1 trunk、4–7 primary、secondary、terminal twigs），相同 sound-frame 序列 + seed 完全可复现。Stage 5 已实现实时耦合：GrowthSession（纯核心）+ LiveGrowthController（150ms cadence）把 SoundFrame 序列增量推进植物，静音不增长、有声才长、大声更粗更长、energy slope 控制左右、centroid 控制横向/向上、variation 控制弯曲、onset 在 terminal twigs 开花。Stage 6 持久化已升级为 PlantRecord：PlantModel + SoundProfile + createdAt + relative audio filename + audioDuration；音频保存在 `Application Support/EchoForest/Audio/<plantUUID>.m4a`，JSON 不存 base64。

Stage 6.5+（本阶段）：
- `GrowthMode`（normal / wild）：Forest 双入口（主“种下一段声音”，次“⚡ 让它暴走”）。
- Wild Mode 纯核心 `WildSession`：约 28s 确定性时间线（开场 → 3-2-1 → growLeft/growRight/growUp/branch/bloom → 中间一次“暴走！”4s → 冷静）。挑战无失败惩罚；识别只用现有 Energy slope / Spectral Centroid / recent Variation / Onset。
- 暴走乘数：growth ×1.35 / 新枝长度 ×1.12 / 花尺寸 ×1.25；hard limits 仍由 PlantGenerator 保证（runtime 分支 ≤58/72、花 ≤41/64）。
- Tree Grammar 2.0 渲染：PlantRenderer 用“从粗到细”的二次曲线填充画主干与各级枝，花只在末梢/树冠外围（距主干 >0.055）。
- PlantRecord 新增 `growthMode`（旧 v1 / 旧 v2 存档均安全迁移为 normal）。
- 测试：新增 `Stage65WildModeSelfTest`；`Stage65SoundTreeAudioSelfTest` 扩展 tree grammar 不变量 / migration / missing audio。
- Runtime 钩子：`ECHO_FOREST_AUTOPILOT_WILD=1`（真实 App 路径 + 确定性脚本帧）；`ECHO_FOREST_AUTOPILOT_DETAIL_PLAY=1` 现在会逐个打开所有记录并播放各自的 M4A。

### Stage 6.5+ Runtime 实测（2026-08-31，iPhone 17 Pro / iOS 26.5）

- Normal 完整闭环：真实麦克风 2 次录音 → Growing → Result → 种进森林 → terminate → relaunch → Detail → 两棵各自播放自己的 M4A（`playbackActive=true`，文件各不相同）PASS。
- Wild 完整闭环：Seed（“它正在暴走……/开始驯服”）→ 倒计时 → 5 挑战全部 `succeeded=true` → 暴走（OCR：`暴走！ 别让它失控！`）→ 冷静 → Result → 种进森林（forest.json `growthMode=wild` + 自己的 M4A）→ relaunch → Detail 播放 PASS。
- REAL CLAP：NOT RUN（扬声器→模拟器麦克风峰值 energy≈0.31 < onset 阈值 0.35；确定性 onset/bloom 测试 PASS，真实拍手待真机）。

### Runtime Gate 实测（2026-08-31，iOS 模拟器 iPhone 17 Pro / iOS 26.5，宿主 Mac 麦克风）

- App 启动 / Forest 首屏：PASS
- 首次“开始创作”系统麦克风权限弹窗：PASS
- 权限允许：PASS；权限拒绝：PASS（“需要麦克风权限”弹窗，可返回森林/留在 Seed，不崩溃）
- 真实 AVAudioPCMBuffer callback：PASS（buffer 9→122，frameLength 4410）
- 真实 AudioAnalyzer metrics：PASS
- 静音门控：PASS（确定性测试；环境有底噪未取真静音样本）
- 声音驱动生长：PASS（steps 0→3）；频率代理响应：PASS（220Hz→226Hz，880Hz→543Hz）
- 拍手/onset：NOT RUN（模拟器扬声器→麦克风路径能量不足；逻辑由 Stage 5 Scenario D 覆盖，真机待验证）
- Result 植物一致 + Sound DNA 真实：PASS（Energy 0.17 / 522 Hz / 12.1s / Variation 0.04）
- 第二次会话重置：PASS（新 plantID、buffers/steps/duration 重置、engine 重启）
- 后台/前台：PASS（无崩溃）；3 分钟流程：PASS（单会话约 19s）

Runtime 修复记录：tap 闭包 MainActor 隔离崩溃（已修复）；Result DNA 空 profile 竞态（已修复）；Forest “mock 植物”残留文案（已修复）。

环境注意：完整 Xcode 26.6 已安装但 active developer directory 仍为 Command Line Tools（sudo 需密码）；使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 覆盖可跑 xcodebuild / 模拟器。

### Stage 6 持久化实测（2026-08-31，模拟器）

- clean install → 首屏空森林（“这里还没有植物”）。
- Plant A 种进森林（`[PERSISTENCE] saved forest with 1 plants`）→ `simctl terminate` → relaunch → “已种下1棵植物 / 模拟植物1”。
- Plant B 追加（`saved forest with 2 plants`）→ terminate → relaunch → “已种下2棵植物 / 模拟植物1 / 模拟植物 2”。
- 容器内 `forest.json`：version 1、plants=2、ID 唯一。
- 持久化策略：只在“种进森林”保存；保存成功才采用快照；失败留在 Result 提示重试；损坏数据安全失败不 crash。

### Stage 6.5 实测（2026-08-31，iOS 模拟器 iPhone 17 / iOS 26.5）

- Tree Grammar：PASS（确定性自测覆盖 slope left/right、centroid upward、variation curvature、onset blossom/cluster、silence no-growth、hard limits、flower terminal twigs）。
- Audio Memory：PASS（AVAudioRecorder 写 AAC/M4A；Audio analyzer 仍用 AVAudioEngine tap）。
- PlantRecord：PASS（forest.json version 2，records + relative audioFilename；v1 plants archive 可迁移）。
- Runtime：clean install + microphone grant + Growing + real recording + Result + plant in forest + terminate/relaunch + detail playback hook PASS。
- 容器验证：PlantRecord 指向自己的 `<plantUUID>.m4a`；前两条 runtime 录音约 12.07s / 8.26s，第三条来自早期未终止长录制，metadata 30.00s，验证 max duration cap。
- Playback：relaunch 后打开 Plant Detail 并调用 Play/Pause handler，`playbackActive=true`。

权限配置注意：App Playground 的官方做法是在 Xcode 打开后，通过 Signing & Capabilities 添加 Microphone capability；仓库包根已附带 `Info.plist`（NSMicrophoneUsageDescription）作为尽力配置，需在 Xcode 中确认生效。

真实状态以后以 `COMPLETION_LOG.md` 为准。

## 开发顺序

严格按 `AGENTS.md` Stage 0–8：

0. Build Baseline — DONE
1. Static Experience — DONE（静态 mock 闭环，未接音频）
2. Audio Input — DONE（代码层；真机麦克风 NOT RUN）
3. Audio Metrics — DONE（代码层；真机音频集成 NOT RUN）
4. Growth Engine — DONE（确定性 PlantModel / tree grammar）
5. Real-time Coupling — DONE（模拟器实测 PASS；真机耦合 NOT RUN）
6. Forest Persistence — DONE（模拟器 kill/relaunch 实测 PASS）
6.5 Sound Tree Redesign & Audio Memory — DONE（模拟器录音/保存/重启/播放 PASS）
6.5+ Wild Mode + Tree Grammar 2.0 + PlantRecord v2 — DONE（模拟器 Normal/Wild runtime PASS）
7. Presentation Polish — PAUSED / NOT STARTED（不要继续，除非用户恢复）
8. Submission Hardening

不要跨层一次性实现大量功能。

## Git

必须使用 Conventional Commit：

```text
feat(audio): add real-time RMS analysis
fix(plant): clamp branch growth bounds
test(audio): cover silent buffer analysis
docs(handoff): update current project state
```

每个任务结束必须：

- 实际运行测试/编译
- 更新 `COMPLETION_LOG.md`
- 更新 `CODE_LOG.md`
- 更新本文件
- Conventional Commit 提交
- 回复 commit hash + message + 测试结果 + 风险

## 当前最推荐的第一项代码任务

Stage 6.5+ 已完成。当前不要开始 Stage 7；下一步必须等用户明确恢复 Presentation Polish 或给出新的修正项。

主页视觉已按设计稿落地（`Sources/Views/ForestView.swift`），模拟器截图见 `Design/runtime-forest-*.png`；可复用提示词见 `Design/PROMPTS.md`。若继续 Stage 7 其余部分（Growing / Result / Detail 视觉精修），请用户明确恢复后再动手；设计基准仍是 `Design/figma-design-draft.html` 与 `Design/assets/`。

当前验证基线：

- `xcodebuild -scheme EchoForest -destination 'platform=iOS Simulator,name=iPhone 17' build` PASS
- 模拟器 Runtime Gate + Stage 6.5 audio memory + Stage 6.5+ Wild + detail playback 实测 PASS（详见 COMPLETION_LOG）
- `swift build --package-path EchoForest.swiftpm` PASS；Stage 1–6.5+（8 个）self-test 全部 PASS
- 真机、人耳听感、真实拍手、音频中断处理：NOT RUN / 未实现

## 绝对不要忘记

- 核心离线。
- 本项目当前不做 AR。
- 不做登录/社区/联网 AI/排行榜等外围功能。
- 音频分析不能由随机数伪装。
- 稳定性优先于功能数量。
