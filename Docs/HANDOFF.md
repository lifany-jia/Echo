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
- 植物生成（Stage 4）：DONE（代码层；真实麦克风耦合 NOT STARTED）
- 实时耦合（Stage 5）：DONE（代码层；真实麦克风耦合 NOT RUN）
- 森林保存：NOT STARTED（Stage 6）
- 视觉精修：NOT STARTED（Stage 7）
- 提交包：NOT STARTED（Stage 8）

Stage 1–4 状态：Stage 2 已接入 AVAudioEngine 输入链路与权限流程；Stage 3 已实现真实指标 RMS / Energy、Spectral Centroid（频率代理，非 Pitch）、Onset；Stage 4 已建立 Plant 模块与五维确定性映射（相同 profile + seed 完全可复现）。Stage 5 已实现实时耦合：GrowthSession（纯核心）+ LiveGrowthController（150ms cadence）把 SoundFrame 序列增量推进植物，静音不增长、有声才长、大声更粗更长、onset 开花；Result 冻结 Growing 的最终 PlantModel，Sound DNA 为会话 SoundProfile（明确叫 Spectral Centroid）。持久化（Stage 6）未实现；森林状态仅存在于当前运行周期内存。

权限配置注意：App Playground 的官方做法是在 Xcode 打开后，通过 Signing & Capabilities 添加 Microphone capability；仓库包根已附带 `Info.plist`（NSMicrophoneUsageDescription）作为尽力配置，需在 Xcode 中确认生效。

真实状态以后以 `COMPLETION_LOG.md` 为准。

## 开发顺序

严格按 `AGENTS.md` Stage 0–8：

0. Build Baseline — DONE
1. Static Experience — DONE（静态 mock 闭环，未接音频）
2. Audio Input — DONE（代码层；真机麦克风 NOT RUN）
3. Audio Metrics — DONE（代码层；真机音频集成 NOT RUN）
4. Growth Engine — DONE（代码层；真实麦克风耦合 NOT STARTED）
5. Real-time Coupling — DONE（代码层；真实麦克风耦合 NOT RUN）
6. Forest Persistence — 下一项
7. Presentation Polish
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

Stage 5 已完成代码层实时耦合。下一项任务是 Stage 6 — Forest Persistence：

> 结果加入森林后本地保存轻量数据（PlantStructure / SoundProfile 的 Codable 或等价轻量方案），重启后仍可显示；保持 25MB 与离线约束。完成后按 `feat(persistence): ...` 提交。

Stage 5 验证：

- `swift build --package-path EchoForest.swiftpm` PASS
- Stage 5 coupling self-test PASS（Scenario A–F：静音 / 大声 / 高低频 / onset / expressive / 确定性回放）
- Stage 1 / Stage 2 / Stage 3 / Stage 4 regression PASS
- 真实麦克风耦合：NOT RUN（Command Line Tools 环境）

## 绝对不要忘记

- 核心离线。
- 本项目当前不做 AR。
- 不做登录/社区/联网 AI/排行榜等外围功能。
- 音频分析不能由随机数伪装。
- 稳定性优先于功能数量。
