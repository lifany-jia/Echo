#!/usr/bin/env python3
"""Echo Forest 树的表达 — 程序化 SVG 艺术生成器

生成内容：
  Design/assets/trees/  六种声音表达的概念树 + 主页概念树（1200x1500）
  Design/assets/plants/ 森林网格小植物（240x300）

全部为纯标准库实现，确定性随机种子，可重复生成。
"""

from __future__ import annotations

import math
import random
from pathlib import Path

W, H = 1200, 1500
GROUND_Y = 1365
ROOT_X = 600


def hex2rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(ai + (bi - ai) * t) for ai, bi in zip(a, b))


def rgba(color, alpha):
    r, g, b = hex2rgb(color)
    return f"rgba({r},{g},{b},{alpha})"


def rgb(color):
    r, g, b = hex2rgb(color)
    return f"rgb({r},{g},{b})"


class Art:
    """一幅作品：收集 defs 与元素，最后拼成 SVG 文件。"""

    def __init__(self, w: int, h: int, seed: int):
        self.w, self.h = w, h
        self.rng = random.Random(seed)
        self.defs: list[str] = []
        self.body: list[str] = []
        self._def_ids: set[str] = set()

    # ---------- defs ----------
    def def_id(self, key: str) -> str:
        return key.replace("#", "").replace("(", "").replace(")", "").replace(",", "").replace(" ", "")

    def radial(self, key, stops, cx="50%", cy="50%", r="50%"):
        if key in self._def_ids:
            return key
        self._def_ids.add(key)
        inner = "".join(
            f'<stop offset="{o}" stop-color="{rgb(c)}" stop-opacity="{a}"/>'
            for o, c, a in stops
        )
        self.defs.append(
            f'<radialGradient id="{key}" cx="{cx}" cy="{cy}" r="{r}">{inner}</radialGradient>'
        )
        return key

    def linear(self, key, stops, x1="0", y1="0", x2="0", y2="1"):
        if key in self._def_ids:
            return key
        self._def_ids.add(key)
        inner = "".join(
            f'<stop offset="{o}" stop-color="{rgb(c)}" stop-opacity="{a}"/>'
            for o, c, a in stops
        )
        self.defs.append(
            f'<linearGradient id="{key}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{inner}</linearGradient>'
        )
        return key

    def blur(self, key, std):
        if key in self._def_ids:
            return key
        self._def_ids.add(key)
        self.defs.append(f'<filter id="{key}" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="{std}"/></filter>')
        return key

    def grain(self):
        if "grain" in self._def_ids:
            return
        self._def_ids.add("grain")
        self.defs.append(
            '<filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.7" numOctaves="3" stitchTiles="stitch"/>'
            '<feColorMatrix type="matrix" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 0.5 0"/></filter>'
        )

    # ---------- primitives ----------
    def rect(self, x, y, w, h, fill, opacity=1.0, blur=None, rx=0):
        f = f' filter="url(#{blur})"' if blur else ""
        self.body.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" opacity="{opacity}"{f}/>'
        )

    def circle(self, cx, cy, r, fill, opacity=1.0, blur=None, stroke=None, sw=None):
        f = f' filter="url(#{blur})"' if blur else ""
        s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.body.append(
            f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}" opacity="{opacity}"{s}{f}/>'
        )

    def ellipse(self, cx, cy, rx, ry, fill, opacity=1.0, blur=None, rot=0):
        f = f' filter="url(#{blur})"' if blur else ""
        t = f' transform="rotate({rot} {cx:.1f} {cy:.1f})"' if rot else ""
        self.body.append(
            f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}" opacity="{opacity}"{t}{f}/>'
        )

    def line(self, x1, y1, x2, y2, stroke, width, opacity=1.0, blur=None, cap="round"):
        f = f' filter="url(#{blur})"' if blur else ""
        self.body.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{stroke}" '
            f'stroke-width="{width:.2f}" stroke-linecap="{cap}" opacity="{opacity}"{f}/>'
        )

    def polyline(self, pts, stroke, width, opacity=1.0, blur=None):
        f = f' filter="url(#{blur})"' if blur else ""
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        self.body.append(
            f'<polyline points="{p}" fill="none" stroke="{stroke}" stroke-width="{width:.2f}" '
            f'stroke-linecap="round" stroke-linejoin="round" opacity="{opacity}"{f}/>'
        )

    def tapered(self, pts, w0, w1, color, opacity=1.0, blur=None, glow=None):
        """用逐段变宽折线模拟自然枝条锥度。"""
        n = len(pts) - 1
        if n <= 0:
            return
        for i in range(n):
            t = i / n
            w = w0 + (w1 - w0) * t
            x1, y1 = pts[i]
            x2, y2 = pts[i + 1]
            self.line(x1, y1, x2, y2, color, max(w, 0.4), opacity, blur)
        if glow:
            self.polyline(pts, glow, w0 * 1.7, opacity * 0.35, blur or "soft")

    def glow_dot(self, cx, cy, r, color, alpha=0.8):
        self.circle(cx, cy, r * 3.2, color, alpha * 0.22, "soft")
        self.circle(cx, cy, r, color, alpha)

    # ---------- compositions ----------
    def background(self, top, mid, bottom, moon=None, moon_alpha=0.32):
        sky = self.linear("sky", [(0, top, 1), (0.55, mid, 1), (1, bottom, 1)])
        self.rect(0, 0, self.w, self.h, f"url(#{sky})")
        if moon:
            g = self.radial("moon", [(0, moon, 0.55), (1, moon, 0)], cx="72%", cy="18%", r="52%")
            self.rect(0, 0, self.w, self.h, f"url(#{g})", moon_alpha)

    def ground(self, color, glow_color, rng):
        g = self.radial("ground", [(0, glow_color, 0.9), (1, glow_color, 0)], cx="50%", cy="50%", r="50%")
        self.ellipse(ROOT_X, GROUND_Y + 8, 470, 96, f"url(#{g})", 0.5, "soft")
        self.ellipse(ROOT_X, GROUND_Y + 4, 330, 64, color, 0.9, "soft")
        # 土地纹理小点
        for _ in range(26):
            x = rng.uniform(ROOT_X - 330, ROOT_X + 330)
            y = rng.uniform(GROUND_Y - 34, GROUND_Y + 34)
            self.circle(x, y, rng.uniform(1.2, 3.0), "#0a1510", rng.uniform(0.12, 0.3))

    def mist(self, rng, color="#1c3a2c", n=4):
        blur = self.blur("mistblur", 36)
        for _ in range(n):
            y = rng.uniform(760, 1180)
            ry = rng.uniform(26, 58)
            rx = rng.uniform(330, 560)
            self.ellipse(rng.uniform(240, 960), y, rx, ry, color, rng.uniform(0.10, 0.20), blur)

    def fireflies(self, rng, n=16, color="#f2c96b"):
        for _ in range(n):
            x = rng.uniform(80, self.w - 80)
            y = rng.uniform(90, GROUND_Y - 120)
            r = rng.uniform(1.2, 2.8)
            self.glow_dot(x, y, r, color, rng.uniform(0.35, 0.9))

    def finish(self) -> str:
        self.blur("soft", 10)
        self.grain()
        self.rect(0, 0, self.w, self.h, "white", 0.035, "grain")
        defs = "<defs>" + "".join(self.defs) + "</defs>"
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
            f'viewBox="0 0 {self.w} {self.h}">'
            f"{defs}{''.join(self.body)}</svg>"
        )


