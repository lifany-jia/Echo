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
- 声音分析：NOT STARTED（Stage 3）
- 植物程序化生成：NOT STARTED（Stage 4）
- 实时耦合：NOT STARTED（Stage 5）
- 森林保存：NOT STARTED（Stage 6）
- 视觉精修：NOT STARTED（Stage 7）
- 提交包：NOT STARTED（Stage 8）

Stage 1 全部声音数据为固定 mock：`MockSoundProfile`（Pitch / Energy / Rhythm / Variation）、`MockPlantModel`、`MockPlantCanvas` 均为静态模拟。Stage 2 已接入 AVAudioEngine 输入链路与权限流程，但唯一真实能力是 `Microphone → AVAudioEngine → AVAudioPCMBuffer`；RMS / FFT / Pitch / Onset / 真实 Sound DNA / 生长映射均未实现。森林状态仅存在于当前运行周期内存，无持久化。

权限配置注意：App Playground 的官方做法是在 Xcode 打开后，通过 Signing & Capabilities 添加 Microphone capability；仓库包根已附带 `Info.plist`（NSMicrophoneUsageDescription）作为尽力配置，需在 Xcode 中确认生效。

真实状态以后以 `COMPLETION_LOG.md` 为准。

## 开发顺序

严格按 `AGENTS.md` Stage 0–8：

0. Build Baseline — DONE
1. Static Experience — DONE（静态 mock 闭环，未接音频）
2. Audio Input — DONE（代码层；真机麦克风 NOT RUN）
3. Audio Metrics — 下一项
4. Growth Engine
5. Real-time Coupling
6. Forest Persistence
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

Stage 2 已完成代码层输入链路。下一项任务是 Stage 3 — Audio Metrics：

> 用纯函数/可注入输入实现并验证 RMS / 能量，再增加 pitch 或频域代理指标，最后增加 onset；继续沿用零依赖自测模式。完成后按 `feat(audio): ...` / `test(audio): ...` 提交。

Stage 2 验证：

- `swift build --package-path EchoForest.swiftpm` PASS
- Stage 1 flow self-test PASS（回归）
- Stage 2 audio state self-test PASS
- 真实麦克风 callback：NOT RUN（当前机器 active developer directory 是 Command Line Tools，无法运行 App Playground / 授权麦克风）

## 绝对不要忘记

- 核心离线。
- 本项目当前不做 AR。
- 不做登录/社区/联网 AI/排行榜等外围功能。
- 音频分析不能由随机数伪装。
- 稳定性优先于功能数量。
