"""为 recipe.json 补充「菜系」标签（cuisine 字段）。

策略：
1) 经典菜/地域名菜走精确映射（EXACT），保证「宫保鸡丁→川菜」这类不会错；
2) 同族变体（回锅肉/水煮/剁椒/白切…）走受控子串规则（RULES），只匹配明确的菜系技法；
3) 其余默认「家常菜」——保证每道菜都有分类，UI 不必处理空值。

同时生成 cuisine_classics.json（菜系经典页）：菜系简介 + 人工排序的经典菜
（带 0 基数组下标，与 RecipeDBManager 的 id 一致）。

刻意不按「香辣/酸辣/孜然」等口味词泛化，避免把家常菜误标成川菜/湘菜。
运行：python scripts/build_cuisine_tags.py
"""
import io
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECIPE_JSON = ROOT / "entry/src/main/resources/rawfile/recipe.json"
CLASSICS_JSON = ROOT / "entry/src/main/resources/rawfile/cuisine_classics.json"

DEFAULT_CUISINE = "家常菜"

# 菜系页展示顺序：八大菜系在前，地方风味与西式在后
CUISINE_ORDER = [
    "川菜", "粤菜", "湘菜", "鲁菜", "苏菜", "浙菜", "闽菜",
    "东北菜", "京菜", "鄂菜", "客家菜", "西式", "台式", "东南亚菜", "新疆菜",
]

# 菜系简介 + 经典菜人工排序（只用于「菜系经典」页面，不影响卡片标签）
CUISINE_META = {
    "川菜": ("🌶️", "一菜一格，百菜百味",
             "善用花椒与辣椒，鱼香、宫保、水煮、干煸各有章法，麻辣之外也讲究清鲜。"),
    "粤菜": ("🍤", "清鲜为本，原汁原味",
             "重食材本味，白灼、清蒸、煲汤最见功夫，调味克制而不寡淡。"),
    "湘菜": ("🌶", "香辣热烈，酸香开胃",
             "剁椒、腊味与小炒是灵魂，香辣下饭，是家常餐桌的常客。"),
    "鲁菜": ("🍲", "咸鲜醇厚，火候见长",
             "北方菜系之源，葱烧、糖醋、爆炒自成体系，讲究汤与火候。"),
    "苏菜": ("🦀", "清鲜平和，精细雅致",
             "刀工与火候并重，狮子头、糖醋排骨、蟹粉豆腐是代表。"),
    "浙菜": ("🐟", "清鲜脆嫩，清淡爽口",
             "讲究时令与鲜味，杭帮风味清雅，少油少辣。"),
    "闽菜": ("🦪", "鲜香淡雅，汤菜见长",
             "善用海鲜与汤，姜母鸭温润滋补，鲜中带甜。"),
    "东北菜": ("🥘", "量大实在，咸鲜浓香",
             "炖菜与肉菜为主，锅包肉、地三鲜、猪肉炖粉条家喻户晓。"),
    "京菜": ("🦆", "宫廷底蕴，酱香浓郁",
             "烤鸭与京酱肉丝为代表，讲究甜面酱、葱香与薄饼。"),
    "鄂菜": ("🐠", "鱼米之乡，鲜香微辣",
             "武昌鱼是招牌，蒸烧皆宜，江湖鲜味十足。"),
    "客家菜": ("🧂", "咸香醇厚，朴实耐吃",
             "盐焗、梅菜扣肉是客家名片，咸香下饭、保存风味。"),
    "西式": ("🍝", "简约现代，轻食友好",
             "黑椒、香煎、焗烤为主，适合快手西餐与轻食搭配。"),
    "台式": ("🍗", "小吃风味，酥香可口",
             "盐酥鸡等台式经典，外酥里嫩、香气直接。"),
    "东南亚菜": ("🍛", "香料浓郁，酸辣开胃",
             "咖喱与香茅是代表，浓郁开胃、配饭一绝。"),
    "新疆菜": ("🍢", "孜然飘香，肉食豪迈",
             "孜然羊肉、烤羊排是经典，香料与炭火香气突出。"),
}