# ---------------------------------------------------------------- 枝条

def trace(d: Art, x, y, angle_deg, length, width, depth, cfg, rng):
    """递归画一条枝干（带锥度、弯曲/折角/分叉控制）。"""
    angle = angle_deg
    pts = [(x, y)]
    steps = 7
    seg = length / steps
    cx, cy = x, y
    for s in range(steps):
        drift = cfg.get("curve", 0)
        if cfg.get("kink") and s > 1 and s % cfg["kink"] == 0:
            angle += rng.uniform(-cfg["kink_amp"], cfg["kink_amp"]) * (1 if s % 2 == 0 else -1)
        else:
            angle += rng.uniform(-drift, drift) * (1 if s % 2 == 0 else -1)
        rad = math.radians(angle)
        nx, ny = cx + math.sin(rad) * seg, cy - math.cos(rad) * seg
        pts.append((nx, ny))
        cx, cy = nx, ny

    d.tapered(pts, width, width * cfg.get("taper", 0.34), cfg["branch_color"],
              cfg.get("branch_alpha", 0.92), glow=cfg.get("glow_color"))

    children = cfg.get("children", 2)
    if depth <= 0 or width < cfg.get("min_w", 1.0):
        end_x, end_y = pts[-1]
        return end_x, end_y, True

    spread = cfg.get("spread", 38)
    child_len = length * cfg.get("len_decay", 0.72)
    child_w = width * cfg.get("w_decay", 0.62)
    for i in range(children):
        if rng.random() < cfg.get("child_skip", 0.08):
            continue
        side = 1 if i % 2 == 0 else -1
        base_angle = angle + side * rng.uniform(spread * 0.45, spread) * rng.uniform(0.7, 1.15)
        if cfg.get("bias") is not None:
            base_angle += cfg["bias"] * (1 if i == 0 else -1) * rng.uniform(0.2, 0.55)
        trace(d, cx, cy, base_angle, child_len, child_w, depth - 1, cfg, rng)
    return cx, cy, False


