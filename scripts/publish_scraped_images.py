"""将 scraped 抓取的菜品图发布为 app 随包资源。

读取 scraped/manifest.json 中 status=ok 的图片，为每张生成
rawfile/recipe_images/{pid}-{thumb|card|detail}.jpg 三个变体，
并把 recipe.json 中对应菜的 imageUri 设为 pid，使 app 能显示。

用法：
  python scripts/publish_scraped_images.py            # 全量发布
  python scripts/publish_scraped_images.py --dry-run  # 只统计，不写文件
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SCRAPED = ROOT / "content/recipe-images/scraped"
ORIG = SCRAPED / "orig"
RAW = ROOT / "entry/src/main/resources/rawfile"
OUTPUT = RAW / "recipe_images"
RECIPE_JSON = RAW / "recipe.json"

# detail 最长边已从 1280 收紧到 1024（详情图实际展示 220vp 高，1024 仍覆盖 3x 屏）
SIZES = {"thumb": (256, 256), "card": (640, 480), "detail": (1024, 1024)}

# JPEG 质量，与 scripts/recompress_recipe_images.py 的 QUALITY 保持一致
JPEG_QUALITY = 75


def find_orig(pid: str) -> Path | None:
    for ext in ("jpg", "jpeg", "png"):
        f = ORIG / f"{pid}.{ext}"
        if f.exists():
            return f
    return None


def make_variant(im: Image.Image, variant: str, size: tuple[int, int]) -> Image.Image:
    if variant == "detail":
        out = im.copy()
        out.thumbnail(size, Image.Resampling.LANCZOS)
        return out
    if im.width < size[0] or im.height < size[1]:
        out = im.copy()
        out.thumbnail(size, Image.Resampling.LANCZOS)
        return out
    return ImageOps.fit(im, size, Image.Resampling.LANCZOS)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="只统计，不写文件")
    args = parser.parse_args()

    manifest = json.loads((SCRAPED / "manifest.json").read_text(encoding="utf-8"))
    recipes = json.loads(RECIPE_JSON.read_text(encoding="utf-8"))
    by_id = {str(r["id"]): r for r in recipes}

    entries = manifest.get("entries", [])
    OUTPUT.mkdir(parents=True, exist_ok=True)

    published = 0
    skipped_missing = 0
    for e in entries:
        if e.get("status") != "ok":
            continue
        pid = str(e["id"])
        src = find_orig(pid)
        if src is None:
            skipped_missing += 1
            continue
        if not args.dry_run:
            try:
                with Image.open(src) as im:
                    im = ImageOps.exif_transpose(im).convert("RGB")
                    for variant, size in SIZES.items():
                        out = make_variant(im, variant, size)
                        dest = OUTPUT / f"{pid}-{variant}.jpg"
                        out.save(dest, format="JPEG", quality=JPEG_QUALITY, optimize=True)
            except Exception as exc:
                print(f"[skip] {pid}: {exc}", file=sys.stderr)
                continue
        if pid in by_id:
            by_id[pid]["imageUri"] = pid
            published += 1

    if not args.dry_run:
        RECIPE_JSON.write_text(
            json.dumps(recipes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    print(f"published={published} skipped_missing={skipped_missing}")


if __name__ == "__main__":
    main()
