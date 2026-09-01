# TEST_PLAN.md — Echo Forest 渐进式验证与回归计划

## 1. 目标

本测试计划采用 **Progressive Validation（渐进式验证）**：每层只引入一种主要新风险，先在可控输入下验证，再接入真实麦克风与最终视觉，防止音频、算法、动画、状态管理同时出错后难以定位。

测试优先级：

P0：比赛现场会直接导致无法体验或违规的问题。
P1：明显影响评分或核心创意可信度的问题。
P2：视觉、手感、边界质量问题。

---

## 2. Stage 0 — Build Baseline

目标：项目可运行。

- [ ] P0 `swift build` / Xcode Build 成功
- [ ] P0 App Playground 可打开
- [ ] P0 首屏可显示
- [ ] P0 无缺失本地资源
- [ ] P0 无必须联网才能加载的内容

完成标准：连续 2 次冷启动可进入首屏。

---

## 3. Stage 1 — 静态流程

使用 mock 数据，不接麦克风。

测试：

- [ ] P0 Forest → Seed
- [ ] P0 Seed → Growing
- [ ] P0 Growing → Result
- [ ] P0 Result → Forest
- [ ] P0 再次进入创作不会残留上一次 GrowthState
- [ ] P1 Result 能展示模拟 Sound DNA
- [ ] P1 植物加入森林后数量正确 +1

回归输入：固定 `SoundProfile.fixtureA`。

---

## 4. Stage 2 — 麦克风与权限

### 允许权限
- [ ] P0 首次请求权限逻辑正确
- [ ] P0 授权后可启动 AVAudioEngine
- [ ] P0 录制结束可正常 stop / reset
- [ ] P1 连续开始/停止 5 次不崩溃

### 拒绝权限
- [ ] P0 明确提示用户需要麦克风
- [ ] P0 不进入伪 Growing 状态
- [ ] P0 不崩溃、不死循环
- [ ] P1 可返回 Forest

### 中断
- [ ] P1 App 进入后台再回来状态合理
- [ ] P1 音频会话中断时不会继续假装录音

---

## 5. Stage 3 — 音频指标

所有指标优先写纯函数/可注入分析输入的测试。

### RMS / Energy

固定样本：

1. 全 0 buffer
2. 极小幅值正弦
3. 中等幅值正弦
4. 高幅值正弦

预期：
- [ ] P0 全 0 接近 0
- [ ] P1 能量值单调随振幅增加
- [ ] P1 超范围值被 clamp
- [ ] P1 noise floor 以下不触发生长

### Pitch / 频域代理

用合成正弦：

- 110 Hz
- 220 Hz
- 440 Hz
- 880 Hz（若采样条件允许）

预期：
- [ ] P1 能区分低/中/高区间
- [ ] P1 相邻帧平滑，不应高频抖动导致枝条乱跳
- [ ] P1 无音高时返回 nil / low confidence，而不是随机大值

若真实 Pitch 检测在 DDL 前稳定性不足，允许降级为 spectral centroid 等频域指标，但必须在日志中如实记录。

### Onset

场景：

- 稳定持续音
- 单次拍手式突发
- 三次间隔突发
- 环境轻噪声

预期：
- [ ] P1 稳定音不连续误触发
- [ ] P1 明显突发可触发一次叶片/开花事件
- [ ] P2 设置最短 debounce，避免单次拍手被重复识别多次

---

## 6. Stage 4 — 植物生成器

先完全不接真实音频。

固定 SoundProfile：

### A — Low / Strong / Stable
预期：更粗、更稳、整体方向偏低/横向。

### B — High / Light / Stable
预期：更细、更高、更轻盈。

### C — Variable / Rhythmic
预期：弯曲/分叉更多，叶片或花事件更多。

验证：
- [ ] P0 不产生 NaN / infinity 坐标
- [ ] P0 不越界到不可见区域
- [ ] P1 A/B/C 最终形态肉眼可分辨
- [ ] P1 固定 random seed 时结果可重复
- [ ] P1 不同 seed 只改变细节，不颠覆声音主特征
- [ ] P2 过长输入有节点上限，避免无限增长

---

## 7. Stage 5 — 实时耦合

真机为主。

固定人工场景：

1. 5 秒静音
2. 5 秒低声持续“呜”
3. 5 秒高声持续“咿”
4. 5 秒音高上下滑动
5. 连续拍手 3 次
6. 大声后突然安静

预期：
- [ ] P0 静音不疯狂生长
- [ ] P1 大声与小声的枝干粗细/生命力有明显差别
- [ ] P1 高低频/音高代理能改变生长趋势
- [ ] P1 拍手触发叶片/开花
- [ ] P1 UI 无明显卡死
- [ ] P1 录音结束后分析与动画状态正确停止

性能观察：
- 不要求每帧 60 FPS，但不得出现长时间冻结。
- Audio callback 不得做文件写入或复杂 UI 操作。

---

## 8. Stage 6 — Forest / Persistence

- [ ] P0 结果加入森林成功
- [ ] P0 重启 App 后若设计为持久化，植物仍存在
- [ ] P1 植物模型保存的是结构/参数，不是巨型截图
- [ ] P1 删除/重置（若有）不会破坏其他数据
- [ ] P2 本地声音文件若保存，应验证体积增长策略

若音频保存会显著增加包体或复杂度，可将“点击树回放声音”降为后续功能；植物核心闭环优先。

---

## 9. Stage 7 — 呈现专项

### 发芽
- [ ] P1 第一段有效声音后 0.5–1.5 秒内产生明显生长反馈

### 生长
- [ ] P1 枝条是连续绘制/展开，不是瞬间替换整张图

