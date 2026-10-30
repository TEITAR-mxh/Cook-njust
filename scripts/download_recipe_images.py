"""按菜名从多个图库抓取成品图（相关性过滤 + 全局去重），生成人工审核清单。

用途：为本地 recipe.json 中「无 imageUri」的菜谱补图。
流程：多源搜索 → 标题相关性过滤 → 下载原图 → 内容 MD5 去重 → 生成缩略图 → 写 manifest + review.html。

数据源（按优先级）：
  1. 360 图片搜索  image.so.com/j  —— JSON 接口，稳定，带标题可过滤
  2. Bing 图片搜索                   —— 解析 HTML 中 m 属性（murl + 标题 t）
  （百度 acjson 反爬返回 Forbid spider access；Wikipedia/Wikimedia 在本环境被墙，
    均不可用，故未接入。）

相关性：仅接受「标题包含菜名」的图片；清炒/凉拌等单主料菜可退化为「主料 + 做法线索」匹配。
        剔除广告、素材网、无关图（如把“回锅肉”搜成电线）。
重复：   不同菜谱允许共用同一张图（同类菜图库重复很常见），不做内容去重。
补图：   已有人工删除的图片（文件不存在）会重新抓取；其余跳过续传。

用法：
  python scripts/download_recipe_images.py --limit 15          # 只跑前 15 道
  python scripts/download_recipe_images.py                     # 全量（自动续传/补图）
"""
import argparse
import html
import json
import re
import subprocess
import time
from pathlib import Path
from urllib.parse import quote, urlsplit

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "entry/src/main/resources/rawfile"
RECIPE_JSON = RAW / "recipe.json"
SCRAPED = ROOT / "content/recipe-images/scraped"
ORIG_DIR = SCRAPED / "orig"
PREVIEW_DIR = SCRAPED / "preview"
MANIFEST = SCRAPED / "manifest.json"
REVIEW_HTML = SCRAPED / "review.html"

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
MAX_BYTES = 10 * 1024 * 1024
SLEEP_SECONDS = 1.0


# ── 基础 HTTP ──────────────────────────────────────────────────────────────

def curl_text(url: str, referer: str = "", timeout: int = 30) -> str:
    cmd = ["curl", "-sSL", "-m", str(timeout), "-A", UA]
    if referer:
        cmd += ["-H", f"Referer: {referer}"]
    cmd += [url]
    proc = subprocess.run(cmd, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(f"curl 失败: {proc.stderr.decode('utf-8', errors='replace')[:120]}")
    return proc.stdout.decode("utf-8", errors="replace")


def is_valid_image(path: Path) -> bool:
    """按文件魔数校验是否为可解码图片，剔除 403/HTML 等误下载内容。"""
    try:
        with open(path, "rb") as f:
            head = f.read(16)
    except OSError:
        return False
    if head.startswith(b"\xff\xd8\xff"):           # JPEG
        return True
    if head.startswith(b"\x89PNG\r\n\x1a\n"):      # PNG
        return True
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":  # WEBP
        return True
    if head[:4] == b"GIF8":                        # GIF
        return True
    return False


def curl_binary(url: str, dest: Path, timeout: int = 20) -> bool:
    """下载图片。

    - 部分 CDN 会校验 Referer，先带 Referer 再退回无 Referer。
    - 不少图床 TLS 证书已过期（如 xiangha CDN），curl schannel 会直接拒绝，
      因此加 -k 跳过证书校验；下载后仍会按文件魔数校验内容。
    - --connect-timeout 让死域名快速失败，避免长时间卡住。
    """
    referers = ["https://image.so.com/", ""]
    for referer in referers:
        cmd = ["curl", "-sSL", "-k", "-m", str(timeout), "--connect-timeout", "8",
               "-A", UA, "--compressed", "-o", str(dest), url]
        if referer:
            cmd[1:1] = ["-H", f"Referer: {referer}"]
        proc = subprocess.run(cmd, capture_output=True)
        if proc.returncode != 0 or not dest.exists() or dest.stat().st_size == 0:
            dest.unlink(missing_ok=True)
            continue
        if dest.stat().st_size > MAX_BYTES:
            dest.unlink(missing_ok=True)
            return False
        if not is_valid_image(dest):
            dest.unlink(missing_ok=True)
            continue
        return True
    return False


# ── 搜索源 ────────────────────────────────────────────────────────────────

def normalize(s: str) -> str:
    """去 HTML 标签/实体与空白，用于菜名/标题相关性比较。

    360/Bing 的标题常带 <em> 高亮标签（如 "【<em>菠菜</em>拌<em>粉丝</em>】"），
    不去标签会导致精确匹配全部失败。
    """
    s = re.sub(r"<[^>]+>", "", s or "")
    s = html.unescape(s)
    return re.sub(r"\s+", "", s)


def search_360(dish: str) -> list[tuple[str, str]]:
    """360 图片搜索，返回 [(标题, 图片URL)]。"""
    url = f"https://image.so.com/j?q={quote(dish)}&pn=0&rn=30&src=rp"
    text = curl_text(url, referer="https://image.so.com/")
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return []
    imgs: list[tuple[str, str]] = []
    thumbs: list[tuple[str, str]] = []
    for item in data.get("list", []):
        title = item.get("title") or ""
        img = item.get("img") or ""
        thumb = item.get("thumb") or ""
        if img:
            imgs.append((title, img))
        if thumb and thumb != img:
            thumbs.append((title, thumb))
    # 先试所有原图，原图都失效（域名过期/防盗链）时才退到 360 CDN 缩略图
    return imgs + thumbs


def _unescape_murl(u: str) -> str:
    """Bing 将 murl 中的 \\u0026、斜杠编码为 \\/，还原为可下载 URL。"""
    u = u.replace("\\/", "/")
    return re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), u)