def canopy(d: Art, cx, cy, r, color, rng, alpha=0.9, n=6):
    blur = d.blur("canopy", 22)
    grad = d.radial("canopyG", [(0, color, alpha), (0.7, color, 0.4), (1, color, 0)])
    for _ in range(n):
        ox = rng.uniform(-r * 0.55, r * 0.55)
        oy = rng.uniform(-r * 0.38, r * 0.38)
        rr = r * rng.uniform(0.42, 0.8)
        d.ellipse(cx + ox, cy + oy, rr, rr * rng.uniform(0.82, 1.08), f"url(#{grad})", 0.9, blur)


def blossom(d: Art, x, y, r, petals, center, rng, n_petals=6, glow=True):
    if glow:
        d.circle(x, y, r * 2.4, petals[0], 0.22, "soft")
    for i in range(n_petals):
        a = i * (2 * math.pi / n_petals) + rng.uniform(-0.18, 0.18)
        pr = r * rng.uniform(0.7, 1.05)
        px, py = x + math.cos(a) * pr, y + math.sin(a) * pr
        d.circle(px, py, r * rng.uniform(0.34, 0.5), petals[i % len(petals)], rng.uniform(0.75, 0.95))
    d.circle(x, y, r * 0.34, center, 0.95)
    d.circle(x, y, r * 0.16, "#fdf6dc", 1.0)


def sparks(d: Art, x, y, rng, n=10, color="#f6c453", radius=90):
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(12, radius)
        ex, ey = x + math.cos(a) * dist, y + math.sin(a) * dist
        d.line(x, y, ex, ey, color, rng.uniform(0.7, 1.6), rng.uniform(0.35, 0.8))


# ---------------------------------------------------------------- 六种表达

