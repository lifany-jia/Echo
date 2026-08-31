#!/usr/bin/env python3
"""Echo Forest App Icon 生成器

以 Design/assets/trees/tree-hero.svg（主页概念声音树）为源，裁出正方形
1024x1024 的 App Icon 构图：完整保留墨夜绿渐变、右上月光、雾带、树根声音
波纹、琥珀花与萤火，输出 SVG 源文件与多尺寸 PNG。

构图（与设计语言一致）：
  - 源图 1200x1500，裁切 y ∈ [240, 1440]（正方形 1200x1200）
  - 缩放到 1024x1024：scale = 1024/1200，translate = -240 * scale
  - 树冠上沿与地面柔光都保留，主体居中、满高构图

渲染：macOS qlmanage（WebKit）负责 SVG -> PNG，无需第三方依赖。
"""

from __future__ import annotations

import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "trees" / "tree-hero.svg"
OUT_DIR = ROOT / "AppIcon"

CANVAS = 1024
CROP_TOP = 240
CROP_SIZE = 1200  # 1200x1200 正方形裁切区域
SCALE = CANVAS / CROP_SIZE
TY = -CROP_TOP * SCALE

SIZES = (1024, 512, 256)


def build_svg() -> str:
    src = SOURCE.read_text(encoding="utf-8")
    defs = re.search(r"<defs>.*?</defs>", src, re.S)
    if defs is None:
        raise RuntimeError("tree-hero.svg: <defs> not found")
    body = src[defs.end() :].rsplit("</svg>", 1)[0]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" '
        f'height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">'
        f"{defs.group(0)}"
        f'<g transform="translate(0,{TY:.4f}) scale({SCALE:.6f})">'
        f"{body}"
        f"</g></svg>"
    )


def render(svg_path: Path, tmp: Path) -> Path:
    subprocess.run(
        ["qlmanage", "-t", "-s", str(CANVAS), "-o", str(tmp), str(svg_path)],
        check=True,
        capture_output=True,
    )
    out = tmp / f"{svg_path.name}.png"
    if not out.exists():
        raise RuntimeError("qlmanage did not produce a PNG")
    return out


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    svg_path = OUT_DIR / "app-icon.svg"
    svg_path.write_text(build_svg(), encoding="utf-8")
    print(f"wrote {svg_path.relative_to(ROOT.parent)}")

    with tempfile.TemporaryDirectory() as td:
        master = render(svg_path, Path(td))
        for size in SIZES:
            dest = OUT_DIR / f"app-icon-{size}.png"
            if size == CANVAS:
                shutil.copyfile(master, dest)
            else:
                subprocess.run(["sips", "-z", str(size), str(size), str(master), "--out", str(dest)],
                               check=True, capture_output=True)
            print(f"wrote {dest.relative_to(ROOT.parent)}")


if __name__ == "__main__":
    main()
