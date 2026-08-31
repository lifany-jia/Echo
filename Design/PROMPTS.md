# Echo Forest · 可复用提示词库

三组提示词，均可直接复制使用：主页 UI 设计稿、树的表达图像、SwiftUI 落地实现。

---

## 一、主页 UI 设计稿提示词

### 一句话版

> 为 iOS 音乐创意 App「声音森林」设计一个有艺术感的主页：深夜森林美学，墨夜绿渐变背景、月白文字、单一琥珀强调色、萤火微光，中心是「种子 → 长成声音树」的意象，底部是琥珀主 CTA「种下一段声音」和次入口「⚡ 让它暴走」。

### 完整版（复制给 Figma AI / 设计工具）

```text
为一个 iOS App 的主页（Forest 首页）设计高保真 UI，画板 402×874（iPhone 16 Pro）。

产品概念：用户用声音种树。音量、音高、拍手、时长、音调变化会实时决定植物形态。
设计方向：深夜森林 / 诗意 / 克制，不要科技感玻璃拟态，不要紫色渐变。

视觉令牌：
- 背景由深到浅：墨夜绿 #0B1512 → 林间绿 #1C3A2C → 琥珀地平线 #3A3120
- 文字：月白 #EDE6D0；次要文字 62% 不透明度
- 强调色（全页唯一）：琥珀 #D9A441，萤火 #F2B84B
- 圆角规则：容器 28、卡片 18、小组件 12、交互胶囊 999
- 字体：圆体（SF Pro Rounded / 苹方），标题 29 bold，CTA 16.5 bold，说明 11

页面层级（自上而下）：
1. 品牌行：种子徽标 + 「声音森林」+ 右侧叶片装饰
2. 中央舞台（空森林）：带三圈声音波纹的种子（150pt）+ 主题句「每一种声音，都可以生长。」+ 副文案「这里还没有植物 · 用你的声音种下第一棵」
3. 底部操作区：琥珀胶囊主按钮「种下一段声音」（56pt 高、带柔光）+ 描边次按钮「⚡ 让它暴走」+ 小字提示「拍手会开花 · 高音会长高」

需要同时给出 4 个状态：
- 空森林：种子 + 波纹（首次进入）
- 已有森林：林中空地面板（28pt 圆角深色玻璃）+ 3 列植物网格 + 「森林里有 N 棵植物」计数胶囊
- 新植物高亮：新植物带琥珀光环 + 悬浮铭牌「新种下 · 植物名」+ Sound DNA 一行（Energy / 频率 / 时长）
- 暴走模式变体：琥珀进度条 + 电光树 + 主次 CTA 对调

氛围元素：3 条雾带（blur）、5 颗漂浮萤火、右上角月光。动画：波纹 3.2s 循环、植物进场 spring、高亮 1.8s 收敛；全部尊重系统「减弱动态」。

不要：紫色/蓝色渐变、三张等宽功能卡、玻璃拟态堆砌、装饰性小圆点、版本号角标。
```

---

## 二、树的表达 · 图像生成提示词

通用约束（每张都加）：
`no text, no watermark, no border, vertical 4:5 composition, painterly digital illustration, luminous line work, soft grain`

### 00 · 概念声音树（主页主视觉）

```text
Stylized concept art, app hero illustration. A single poetic tree in a dark midnight forest: slender luminous trunk, gently asymmetric branching, sparse glowing amber blossoms among deep green canopy, faint sound ripples near the base. Background is a vertical gradient from ink green #0B1512 through forest green #1C3A2C to an amber horizon #3A3120, with soft mist bands and 5 warm fireflies. Lighting: dim moonlight from upper right. Palette: deep greens, moon-white highlights, single amber accent. Painterly digital illustration with luminous line work and soft film grain. Vertical 4:5. No text, no watermark.
```

### 01 · 低音 · 厚土根（RMS 高 → 树干粗壮）

```text
Stylized concept art of a massive low-slung tree rooted in dark earth: very thick tapered trunk, wide spreading root flare, heavy drooping canopy of dense deep-green foliage, moody and grounded. Background: near-black green vertical gradient, faint amber horizon glow, thin mist at ground level. Palette: deepest greens #0E2A1B, umber trunk #1D2B21, sparse amber rim light. Painterly digital illustration, luminous edge highlights, soft grain. Vertical 4:5. No text, no watermark.
```

### 02 · 高音 · 向光枝（频谱高 → 向上生长）

```text
Stylized concept art of an airy slender tree reaching toward light: tall thin trunk, many fine silver-green branches fanning upward like a fountain, tiny pale leaf specks, bright moonlit upper glow. Background: deep green-teal vertical gradient with a pale moon halo at upper right. Palette: silver-green #9DB8A5, pale mint #E4EFDC, deep teal shadows. Painterly digital illustration, luminous and delicate, soft grain. Vertical 4:5. No text, no watermark.
```