def search_bing(dish: str) -> list[tuple[str, str]]:
    """Bing 图片搜索，解析 m 属性 JSON（含 murl + 标题 t），返回 [(标题, 图片URL)]。"""
    url = f"https://www.bing.com/images/search?q={quote(dish)}&count=35&first=1"
    text = curl_text(url)
    unescaped = html.unescape(text)
    out: list[tuple[str, str]] = []
    for m in re.finditer(r'm="(\{.*?\})"', unescaped):
        try:
            obj = json.loads(m.group(1))
        except json.JSONDecodeError:
            continue
        murl = obj.get("murl", "")
        title = obj.get("t", "")
        if murl:
            out.append((title, _unescape_murl(murl)))
    return out


def search_candidates(dish: str) -> list[tuple[str, str]]:
    """多源搜索，按 URL 去重保序，返回 [(标题, 图片URL)]。"""
    seen: set[str] = set()
    out: list[tuple[str, str]] = []
    for source in (search_360, search_bing):
        try:
            for title, url in source(dish):
                if url in seen:
                    continue
                seen.add(url)
                out.append((title, url))
        except Exception:
            continue
    return out


def is_relevant(title: str, dish: str) -> bool:
    """标题必须包含菜名（规范化后），才算相关，剔除广告/无关图。"""
    dn = normalize(dish)
    tn = normalize(title)
    return len(dn) > 0 and dn in tn


# 做法前缀：去掉后可退化为「主料 + 做法线索」匹配，仅用于清炒/凉拌一类单主料菜。
METHOD_PREFIXES = ("清炒", "素炒", "凉拌", "白灼", "小炒", "清蒸", "炝炒", "爆炒")
DISH_CUES = ("炒", "拌", "蒸", "烧", "炖", "煮", "焖", "菜谱", "食谱", "做法", "出锅", "下饭", "家常", "成品")
NEG_CUES = ("种子", "种植", "农田", "苗", "批发", "价格", "素材", "壁纸", "海报",
            "药物", "胶囊", "影视", "下载", "电商", "生鲜", "盆栽", "产地", "亩")


def core_dish_name(dish: str) -> str:
    """去掉做法前缀，返回主料名；无法拆分时返回原名。"""
    for p in METHOD_PREFIXES:
        if dish.startswith(p) and len(dish) >= len(p) + 2:
            return dish[len(p):]
    return dish


def is_core_relevant(title: str, dish: str) -> bool:
    """宽松匹配：标题含主料 + 做法线索，且不含无关/卖货类词。"""
    core = core_dish_name(dish)
    if core == dish:
        return False
    tn = normalize(title)
    cn = normalize(core)
    if len(cn) < 2 or cn not in tn:
        return False
    if not any(c in tn for c in DISH_CUES):
        return False
    return not any(c in tn for c in NEG_CUES)


# ── 图片处理 ──────────────────────────────────────────────────────────────

def make_preview(src: Path, key: str) -> Path:
    with Image.open(src) as im:
        im = ImageOps.exif_transpose(im).convert("RGB")
        im.thumbnail((640, 640), Image.Resampling.LANCZOS)
        dest = PREVIEW_DIR / f"{key}.jpg"
        im.save(dest, format="JPEG", quality=80, optimize=True)
        return dest


def ext_from_url(url: str) -> str:
    e = urlsplit(url).path.split(".")[-1].lower() if "." in urlsplit(url).path else ""
    return e if e in ("jpg", "jpeg", "png", "webp") else "jpg"


# ── 清单读写 ──────────────────────────────────────────────────────────────

def load_manifest() -> dict[str, dict]:
    if MANIFEST.exists():
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        return {str(e["id"]): e for e in data.get("entries", [])}
    return {}