def art_deep_bass():
    """低音 · 厚土根：粗壮树干、巨大根盘、低垂浓冠。"""
    d = Art(W, H, seed=11)
    d.background("#07100c", "#0e2017", "#16301f", moon="#8f9f74", moon_alpha=0.22)
    d.mist(d.rng, "#122a1e", 5)
    d.ground("#0a1810", "#24452f", d.rng)
    rng = d.rng

    # 根盘
    root_cfg = dict(branch_color="#223228", glow_color=None, curve=5, children=3,
                    spread=58, len_decay=0.86, w_decay=0.58, taper=0.5, min_w=3.0,
                    child_skip=0.12, bias=28, kink=0)
    for side in (-1, 1):
        for i in range(3):
            a = side * rng.uniform(68, 96)
            L = rng.uniform(210, 330)
            trace(d, ROOT_X - side * 46, GROUND_Y + 8, 180 - a * (1 if side < 0 else 1), L, rng.uniform(26, 42), 1, root_cfg, rng)

    # 主干：底部极粗
    trunk = []
    ang = 0
    cx, cy = ROOT_X, GROUND_Y - 6
    for s in range(9):
        ang += rng.uniform(-2.2, 2.2)
        cx += math.sin(math.radians(ang)) * 34
        cy -= math.cos(math.radians(ang)) * 34
        trunk.append((cx, cy))
    d.tapered(trunk, 118, 40, "#1d2b21", 1.0, glow="#3c5b41")
    d.tapered(trunk, 96, 32, "#274033", 0.7, blur="soft")

    # 主枝（低垂浓重）
    cfg = dict(branch_color="#274033", glow_color="#44644a", curve=7, children=2,
               spread=46, len_decay=0.72, w_decay=0.6, taper=0.4, min_w=2.2,
               child_skip=0.06, bias=16, kink=0)
    tips = []
    for side in (-1, 1):
        base = side * rng.uniform(28, 52)
        for _ in range(2):
            ex, ey, term = trace(d, cx, cy, base + rng.uniform(-12, 12), rng.uniform(300, 400),
                                 rng.uniform(34, 44), 3, cfg, rng)
            if term:
                tips.append((ex, ey))
    for _ in range(5):
        ex, ey, term = trace(d, cx, cy - 60, rng.uniform(-34, 34), rng.uniform(210, 320),
                             rng.uniform(22, 30), 2, cfg, rng)
        if term:
            tips.append((ex, ey))

    # 浓冠：大团墨绿 + 暗琥珀底光
    for i, (tx, ty) in enumerate(tips):
        canopy(d, tx, ty - 26, rng.uniform(105, 165), "#123526", rng, 0.92, 7)
    for _ in range(9):
        x = rng.uniform(300, 900)
        y = rng.uniform(300, 640)
        canopy(d, x, y, rng.uniform(70, 130), "#0e2a1b", rng, 0.9, 6)
    for _ in range(7):
        x = rng.uniform(330, 870)
        y = rng.uniform(360, 660)
        canopy(d, x, y, rng.uniform(46, 84), "#1d4a30", rng, 0.85, 5)
    # 枝缝间的光
    for _ in range(6):
        x = rng.uniform(360, 840)
        y = rng.uniform(420, 700)
        d.glow_dot(x, y, rng.uniform(3, 6), "#c7a35e", rng.uniform(0.18, 0.4))
    d.fireflies(rng, 10)
    return d.finish()


def art_high_pitch():
    """高音 · 向光枝：纤细高挑、向上喷涌的银绿枝条。"""
    d = Art(W, H, seed=22)
    d.background("#0a1412", "#122820", "#1b3a28", moon="#d7e6c8", moon_alpha=0.42)
    d.mist(d.rng, "#1a3a28", 4)
    d.ground("#0b1912", "#2b5238", d.rng)
    rng = d.rng

    # 细高主干
    trunk = []
    ang = 0
    cx, cy = ROOT_X, GROUND_Y - 4
    for s in range(12):
        ang += rng.uniform(-1.4, 1.4)
        cx += math.sin(math.radians(ang)) * 26
        cy -= math.cos(math.radians(ang)) * 26
        trunk.append((cx, cy))
    d.tapered(trunk, 34, 7, "#8ba795", 0.95, glow="#bcd4bd")

    cfg = dict(branch_color="#9db8a5", glow_color="#cfe0cc", curve=3, children=2,
               spread=24, len_decay=0.78, w_decay=0.66, taper=0.45, min_w=0.8,
               child_skip=0.03, bias=0, kink=0)
    tips = []
    for depth, count, base_y in ((4, 6, 470), (3, 8, 660), (2, 9, 840)):
        for _ in range(count):
            a = rng.uniform(-34, 34)
            ex, ey, term = trace(d, cx, cy - base_y + rng.uniform(-40, 40), a, rng.uniform(230, 330),
                                 rng.uniform(6, 9), depth, cfg, rng)
            if term:
                tips.append((ex, ey))

    # 轻盈叶簇：小光点
    leaf = d.radial("leaf", [(0, "#e4efdc", 0.9), (1, "#e4efdc", 0)])
    for x, y in tips:
        d.circle(x, y, rng.uniform(5, 9), f"url(#{leaf})", 0.9, "soft")
    for _ in range(46):
        x = rng.uniform(300, 900)
        y = rng.uniform(190, 1050)
        d.circle(x, y, rng.uniform(2.2, 5.4), f"url(#{leaf})", rng.uniform(0.4, 0.85), "soft")
    for _ in range(10):
        d.circle(rng.uniform(330, 870), rng.uniform(220, 900), rng.uniform(1, 2), "#f4f6e6", rng.uniform(0.5, 0.9))
    d.fireflies(rng, 14, "#e8efd0")
    return d.finish()