# 各菜系经典菜排序（名称需与 recipe.json 完全一致；未列出的菜按原顺序补在末尾）
CLASSIC_ORDER = {
    "川菜": ["麻婆豆腐", "宫保鸡丁", "回锅肉", "鱼香肉丝", "水煮肉片", "口水鸡",
             "辣子鸡丁", "蒜泥白肉", "鱼香茄子", "干煸四季豆", "酸菜鱼", "蚂蚁上树"],
    "粤菜": ["白切鸡", "蜜汁叉烧", "清蒸鲈鱼", "白灼大虾", "葱姜炒蟹", "蒜蓉粉丝蒸扇贝",
             "豆豉蒸排骨", "上汤豆苗", "蚝油生菜", "香菇滑鸡", "卤鹅肉", "白灼菜心"],
    "湘菜": ["农家一碗香", "小炒黄牛肉", "家常小炒肉", "手撕包菜",
             "剁椒鲈鱼", "剁椒蒸鸡块", "啤酒鸭"],
    "鲁菜": ["糖醋鲤鱼", "糖醋里脊", "四喜丸子", "油焖大虾",
             "葱爆羊肉", "焦溜肉片", "醋溜白菜", "把子肉"],
    "苏菜": ["狮子头", "清炖狮子头", "红烧狮子头", "糖醋排骨",
             "蟹粉豆腐", "清蒸大闸蟹", "老鸭粉丝汤"],
    "浙菜": ["杭椒牛柳"],
    "闽菜": ["姜母鸭"],
    "东北菜": ["锅包肉", "地三鲜", "溜肉段", "鲶鱼炖茄子", "猪肉炖粉条",
               "尖椒干豆腐", "白肉血肠", "酸菜炖白肉", "酸菜炒粉条"],
    "京菜": ["烤鸭", "京酱肉丝"],
    "鄂菜": ["清蒸武昌鱼", "红烧武昌鱼", "香煎武昌鱼", "糖醋武昌鱼", "剁椒武昌鱼"],
    "客家菜": ["盐焗鸡", "梅菜扣肉", "芋头扣肉", "梅菜蒸鸡", "梅菜扣素菜", "梅菜炒笋干"],
    "西式": ["黑椒牛柳", "香煎牛排家常", "黑椒牛肉", "芝士焗虾", "鸡米花", "奥尔良烤鸡翅"],
    "台式": ["盐酥鸡"],
    "东南亚菜": ["咖喱牛肉", "咖喱牛腩"],
    "新疆菜": ["孜然羊肉", "孜然羊排"],
}

# 菜系页每系最多展示的排名数量（其余菜谱仍在全库中）
RANK_LIMIT = 5

# 精确映射：数据集中的经典菜/地域名菜
EXACT = {
    # 川菜
    "麻婆豆腐": "川菜",
    "鱼香茄子": "川菜",
    "鱼香肉丝": "川菜",
    "宫保鸡丁": "川菜",
    "回锅肉": "川菜",
    "蒜苗回锅肉": "川菜",
    "青椒回锅肉": "川菜",
    "洋葱回锅肉": "川菜",
    "蒜泥白肉": "川菜",
    "口水鸡": "川菜",
    "椒麻鸡": "川菜",
    "藤椒鸡": "川菜",
    "辣子鸡丁": "川菜",
    "辣子鸡煲": "川菜",
    "蚂蚁上树": "川菜",
    "盐煎肉": "川菜",
    "酸菜鱼": "川菜",
    "水煮肉片": "川菜",
    "水煮五花肉": "川菜",
    "水煮草鱼": "川菜",
    "水煮鲶鱼": "川菜",
    "水煮鱼片": "川菜",
    "水煮牛肉": "川菜",
    "水煮牛百叶": "川菜",
    "粉蒸排骨": "川菜",
    "粉蒸鸡肉": "川菜",
    "酸辣土豆丝": "川菜",
    # 粤菜
    "白切鸡": "粤菜",
    "葱油鸡": "粤菜",
    "香菇滑鸡": "粤菜",
    "清蒸鲈鱼": "粤菜",
    "豆豉蒸排骨": "粤菜",
    "豆豉蒸鲈鱼": "粤菜",
    "脆皮鹅": "粤菜",
    "卤鹅肉": "粤菜",
    "葱姜炒蟹": "粤菜",
    "清蒸大虾": "粤菜",
    "清蒸扇贝": "粤菜",
    "粉丝蒸虾": "粤菜",
    "蒜蓉开背虾": "粤菜",
    "蒜蓉粉丝蒸扇贝": "粤菜",
    "上汤豆苗": "粤菜",
    "荷塘月色": "粤菜",
    # 客家菜
    "盐焗鸡": "客家菜",
    "梅菜扣肉": "客家菜",
    "芋头扣肉": "客家菜",
    # 湘菜
    "农家一碗香": "湘菜",
    "家常小炒肉": "湘菜",
    "小炒黄牛肉": "湘菜",
    "手撕包菜": "湘菜",
    "啤酒鸭": "湘菜",
    # 鲁菜
    "糖醋里脊": "鲁菜",
    "焦溜肉片": "鲁菜",
    "四喜丸子": "鲁菜",
    "把子肉": "鲁菜",
    "醋溜白菜": "鲁菜",
    "葱爆羊肉": "鲁菜",
    "糖醋鲤鱼": "鲁菜",
    "油焖大虾": "鲁菜",
    # 苏菜
    "狮子头": "苏菜",
    "红烧狮子头": "苏菜",
    "清炖狮子头": "苏菜",
    "糖醋排骨": "苏菜",
    "蟹粉豆腐": "苏菜",
    "清蒸大闸蟹": "苏菜",
    "老鸭粉丝汤": "苏菜",
    # 浙菜
    "杭椒牛柳": "浙菜",
    # 闽菜
    "姜母鸭": "闽菜",
    # 鄂菜
    "红烧武昌鱼": "鄂菜",
    "清蒸武昌鱼": "鄂菜",
    "剁椒武昌鱼": "鄂菜",
    "香煎武昌鱼": "鄂菜",
    "糖醋武昌鱼": "鄂菜",
    # 京菜
    "京酱肉丝": "京菜",
    "烤鸭": "京菜",
    # 东北菜
    "锅包肉": "东北菜",
    "溜肉段": "东北菜",
    "地三鲜": "东北菜",
    "猪肉炖粉条": "东北菜",
    "白肉血肠": "东北菜",
    "酸菜炖白肉": "东北菜",
    "酸菜炒粉条": "东北菜",
    "鲶鱼炖茄子": "东北菜",
    "尖椒干豆腐": "东北菜",
    # 新疆/西北
    "孜然羊肉": "新疆菜",
    "孜然羊排": "新疆菜",
    # 西式/台式/东南亚
    "奥尔良烤鸡翅": "西式",
    "黑椒牛肉": "西式",
    "黑椒牛柳": "西式",
    "香煎牛排家常": "西式",
    "芝士焗虾": "西式",
    "鸡米花": "西式",
    "盐酥鸡": "台式",
    "咖喱牛肉": "东南亚菜",
    "咖喱牛腩": "东南亚菜",
}

