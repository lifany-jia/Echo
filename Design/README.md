# Echo Forest · 主页 UI 设计稿与树的表达

面向 **Echo Forest / 声音森林** 主页（Forest）的一套有艺术感的设计交付物：Figma 风格设计板、程序化树的表达资产、可直接对照 SwiftUI 的设计令牌。

## 设计方向

> 深夜森林：墨夜绿为底、月白为字、琥珀只用于关键动作与反馈。主页中心的意象是「一株正在被声音塑造的树」。

- 单一强调色：琥珀（`#D9A441` / 萤火 `#F2B84B`）
- 一套圆角规则：容器 28 · 卡片 18 · 小组件 12 · 交互胶囊 999
- 所有动画必须有理由（层级 / 叙事 / 反馈），尊重系统「减弱动态」
- 树与植物全部为程序化生成资产，与 App 内 `PlantRenderer` 同源理念，可无限缩放

## 文件结构

```text
Design/
├── figma-design-draft.html      # 主交付物：Figma 风格设计板（浏览器直接打开）
├── design-board-preview.png     # 设计板整板预览图（1680 × 6500）
├── runtime-forest-empty.png     # App 落地后空森林主页截图（iOS 模拟器）
├── runtime-forest-planted.png   # App 落地后已有森林 + 新植物高亮截图
├── PROMPTS.md                   # 可复用提示词库（设计稿 / 图像 / 实现）
├── README.md
├── assets/
│   ├── trees/                   # 7 幅树的表达（SVG 源文件 + 1200×1500 PNG）
│   └── plants/                  # 6 棵主页森林小植物（SVG + 240×300 PNG）
├── AppIcon/                     # App 图标（1024 主图 + 512/256 缩略 + SVG 源）
└── scripts/
    ├── generate_trees.py        # 程序化生成器（纯标准库，可重复生成）
    └── generate_appicon.py      # App 图标生成器（裁切 tree-hero 主视觉）
```

## 使用方式

1. **查看设计稿**：直接双击打开 `figma-design-draft.html`。左侧为图层树，右侧为设计属性面板，点击任意画板可在右侧查看规格。
2. **导入 Figma**：把 `assets/trees/*.svg` 或 `assets/trees/*.png` 直接拖入 Figma 画布。SVG 无损缩放，PNG 为位图预览。
3. **对照实现**：设计板末尾「设计令牌」一节提供了 SwiftUI 映射表（Color / 圆角 / 字体 / 动效），可直接对应 `ForestView.swift`。
4. **复现 / 复刻**：需要把设计方向、图像提示词或实现要求发给其他工具时，直接复制 `PROMPTS.md` 中的对应段落。

主页设计已按本稿落地到 `EchoForest.swiftpm/Sources/Views/ForestView.swift`；`runtime-forest-*.png` 为模拟器实拍验证截图。

## App 图标（`AppIcon/`）

图标复用主页概念主视觉 `tree-hero`，裁出正方形 1024×1024 构图：墨夜绿渐变、
右上月光、树根声音波纹、琥珀花与萤火全部保留，与设计语言一致；无文字、无圆角
（iOS 由系统自动施加圆角遮罩）。

| 文件 | 用途 |
|---|---|
| `app-icon.svg` | 可复现矢量源（1200×1500 源图裁 y∈[240,1440] 后缩放到 1024²） |
| `app-icon-1024.png` | 主图，App Store / AppIcon 标准尺寸 |
| `app-icon-512.png` / `app-icon-256.png` | 缩略图 / 一般展示用 |

重新生成：

```bash
python3 Design/scripts/generate_appicon.py
```

在 Swift Playgrounds（.swiftpm）中设置：打开 App 的 **App Settings → App Icon**，
选择 `app-icon-1024.png`；若用 Xcode 工程，则放入 `Assets.xcassets` 的
`AppIcon.appiconset`。

## 树的表达（六种声音性格）

| 资产 | 声音特征 | 视觉表达 |
|---|---|---|
| `tree-hero` | 主页概念主视觉 | 不对称、微光、稀疏琥珀花的「声音树」 |
| `tree-deep-bass` | RMS 高（低沉大声） | 粗壮树干、外扩根盘、低垂浓冠 |
| `tree-high-pitch` | 音高 / 频谱高 | 细长主干、向上喷涌的银绿枝条 |
| `tree-rhythm` | Onset / 拍手 | 带折角的枝干、枝头绽开的琥珀花 |
| `tree-sustained` | 持续时间长 | 波状枝、层层叠叠的圆润树冠 |
| `tree-melody` | 音调变化大 | S 形蜿蜒主干、丝带般流动枝条 |
| `tree-wild` | 暴走挑战模式 | 锯齿枝干、琥珀闪电、火花爆裂 |

## 重新生成

```bash
python3 Design/scripts/generate_trees.py
```

生成器使用确定性随机种子，同一脚本在任何机器上产出完全一致的 SVG。PNG 由 SVG 渲染得到（设计稿内直接引用 SVG，保证清晰度）。