def art_rhythm():
    """节奏 · 拍手花：带折角的枝干 + 枝头绽开的琥珀花。"""
    d = Art(W, H, seed=33)
    d.background("#0b120e", "#17261c", "#2a2f1d", moon="#e8bd6d", moon_alpha=0.30)
    d.mist(d.rng, "#202f1e", 4)
    d.ground("#101a11", "#3a4a28", d.rng)
    rng = d.rng

    cfg = dict(branch_color="#31412f", glow_color="#5b6b47", curve=2, children=3,
               spread=42, len_decay=0.7, w_decay=0.62, taper=0.42, min_w=1.2,
               child_skip=0.1, bias=10, kink=3, kink_amp=16)
    trunk = []
    ang = 0
    cx, cy = ROOT_X, GROUND_Y - 4
    for s in range(8):
        ang += rng.uniform(-4, 4)
        cx += math.sin(math.radians(ang)) * 30
        cy -= math.cos(math.radians(ang)) * 30
        trunk.append((cx, cy))
    d.tapered(trunk, 52, 16, "#2b3a2a", 1.0, glow="#4b5b3c")

    tips = []
    for _ in range(10):
        a = rng.uniform(-52, 52)
        ex, ey, term = trace(d, cx, cy, a, rng.uniform(200, 330), rng.uniform(12, 18), 3, cfg, rng)
        if term:
            tips.append((ex, ey))

    petals = ["#e8a24a", "#d97b52", "#f2c96b"]
    for i, (x, y) in enumerate(tips):
        r = rng.uniform(12, 20)
        blossom(d, x, y, r, petals, "#f6e3a0", rng, n_petals=6 + i % 3, glow=True)
        sparks(d, x, y, rng, n=7, radius=70)

    # 枝中段的小花苞
    for _ in range(8):
        x = rng.uniform(280, 920)
        y = rng.uniform(600, 1080)
        r = rng.uniform(4, 7)
        blossom(d, x, y, r, petals, "#f6e3a0", rng, n_petals=5, glow=False)
    d.fireflies(rng, 13, "#f2c96b")
    return d.finish()


def art_sustained():
    """长音 · 绵长冠：柔软波状枝 + 层层叠叠的圆润树冠。"""
    d = Art(W, H, seed=44)
    d.background("#0a1512", "#13271f", "#1d3a2a", moon="#b9d2ae", moon_alpha=0.36)
    d.mist(d.rng, "#1c3a2c", 5)
    d.ground("#0c1b13", "#2c5238", d.rng)
    rng = d.rng

    trunk = []
    ang = 0
    cx, cy = ROOT_X, GROUND_Y - 4
    for s in range(9):
        ang += rng.uniform(-3.5, 3.5)
        cx += math.sin(math.radians(ang)) * 30
        cy -= math.cos(math.radians(ang)) * 30
        trunk.append((cx, cy))
    d.tapered(trunk, 62, 18, "#2d4636", 1.0, glow="#4a6b50")

    cfg = dict(branch_color="#3a5844", glow_color="#5d7f60", curve=9, children=3,
               spread=40, len_decay=0.72, w_decay=0.64, taper=0.5, min_w=1.5,
               child_skip=0.05, bias=8, kink=0)
    for _ in range(7):
        a = rng.uniform(-46, 46)
        trace(d, cx, cy, a, rng.uniform(190, 300), rng.uniform(14, 20), 3, cfg, rng)

    # 云冠：大、圆、柔
    for _ in range(16):
        x = rng.uniform(300, 900)
        y = rng.uniform(300, 720)
        canopy(d, x, y, rng.uniform(80, 150), "#2c5439", rng, 0.92, 7)
    for _ in range(12):
        x = rng.uniform(320, 880)
        y = rng.uniform(340, 700)
        canopy(d, x, y, rng.uniform(52, 96), "#457a50", rng, 0.88, 5)
    for _ in range(7):
        x = rng.uniform(360, 840)
        y = rng.uniform(380, 660)
        canopy(d, x, y, rng.uniform(28, 58), "#7ba46f", rng, 0.72, 4)
    d.fireflies(rng, 12, "#cfe0b8")
    return d.finish()