# 受控子串规则：只收录特征明确的菜系技法，按顺序匹配
RULES = [
    # 川菜
    ("回锅肉", "川菜"),
    ("麻婆", "川菜"),
    ("鱼香", "川菜"),
    ("宫保", "川菜"),
    ("蚂蚁上树", "川菜"),
    ("口水鸡", "川菜"),
    ("辣子鸡", "川菜"),
    ("粉蒸", "川菜"),
    ("泡椒", "川菜"),
    ("干煸", "川菜"),
    ("麻辣", "川菜"),
    # 湘菜
    ("剁椒", "湘菜"),
    # 粤菜
    ("白切", "粤菜"),
    ("白灼", "粤菜"),
    ("蚝油", "粤菜"),
    ("叉烧", "粤菜"),
    ("豆豉蒸", "粤菜"),
    # 客家菜
    ("梅菜", "客家菜"),
]


def classify(name: str) -> str:
    if name in EXACT:
        return EXACT[name]
    for keyword, cuisine in RULES:
        if keyword in name:
            return cuisine
    # 水煮蛋/水煮鹌鹑蛋是白煮蛋，不是川菜「水煮」技法，显式排除
    if name.startswith("水煮") and "蛋" not in name:
        return "川菜"
    return DEFAULT_CUISINE


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    data = json.loads(RECIPE_JSON.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit("recipe.json 不是数组")

    counter = Counter()
    by_cuisine = {}
    for index, item in enumerate(data):
        cuisine = classify(item["name"])
        item["cuisine"] = cuisine
        counter[cuisine] += 1
        if cuisine in CUISINE_META:
            by_cuisine.setdefault(cuisine, []).append((index, item))

    RECIPE_JSON.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    # ── 菜系经典页数据：名称 + 0 基数组下标（与 RecipeDBManager 的 id 一致）──
    missing_names = []
    sections = []
    for cuisine in CUISINE_ORDER:
        entries = by_cuisine.get(cuisine, [])
        if not entries:
            continue
        # 微波炉快手菜不属于「经典」，不参与排行（仍在全库中）
        usable = [(i, item) for (i, item) in entries if not item["name"].startswith("微波炉")]
        name_to_index = {}
        for i, item in usable:
            name_to_index.setdefault(item["name"], i)

        ordered = []
        used = set()
        for name in CLASSIC_ORDER.get(cuisine, []):
            index = name_to_index.get(name)
            if index is None:
                missing_names.append(f"{cuisine}/{name}")
                continue
            ordered.append((index, name))
            used.add(index)
        for i, item in usable:
            if i not in used:
                ordered.append((i, item["name"]))
                used.add(i)

        emoji, tagline, description = CUISINE_META[cuisine]
        sections.append({
            "name": cuisine,
            "emoji": emoji,
            "tagline": tagline,
            "description": description,
            "count": len(entries),
            "dishes": [
                {"id": i, "name": name}
                for (i, name) in ordered[:RANK_LIMIT]
            ],
        })

    output = {"cuisines": sections}
    CLASSICS_JSON.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"共 {len(data)} 道菜，菜系分布：")
    for cuisine, count in counter.most_common():
        print(f"  {cuisine:6s} {count}")
    print(f"\n菜系经典页：{len(sections)} 个菜系 → {CLASSICS_JSON.relative_to(ROOT)}")
    if missing_names:
        print("⚠ 未在 recipe.json 中找到的经典菜名：")
        for name in missing_names:
            print(f"  {name}")


if __name__ == "__main__":
    main()