### 03 · 节奏 · 拍手花（Onset → 开花）

```text
Stylized concept art of a rhythm-inspired tree: angular branches with slight kinks as if interrupted by claps, amber and coral blossom bursts at branch tips with radiating spark lines. Background: dark green-amber vertical gradient, warm fireflies. Palette: deep green trunk #31412F, amber #E8A24A, coral #D97B52, cream center #F6E3A0. Painterly digital illustration, luminous blossoms, soft grain. Vertical 4:5. No text, no watermark.
```

### 04 · 长音 · 绵长冠（Duration → 树冠丰满）

```text
Stylized concept art of a calm, generous tree with a soft wavy trunk and a huge rounded layered canopy like stacked clouds of sage and teal green, gentle and meditative. Background: deep green vertical gradient, soft mist, faint moon. Palette: sage #457A50, soft light green #7BA46F, dark moss #2C5439. Painterly digital illustration, soft diffuse edges, luminous highlights, film grain. Vertical 4:5. No text, no watermark.
```

### 05 · 旋律 · 蜿蜒脉（Variation → 枝条蜿蜒）

```text
Stylized concept art of a melodic tree with a strong S-curved trunk and ribbon-like winding branches flowing like calligraphy, tiny teal leaf dots tracing the curves, faint flowing light streams around it. Background: deep blue-green vertical gradient with moonlight. Palette: teal #3F6B5B, pale mint #A5CFBD, luminous ribbon highlights #8FD0B8. Painterly digital illustration, elegant curved line work, soft grain. Vertical 4:5. No text, no watermark.
```

### 06 · 暴走 · 电光树（Wild 挑战 → 能量爆裂）

```text
Stylized concept art of a wild lightning tree: jagged zigzag dark branches, amber electric cracks running along the trunk, sparks bursting at branch tips, low energy waves at the base. Background: near-black green with a strong amber glow from above. Palette: charcoal green trunk #1F2620, electric amber #F2B84B, pale gold #FFE3A0. Painterly digital illustration, high contrast, luminous sparks, soft grain. Vertical 4:5. No text, no watermark.
```

---

## 三、SwiftUI 落地实现提示词

```text
在 SwiftUI 项目 EchoForest 中按设计稿重做主页 ForestView（仅此文件，不改其他流程）。

要求：
1. 对外接口保持不变：plantedRecords / highlightedPlantID / onStart / onStartWild / onSelectRecord。
2. 背景：LinearGradient 从 #0B1512 → #1C3A2C → #3A3120，加右上月光 RadialGradient、3 条模糊雾带、5 颗萤火点（轻量动画，不可用高频 TimelineView）。
3. 顶部品牌行：小种子徽标 + 「声音森林」16pt bold。
4. 空森林：种子（150pt）+ 三圈声音波纹（easeOut 3.2s 循环、错峰 1.07s）+ 主题句「每一种声音，\n都可以生长。」29pt bold + 副文案。
5. 已有森林：28pt 圆角深色面板 + 「森林里有 N 棵植物」琥珀胶囊 + LazyVGrid adaptive(minimum:100) 植物网格；新植物高亮时给琥珀边框/光环，并在面板顶部悬浮「新种下 · 名称」+ Sound DNA 一行（Energy / 频率Hz / 时长s）。
6. 底部：56pt 琥珀渐变胶囊主按钮「种下一段声音」（深色文字、柔光阴影）+ 描边次按钮「⚡ 让它暴走」+ 小字「拍手会开花 · 高音会长高」。
7. 所有动画尊重 accessibilityReduceMotion；按钮文字对比度满足 WCAG AA。
8. 用私有 enum 集中管理颜色令牌，注释标注 hex。
```

---

## 四、一键复刻整包提示词

```text
为「Echo Forest / 声音森林」这个用声音种树的 iOS App 完成三件事：
1) 产出一份 Figma 风格主页设计稿（4 个状态 + 设计令牌 + 树的画廊）；
2) 程序化生成 6 幅「声音→树」艺术图（低音厚土根、高音向光枝、节奏拍手花、长音绵长冠、旋律蜿蜒脉、暴走电光树）+ 1 幅主页概念树，SVG 源文件 + PNG 导出；
3) 按设计稿用 SwiftUI 重写主页 ForestView，保持流程接口不变，可编译、自测通过。
设计语言固定为：深夜森林、墨夜绿 #0B1512 / 林间绿 #1C3A2C / 琥珀 #D9A441 / 月白 #EDE6D0、圆角 28/18/12/999、单一强调色、尊重减弱动态。树与声音的映射：RMS→粗细、频谱→方向、Onset→开花、Duration→树冠、Variation→蜿蜒、Wild→闪电。
```