def art_melody():
    """旋律 · 蜿蜒脉：S 形蜿蜒主干，枝条如水墨丝带流动。"""
    d = Art(W, H, seed=55)
    d.background("#0a1513", "#122b25", "#1b3a2c", moon="#a9d0bf", moon_alpha=0.34)
    d.mist(d.rng, "#143528", 5)
    d.ground("#0c1c14", "#28503b", d.rng)
    rng = d.rng

    # 蜿蜒主干：显式 S 曲线
    trunk = []
    cx, cy = ROOT_X, GROUND_Y - 4
    for s in range(14):
        t = s / 13
        sway = math.sin(t * 5.4) * (58 + 34 * t)
        trunk.append((cx + sway, cy - s * 34))
    cx, cy = trunk[-1]
    d.tapered(trunk, 40, 9, "#33564a", 1.0, glow="#4f7a68")

    cfg = dict(branch_color="#3f6b5b", glow_color="#6b9a83", curve=16, children=2,
               spread=30, len_decay=0.74, w_decay=0.66, taper=0.5, min_w=1.0,
               child_skip=0.04, bias=6, kink=0)
    tips = []
    for depth, count in ((3, 5), (2, 7), (1, 8)):
        for _ in range(count):
            a = rng.uniform(-44, 44)
            ex, ey, term = trace(d, cx, cy, a, rng.uniform(170, 300), rng.uniform(7, 11), depth, cfg, rng)
            if term:
                tips.append((ex, ey))

    # 沿枝的点状叶
    leaf = d.radial("leaf", [(0, "#a5cfbd", 0.95), (1, "#a5cfbd", 0)])
    for _ in range(70):
        x = rng.uniform(280, 920)
        y = rng.uniform(260, 1120)
        d.circle(x, y, rng.uniform(2.6, 6.5), f"url(#{leaf})", rng.uniform(0.4, 0.85), "soft")
    # 流动光带（旋律的视觉化）
    for _ in range(5):
        y0 = rng.uniform(480, 1050)
        pts = []
        x = rng.uniform(180, 260)
        for s in range(24):
            pts.append((x, y0 + math.sin(s * 0.55 + rng.uniform(0, 6)) * 46 + s * 9))
            x += rng.uniform(24, 34)
        d.polyline(pts, "#8fd0b8", rng.uniform(0.7, 1.4), rng.uniform(0.14, 0.3), "soft")
    d.fireflies(rng, 15, "#b7e0cb")
    return d.finish()


def art_wild():
    """暴走 · 电光树：锯齿状枝干 + 琥珀闪电裂纹 + 迸射火花。"""
    d = Art(W, H, seed=66)
    d.background("#070b0c", "#101a18", "#1d2417", moon="#f2b84b", moon_alpha=0.30)
    d.mist(d.rng, "#1c2417", 4)
    d.ground("#0d120c", "#3d4220", d.rng)
    rng = d.rng

    cfg = dict(branch_color="#1f2620", glow_color="#7a5b26", curve=0, children=3,
               spread=52, len_decay=0.68, w_decay=0.6, taper=0.35, min_w=1.2,
               child_skip=0.05, bias=16, kink=2, kink_amp=34)
    trunk = []
    ang = 0
    cx, cy = ROOT_X, GROUND_Y - 4
    for s in range(9):
        ang += rng.uniform(-14, 14) if s % 2 == 0 else rng.uniform(-6, 6)
        cx += math.sin(math.radians(ang)) * 30
        cy -= math.cos(math.radians(ang)) * 30
        trunk.append((cx, cy))
    d.tapered(trunk, 70, 14, "#171d17", 1.0, glow="#4a3a18")

    tips = []
    for _ in range(11):
        a = rng.uniform(-60, 60)
        ex, ey, term = trace(d, cx, cy, a, rng.uniform(180, 320), rng.uniform(12, 18), 3, cfg, rng)
        if term:
            tips.append((ex, ey))

    # 闪电裂纹（沿枝干的琥珀线）
    for _ in range(9):
        pts = []
        x, y = rng.uniform(380, 820), rng.uniform(340, 760)
        for s in range(10):
            pts.append((x, y))
            x += rng.uniform(-18, 18)
            y += rng.uniform(26, 52)
        d.polyline(pts, "#f2b84b", rng.uniform(1.6, 3.4), rng.uniform(0.55, 0.9), "soft")
        d.polyline(pts, "#ffe3a0", rng.uniform(0.5, 1.0), rng.uniform(0.8, 1.0))

    # 枝头火花爆裂
    for x, y in tips:
        sparks(d, x, y, rng, n=13, color="#f2c44b", radius=120)
        d.circle(x, y, rng.uniform(5, 9), "#ffe3a0", 0.95, "soft")
        d.circle(x, y, rng.uniform(1.5, 3), "#fff6d8", 1.0)
    for _ in range(24):
        x = rng.uniform(180, 1020)
        y = rng.uniform(220, 1180)
        d.glow_dot(x, y, rng.uniform(1.0, 2.6), "#f2b84b", rng.uniform(0.3, 0.85))
    # 底部能量波
    for i in range(3):
        rr = 150 + i * 80
        d.ellipse(ROOT_X, GROUND_Y + 18, rr, rr * 0.22, "#f2b84b", 0.10 - i * 0.02, "soft")
    return d.finish()


