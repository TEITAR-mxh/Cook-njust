"""发现 HowToCook 成品图并与本地菜谱关联，生成 content/recipe-images/manifest.json。

数据来源：
- HowToCook 文件树：GitHub git/trees API（api.github.com，raw.githubusercontent 被墙时可用）
- 菜谱 Markdown：cdn.jsdelivr.net/gh 镜像

成品图判定优先级：
1. 与目录同名的 `{菜名}.jpg/.jpeg/.png` → 高置信（approved）
2. 文件名含「成品」→ 高置信（approved）
3. 目录内仅一张图 → 假定为成品（approved）
4. 否则取 Markdown 中第一处 `![...]` 引用 → 需人工核对（candidate）

本脚本只写 manifest.json，不下载图片、不改写 recipe.json。
"""
import json
import re
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen, Request

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content/recipe-images"
RAW = ROOT / "entry/src/main/resources/rawfile"
TREE_CACHE = CONTENT / "howtocook_tree.json"
MANIFEST = CONTENT / "manifest.json"
REVISION = "f6da4528c4cb55fe0fbb5c3db17d76202b9f6ad9"
API_TREE = f"https://api.github.com/repos/Anduin2017/HowToCook/git/trees/{REVISION}?recursive=1"
JSDELIVR = f"https://cdn.jsdelivr.net/gh/Anduin2017/HowToCook@{REVISION}/"
IMG_EXT = (".jpg", ".jpeg", ".png")


def load_tree():
    if not TREE_CACHE.exists():
        req = Request(API_TREE, headers={"Accept": "application/vnd.github+json", "User-Agent": "cook-image-discovery"})
        with urlopen(req, timeout=60) as resp:
            data = resp.read()
        TREE_CACHE.write_bytes(data)
    tree = json.loads(TREE_CACHE.read_text(encoding="utf-8"))
    if tree.get("truncated"):
        raise SystemExit("git tree 被截断，无法可靠枚举")
    return tree["tree"]


def dish_dir_images(tree):
    """返回 {菜名: {'category': .., 'images': [(文件名, 完整路径), ...], 'doc': md路径}}"""
    out = {}
    for item in tree:
        path = item["path"]
        if not path.startswith("dishes/"):
            continue
        parts = path.split("/")
        if len(parts) < 4:
            continue
        category, name, fname = parts[1], parts[2], parts[3]
        if category == "template":
            continue
        entry = out.setdefault(name, {"category": category, "images": [], "doc": None})
        low = fname.lower()
        if low.endswith(IMG_EXT):
            entry["images"].append((fname, path))
        elif low.endswith(".md"):
            entry["doc"] = path
    return out


def first_image_ref(doc_path):
    """取 Markdown 中第一处 ![alt](path) 引用的文件名。"""
    url = JSDELIVR + quote(doc_path, safe="/")
    import time
    last = None
    for attempt in range(3):
        try:
            req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urlopen(req, timeout=30) as resp:
                text = resp.read().decode("utf-8", errors="replace")
            break
        except Exception as exc:  # 网络/限流失败时退回兜底，不阻断整批
            last = exc
            time.sleep(1.5 * (attempt + 1))
    else:
        print(f"  warn: 无法读取 {doc_path}: {last}")
        return None
    for m in re.finditer(r"!\[[^\]]*\]\(([^)]+)\)", text):
        target = m.group(1).strip()
        name = target.rsplit("/", 1)[-1]
        if name.lower().endswith(IMG_EXT):
            return name
    return None


def pick_finished(name, entry):
    """返回 (sourceImage 文件名, status, note)。"""
    imgs = entry["images"]
    by_fname = {fname: path for fname, path in imgs}
    # 1. 与目录同名
    for fname, _ in imgs:
        stem = fname.rsplit(".", 1)[0]
        if stem == name:
            return fname, "approved", "成品图与菜名同名"
    # 2. 文件名含「成品」
    for fname, _ in imgs:
        if "成品" in fname:
            return fname, "approved", "文件名含「成品」，为成图"
    # 3. 单图
    if len(imgs) == 1:
        return imgs[0][0], "approved", "目录内仅一张图，假定为成品"
    # 4. Markdown 首图
    first = first_image_ref(entry["doc"]) if entry["doc"] else None
    if first and first in by_fname:
        return first, "candidate", "按 Markdown 首图推定，需人工核对成品/过程图"
    # 兜底：取首图，标记候选
    return imgs[0][0], "candidate", "无法可靠判定，取首图待人工核对"


def main():
    tree = load_tree()
    recipes = json.loads((RAW / "recipe.json").read_text(encoding="utf-8"))
    dirs = dish_dir_images(tree)

    images = []
    missing = []
    for index, r in enumerate(recipes):
        name = r["name"]
        if name not in dirs:
            continue
        entry = dirs[name]
        if not entry["images"]:
            continue  # HowToCook 有同名 md 但无图，跳过
        fname, status, note = pick_finished(name, entry)
        doc = entry["doc"] or f"dishes/{entry['category']}/{name}/{name}.md"
        images.append({
            "key": f"howtocook-{r['id']}",
            "recipeName": name,
            "legacyIndex": index,
            "sourceRecipeId": r["id"],
            "sourceDocument": doc,
            "sourceImage": f"dishes/{entry['category']}/{name}/{fname}",
            "alt": f"{name}成品参考图",
            "status": status,
            "note": note,
        })
        if status == "candidate":
            missing.append(name)

    manifest = {
        "version": 1,
        "provider": "Anduin2017/HowToCook",
        "revision": REVISION,
        "license": "Unlicense",
        "images": images,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    approved = sum(1 for i in images if i["status"] == "approved")
    print(f"菜谱总数 {len(recipes)}，命中 HowToCook 成品图 {len(images)} 道")
    print(f"  approved: {approved}，candidate(需人工核对): {len(missing)}")
    if missing:
        print("  需核对:", "、".join(missing))


if __name__ == "__main__":
    main()