def save_manifest(entries: list[dict]) -> None:
    payload = {"version": 2, "entries": entries}
    MANIFEST.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_review_html(entries: list[dict]) -> None:
    cards = []
    for e in entries:
        name = html.escape(e["name"])
        pid = e["id"]
        if e.get("status") == "ok":
            img = html.escape(f"preview/{pid}.jpg", quote=True)
            src = html.escape(e.get("source_url", ""), quote=True)
            cards.append(
                f'<figure><img loading="lazy" src="{img}" width="160">'
                f'<figcaption><b>{pid}</b> {name}<br><a href="{src}" target="_blank" style="font-size:10px">{src[:60]}</a></figcaption></figure>'
            )
        else:
            cards.append(
                f'<figure><div style="width:160px;height:120px;background:#eee;display:flex;align-items:center;justify-content:center;color:#999">无图</div>'
                f'<figcaption><b>{pid}</b> {name}<br><span style="color:#c00">{html.escape(e.get("error", ""))}</span></figcaption></figure>'
            )
    html_doc = (
        "<!doctype html><html><head><meta charset='utf-8'><title>菜品图片审核</title>"
        "<style>body{font-family:sans-serif;padding:16px}figure{display:inline-block;margin:8px;text-align:center;vertical-align:top}"
        "img{display:block;object-fit:cover;border:1px solid #ddd}figcaption{max-width:180px;font-size:12px;word-break:break-all}</style>"
        "</head><body><h2>菜品图片审核清单（共 " + str(len(entries)) + " 道）</h2>"
        "<p>状态：已下载=待核对；红字=失败。核对后删除错误图，重跑脚本即可自动补图（不重下正确图）。</p>"
        + "".join(cards) + "</body></html>"
    )
    REVIEW_HTML.write_text(html_doc, encoding="utf-8")


# ── 主流程 ────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=0, help="只处理前 N 道（0=全量）")
    parser.add_argument("--sleep", type=float, default=SLEEP_SECONDS, help="搜索间隔秒数")
    parser.add_argument("--only-error", type=str, default="", help="只重试 error 字段等于该值的失败项（空=补所有失败项）")
    args = parser.parse_args()

    SCRAPED.mkdir(parents=True, exist_ok=True)
    ORIG_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

    recipes = json.loads(RECIPE_JSON.read_text(encoding="utf-8"))
    existing = load_manifest()

    # 只处理无 imageUri 的菜
    todo = [r for r in recipes if not (r.get("imageUri") or "").strip()]
    if args.limit > 0:
        todo = todo[: args.limit]

    ok = fail = skip = 0
    for idx, r in enumerate(todo, 1):
        pid = str(r["id"])
        name = r["name"]
        entry = existing.get(pid, {"id": pid, "name": name, "status": "fail", "source_url": "", "error": ""})

        # 已有有效图（原图+缩略图都在）→ 跳过（续传）。
        # 原图或缩略图任一被人工删除，都视为「用户已否决该图」，重新抓取。
        if entry.get("status") == "ok":
            f = ORIG_DIR / f"{pid}.{entry.get('ext', 'jpg')}"
            p = PREVIEW_DIR / f"{pid}.jpg"
            if f.exists() and p.exists():
                skip += 1
                continue
        # --only-error：仅重试指定错误类型，其余失败项（如「无相关结果」）跳过，避免无效重试。
        # 注意排除 status=="ok"：被人工删除原图/缩略图的 ok 项仍应重新抓取，不能被此判断误跳过。
        if args.only_error and entry.get("status") != "ok" and entry.get("error") != args.only_error:
            skip += 1
            continue
        # 否则（无图/被删/重复）→ 清理旧文件后重新抓取
        for stale in ORIG_DIR.glob(f"{pid}.*"):
            stale.unlink(missing_ok=True)
        (PREVIEW_DIR / f"{pid}.jpg").unlink(missing_ok=True)
        entry.update({"status": "fail", "source_url": "", "error": "", "match": ""})
        try:
            candidates = search_candidates(name)
            relevant = [(t, u) for t, u in candidates if is_relevant(t, name)]
            match_type = "full"
            if not relevant:
                core = core_dish_name(name)
                if core != name:
                    candidates = search_candidates(core)
                    relevant = [(t, u) for t, u in candidates if is_core_relevant(t, name)]
                    match_type = "core"
            if not relevant:
                entry["error"] = "无相关结果"
                raise RuntimeError("no relevant results")
            saved = False
            last_err = ""
            # 允许不同菜共用同一张图（同类菜图库重复很常见），不再按内容去重
            for title, url in relevant[:12]:
                ext = ext_from_url(url)
                orig = ORIG_DIR / f"{pid}.{ext}"
                if curl_binary(url, orig):
                    make_preview(orig, pid)
                    entry.update({"status": "ok", "source_url": url, "ext": ext, "match": match_type})
                    saved = True
                    ok += 1
                    break
                last_err = "下载失败/超时"
            if not saved:
                entry["error"] = last_err or "无可用图片"
                fail += 1
        except Exception as exc:
            entry["error"] = str(exc)[:100]
            fail += 1

        existing[pid] = entry
        print(f"[{idx}/{len(todo)}] {pid} {name} -> {entry['status']} {entry.get('error','')}", flush=True)
        save_manifest(list(existing.values()))
        time.sleep(args.sleep)

    entries = list(existing.values())
    save_manifest(entries)
    write_review_html(entries)
    print(f"\n完成：ok={ok} fail={fail} skip={skip}，清单 entries={len(entries)}")
    print(f"审核页：{REVIEW_HTML}")


if __name__ == "__main__":
    main()