def art_hero():
    """主页概念树：克制、不对称、带着微光的“声音树”。"""
    d = Art(W, H, seed=77)
    d.background("#0b1713", "#12291e", "#3a3120", moon="#e7cf92", moon_alpha=0.30)
    d.mist(d.rng, "#1a3325", 4)
    d.ground("#0d1d14", "#2c5235", d.rng)
    rng = d.rng

    trunk = []
    ang = 0
    cx, cy = ROOT_X, GROUND_Y - 4
    for s in range(11):
        ang += rng.uniform(-2.6, 2.6)
        cx += math.sin(math.radians(ang)) * 30
        cy -= math.cos(math.radians(ang)) * 30
        trunk.append((cx, cy))
    d.tapered(trunk, 56, 10, "#243c2d", 1.0, glow="#4a6b48")

    cfg = dict(branch_color="#2f4d39", glow_color="#5b7d57", curve=6, children=2,
               spread=40, len_decay=0.74, w_decay=0.64, taper=0.45, min_w=1.1,
               child_skip=0.06, bias=14, kink=0)
    tips = []
    for _ in range(6):
        a = rng.uniform(-42, 42)
        ex, ey, term = trace(d, cx, cy, a, rng.uniform(200, 310), rng.uniform(13, 17), 3, cfg, rng)
        if term:
            tips.append((ex, ey))
    # 补几根上探枝
    for _ in range(3):
        ex, ey, term = trace(d, cx, cy - 120, rng.uniform(-24, 24), rng.uniform(170, 250),
                             rng.uniform(6, 9), 2, cfg, rng)
        if term:
            tips.append((ex, ey))

    # 树冠：绿雾 + 稀疏琥珀花
    for i, (tx, ty) in enumerate(tips):
        canopy(d, tx, ty - 24, rng.uniform(74, 118), "#1c4228", rng, 0.92, 6)
    for _ in range(7):
        x = rng.uniform(320, 880)
        y = rng.uniform(360, 700)
        canopy(d, x, y, rng.uniform(44, 86), "#2b5c38", rng, 0.88, 5)
    petals = ["#e8b04c", "#d98a5a", "#f2d489"]
    for i, (x, y) in enumerate(tips[::2]):
        blossom(d, x, y, rng.uniform(10, 16), petals, "#f6e6ae", rng, n_petals=6, glow=True)

    # 声音波纹（主干旁）
    for i in range(3):
        rr = 90 + i * 62
        d.ellipse(ROOT_X + 210, GROUND_Y - 40, rr, rr * 0.32, "#e7cf92", 0.10 - i * 0.025, "soft", rot=8)
    d.fireflies(rng, 15, "#f2cf7a")
    return d.finish()


# ---------------------------------------------------------------- 森林小植物

