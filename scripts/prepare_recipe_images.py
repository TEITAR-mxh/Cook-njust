"""Build the pinned HowToCook pilot images, or verify the checked-in assets offline.

Requires Python 3.10+ and Pillow. This tool never rewrites recipe.json.
"""
import argparse
import base64
import hashlib
import io
import json
import subprocess
from pathlib import Path
from urllib.parse import quote

from PIL import Image, ImageOps, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content/recipe-images"
RAW = ROOT / "entry/src/main/resources/rawfile"
OUTPUT = RAW / "recipe_images"
REPORT = CONTENT / "generated.json"
SIZES = {"thumb": (256, 256), "card": (640, 480), "detail": (1280, 1280)}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate existing images without network access")
    args = parser.parse_args()
    manifest = json.loads((CONTENT / "manifest.json").read_text(encoding="utf-8"))
    recipes = json.loads((RAW / "recipe.json").read_text(encoding="utf-8"))
    report = json.loads(REPORT.read_text(encoding="utf-8")) if args.check else {
        "revision": manifest["revision"], "pillowVersion": pillow_version, "assets": []
    }
    if report["revision"] != manifest["revision"]:
        raise ValueError("Generated assets belong to another upstream revision")
    failures = []
    for item in manifest["images"]:
        recipe = recipes[item["legacyIndex"]]
        if recipe["name"] != item["recipeName"] or recipe["id"] != item["sourceRecipeId"]:
            raise ValueError(f"Recipe identity changed: {item['key']}; review migration before generating images")
        if args.check:
            for variant in SIZES:
                relative = f"recipe_images/{item['key']}-{variant}.jpg"
                stored = next(asset for asset in report["assets"] if asset["path"] == relative)
                data = (RAW / relative).read_bytes()
                if digest(data) != stored["sha256"]:
                    raise ValueError(f"Image content changed: {relative}")
                with Image.open(io.BytesIO(data)) as image:
                    image.load()
                    if list(image.size) != stored["size"]:
                        raise ValueError(f"Image dimensions changed: {relative}")
            continue
        try:
            # 通过 GitHub contents API 取 base64（api.github.com 更稳，绕开 raw/jsdelivr 的丢包）
            api_url = ("https://api.github.com/repos/Anduin2017/HowToCook/contents/"
                       + quote(item["sourceImage"], safe="/") + "?ref=" + manifest["revision"])
            proc = subprocess.run(
                ["curl", "-sSL", "--retry", "5", "--retry-all-errors", "--retry-delay", "2",
                 "--max-time", "120", "-H", "Accept: application/vnd.github+json",
                 "-H", "User-Agent: cook-image-discovery", api_url],
                capture_output=True)
            if proc.returncode != 0:
                raise RuntimeError(f"下载失败 {item['sourceImage']}: "
                                   + proc.stderr.decode("utf-8", errors="replace"))
            payload = json.loads(proc.stdout.decode("utf-8"))
            if "content" not in payload:
                raise RuntimeError(f"GitHub API 异常 {item['sourceImage']}: {payload.get('message')}")
            original = base64.b64decode(payload["content"])
            if len(original) > 10 * 1024 * 1024:
                raise ValueError("Source image exceeds the 10 MB pilot limit")
            with Image.open(io.BytesIO(original)) as source:
                # MPO 为多帧 JPEG，取首帧；再统一转 RGB
                if source.format == "MPO":
                    source.seek(0)
                    frame = source.copy()
                    image = ImageOps.exif_transpose(frame).convert("RGB")
                else:
                    image = ImageOps.exif_transpose(source).convert("RGB")
            OUTPUT.mkdir(parents=True, exist_ok=True)
            for variant, size in SIZES.items():
                if variant == "detail":
                    result = image.copy()
                    result.thumbnail(size, Image.Resampling.LANCZOS)
                else:
                    if image.width < size[0] or image.height < size[1]:
                        # 源图小于目标尺寸时不放大平铺，按原比例缩到不超过目标
                        result = image.copy()
                        result.thumbnail(size, Image.Resampling.LANCZOS)
                    else:
                        result = ImageOps.fit(image, size, method=Image.Resampling.LANCZOS)
                relative = f"recipe_images/{item['key']}-{variant}.jpg"
                buffer = io.BytesIO()
                result.save(buffer, format="JPEG", quality=82, optimize=True)
                data = buffer.getvalue()
                (RAW / relative).write_bytes(data)
                report["assets"].append({
                    "path": relative, "size": list(result.size), "bytes": len(data),
                    "sha256": digest(data), "originalSha256": digest(original), "sourceUrl": api_url,
                })
        except Exception as exc:
            failures.append({"key": item["key"], "recipeName": item["recipeName"], "error": str(exc)})
    if not args.check:
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"mode": "check" if args.check else "build", "recipes": len(manifest["images"]),
                      "assets": len(report["assets"]), "bytes": sum(a["bytes"] for a in report["assets"]),
                      "failures": failures}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
