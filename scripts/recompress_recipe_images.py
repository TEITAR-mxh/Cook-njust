"""原地重压缩 recipe_images 以减小随包体积，不改动 recipe.json。

对 rawfile/recipe_images/ 下所有 *.jpg 统一降质量重编码：
- JPEG 质量 82 → 75（肉眼几乎无差，体积约减 30%）
- detail 变体最长边 1280 → 1024（详情图实际展示 220vp 高，1024 仍覆盖 3x 屏）

用法：
  python scripts/recompress_recipe_images.py            # 原地重压缩
  python scripts/recompress_recipe_images.py --dry-run  # 只统计，不写文件
"""
import argparse
import os
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "entry/src/main/resources/rawfile/recipe_images"

QUALITY = 75
DETAIL_MAX = 1024


def recompress(path: Path) -> tuple[int, int]:
    """重编码单张图，返回 (before, after) 字节数。"""
    before = path.stat().st_size
    with Image.open(path) as im:
        im = ImageOps.exif_transpose(im).convert("RGB")
        if "-detail.jpg" in path.name:
            im.thumbnail((DETAIL_MAX, DETAIL_MAX), Image.Resampling.LANCZOS)
        tmp = path.with_suffix(".recomp.jpg")
        im.save(tmp, format="JPEG", quality=QUALITY, optimize=True)
    tmp.replace(path)
    return before, path.stat().st_size


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="只统计，不写文件")
    args = parser.parse_args()

    files = sorted(OUTPUT.glob("*.jpg"))
    saved = 0
    total_before = 0
    total_after = 0
    for i, f in enumerate(files, 1):
        before = f.stat().st_size
        total_before += before
        if args.dry_run:
            # 干跑不重编码，仅按经验系数估算（detail 另计尺寸缩减）
            factor = 0.7
            if "-detail.jpg" in f.name:
                factor *= 0.64
            total_after += int(before * factor)
            saved += before - int(before * factor)
            continue
        b, a = recompress(f)
        saved += b - a
        total_after += a
        if i % 300 == 0:
            print(f"{i}/{len(files)} saved={saved / 1048576:.1f}MB", file=sys.stderr)

    print(f"files={len(files)} before={total_before / 1048576:.1f}MB "
          f"after={total_after / 1048576:.1f}MB saved={saved / 1048576:.1f}MB")


if __name__ == "__main__":
    main()