def plant(seed: int, name_hint: str, cfg_override: dict, canopy_color: str, bloom=False):
    d = Art(240, 300, seed=seed)
    d.rect(0, 0, 240, 300, "#0d1a13")
    rng = d.rng
    d.ellipse(120, 272, 88, 18, "#0a1510", 0.9, "soft")
    cfg = dict(branch_color="#2c4634", glow_color="#517052", curve=4, children=2,
               spread=36, len_decay=0.7, w_decay=0.62, taper=0.4, min_w=0.8,
               child_skip=0.05, bias=8, kink=0)
    cfg.update(cfg_override)
    trunk = []
    cx, cy = 120, 272
    ang = 0
    for s in range(6):
        ang += rng.uniform(-3, 3)
        cx += math.sin(math.radians(ang)) * 16
        cy -= math.cos(math.radians(ang)) * 16
        trunk.append((cx, cy))
    d.tapered(trunk, 20, 4, cfg["branch_color"], 1.0, glow=cfg.get("glow_color"))
    tips = []
    for _ in range(5):
        a = rng.uniform(-40, 40)
        ex, ey, term = trace(d, cx, cy, a, rng.uniform(74, 118), rng.uniform(4.4, 6), 2, cfg, rng)
        if term:
            tips.append((ex, ey))
    for x, y in tips:
        canopy(d, x, y - 10, rng.uniform(20, 32), canopy_color, rng, 0.92, 4)
    for _ in range(2):
        canopy(d, rng.uniform(80, 160), rng.uniform(96, 168), rng.uniform(14, 22), canopy_color, rng, 0.85, 3)
    if bloom:
        for x, y in tips[:2]:
            blossom(d, x, y, rng.uniform(4.5, 6), ["#e8a24a", "#d97b52"], "#f6e3a0", rng, n_petals=5, glow=True)
    for _ in range(4):
        d.glow_dot(rng.uniform(24, 216), rng.uniform(30, 200), rng.uniform(0.8, 1.6), "#e7cf92", rng.uniform(0.3, 0.7))
    return d.finish()


ARTWORKS = {
    "tree-deep-bass": art_deep_bass,
    "tree-high-pitch": art_high_pitch,
    "tree-rhythm": art_rhythm,
    "tree-sustained": art_sustained,
    "tree-melody": art_melody,
    "tree-wild": art_wild,
    "tree-hero": art_hero,
}

PLANTS = {
    "plant-1": dict(seed=1, hint="低语杉", cfg=dict(curve=2, spread=26, len_decay=0.72), canopy="#1c4228"),
    "plant-2": dict(seed=2, hint="风铃藤", cfg=dict(curve=12, spread=44, len_decay=0.68), canopy="#2f5d46", bloom=True),
    "plant-3": dict(seed=3, hint="琥珀花", cfg=dict(curve=4, spread=38, kink=3, kink_amp=12), canopy="#34523a", bloom=True),
    "plant-4": dict(seed=4, hint="夜莺柳", cfg=dict(curve=9, spread=30, len_decay=0.78), canopy="#3f6b5b"),
    "plant-5": dict(seed=5, hint="云冠榆", cfg=dict(curve=5, spread=40, children=3), canopy="#2c5439"),
    "plant-6": dict(seed=6, hint="电光棘", cfg=dict(kink=2, kink_amp=26, spread=50, curve=0), canopy="#3a3a24", bloom=True),
}


def main():
    root = Path(__file__).resolve().parent.parent / "assets"
    trees_dir = root / "trees"
    plants_dir = root / "plants"
    trees_dir.mkdir(parents=True, exist_ok=True)
    plants_dir.mkdir(parents=True, exist_ok=True)
    for name, fn in ARTWORKS.items():
        out = trees_dir / f"{name}.svg"
        out.write_text(fn(), encoding="utf-8")
        print(f"wrote {out.relative_to(root.parent.parent)}")
    for name, spec in PLANTS.items():
        svg = plant(spec["seed"], spec["hint"], spec["cfg"], spec["canopy"], spec.get("bloom", False))
        out = plants_dir / f"{name}.svg"
        out.write_text(svg, encoding="utf-8")
        print(f"wrote {out.relative_to(root.parent.parent)}")


if __name__ == "__main__":
    main()