### 叶片/花朵
- [ ] P1 出现带 scale/opacity 过渡
- [ ] P2 拍手触发开花具有可感知惊喜

### 文字
- [ ] P1 首屏 5 秒内能理解主操作
- [ ] P1 教程不超过必要信息
- [ ] P1 结果页能让评委理解“声音真的影响了树”

---

## 9.5 Stage 6.5+ — Wild Mode 与 Tree Grammar 2.0

### Tree Grammar 不变量（确定性）

- [ ] P0 trunk taper 合法：所有一级枝比主干细，所有子枝比父枝细
- [ ] P0 branch hierarchy 正确：depth1 挂 trunk，depth2 挂 depth1，depth3 挂 depth2
- [ ] P0 hard branch limits：primary ≤7、secondary ≤20、twigs ≤45、总分枝 ≤72
- [ ] P0 terminal twig 可识别：depth==3 且无子枝
- [ ] P0 blossom 不生成在 trunk 中间（距主干线段 >0.05）
- [ ] P0 geometry finite 且在合理范围
- [x] P0 二次曲线 prefix 包含原曲线 0...fraction 的点（禁止端点 lerp）
- [x] P0 一级枝起点落在主干曲线上；子枝起点落在父枝曲线上
- [x] P0 已显现的一级枝落在当前主干前缀上（弯曲树生长过程不悬空）
- [x] P0 叶片跟随宿主枝条当前挂点 / 尖端，不提前出现在未长到的终点
- [x] P0 实时长会话主干比幼苗更高更粗
- [x] P0 同级主枝长度比 < 1.65
- [x] P0 taper 轮廓宽度等于单位空间 thickness，不会铺满画布

### 固定帧序列映射

- [ ] P0 decreasing energy → left tendency
- [ ] P0 increasing energy → right tendency
- [ ] P0 high centroid → 更向上
- [ ] P0 low centroid → 更横向
- [ ] P0 high variation → 更弯 / 更多分叉（含 recent variability）
- [ ] P0 onset → blossom；连续 onset → blossom cluster
- [ ] P0 silence → 不生长
- [ ] P0 same frames + same seed → same structure

### Wild Mode

- [ ] P0 growLeft / growRight / growUp / branch / bloom 挑战都能被正确识别
- [ ] P0 短噪声不误触发（需要持续满足）
- [ ] P0 challenge failure 不 crash：不满足时会话照常完成，树仍按真实声音生长
- [ ] P0 Wild Burst 不突破 hard limits（高能量 + 乘数持续驱动）
- [ ] P0 Wild session reset：新会话不共享挑战状态
- [ ] P0 时间线 20–30s，暴走恰好一次且位于中间

### Audio / Persistence v2

- [ ] P0 recording file created；duration > 0
- [ ] P0 不同植物使用不同 audio filename
- [ ] P0 PlantRecord（含 growthMode）encode / decode
- [ ] P0 missing audio file 安全（不 crash）
- [ ] P0 old persistence（v1 plants / 旧 v2 无 growthMode）安全迁移
- [ ] P0 relaunch 后两株植物各播自己的录音，不串音频

### Simulator Runtime

- [ ] P0 Forest → Normal → 录音 → Growing → Result → Save → terminate → relaunch → Detail → playback
- [ ] P0 实际进入 Wild Mode（确定性脚本帧走真实 App 路径）验证 left/right/up/variation/bloom
- [ ] P2 REAL CLAP：真机拍手（模拟器无法达到阈值时记为 NOT RUN，不允许伪造 PASS）

---

## 10. Stage 8 — 参赛验收

### 3 分钟计时验收
至少找 1 个没有参与开发的人体验。

记录：
- 从启动到第一次植物完成耗时
- 是否无需解释即可操作
- 是否主动想第二次尝试
- 是否能说出“声音影响植物”的机制

通过条件：
- [ ] P0 主要体验 <= 3 分钟
- [ ] P1 第一次结果最好 <= 90 秒

### 离线

- [ ] P0 飞行模式冷启动
- [ ] P0 飞行模式完成主闭环
- [ ] P0 无网络错误弹窗干扰主流程

### 包体

- [ ] P0 ZIP < 25 MB
- [ ] P1 清理未使用资源
- [ ] P1 不包含 DerivedData / build 产物 / 临时录音 / 调试视频

### PDF

- [ ] P0 文字说明 <= 200 字
- [ ] P0 PDF 可正常打开
- [ ] P0 PDF 与 `.swiftpm` 一并打包 ZIP

---

## 11. 必做回归矩阵

每个可提交候选版本至少跑：

| 场景 | 预期 |
|---|---|
| 首次启动 + 同意麦克风 | 完成主流程 |
| 首次启动 + 拒绝麦克风 | 不崩溃，可回退 |
| 静音 | 不异常生长 |
| 低音持续 | 植物趋势稳定 |
| 高音持续 | 与低音明显不同 |
| 大声 | 能量映射明显 |
| 小声 | 生长较弱但可控 |
| 拍手 x3 | 至少触发可辨识事件 |
| 连续创作 3 棵 | 数据互不污染 |
| 飞行模式 | 主流程完整 |

---

## 12. Bug 分级

### Blocker
- 无法编译
- 启动崩溃
- 麦克风流程不可用
- 核心闭环无法完成
- 依赖网络
- ZIP > 25 MB

### Critical
- 声音不影响植物
- 植物主要由随机数决定
- 结果无法加入森林
- 第二次创作状态混乱

### Major
- 音高映射不稳定
- 拍手频繁误触发
- 动画严重卡顿
- 文案让用户不知如何开始

### Minor
- 局部动画不顺
- 边距、字号、颜色细节
- 非核心页面显示问题

提交前必须清零 Blocker / Critical。
