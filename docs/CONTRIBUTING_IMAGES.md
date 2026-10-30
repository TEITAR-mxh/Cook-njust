# 菜品配图贡献指南

App 的菜谱图片是**随包离线资源**，对应 `entry/src/main/resources/rawfile/recipe_images/`。
没有成品图的菜谱在详情页会显示中性占位图，并提供「帮助补充成品图」入口。

## 目前状态

- 菜谱总数：996
- 已有配图：601（每道菜 3 档：`-thumb` 256×256、`-card` 640×480、`-detail` 长边 ≤1024）
- 仍缺图：395（长尾家常菜为主，公开图库很难按菜名精确命中）

## 贡献方式一：提交 Issue（最简单）

1. 在 App 内打开缺图菜谱的详情页，点击「帮助补充成品图 ›」。
2. 点「复制提交信息」，再点「去 GitHub 提交」。
3. 在 Issue 编辑框中粘贴信息、拖入图片，提交。

维护者会核对菜名与成品是否一致、来源是否可授权，通过后由脚本生成三档图片并合入。

## 贡献方式二：直接提 PR

图片必须关联稳定菜谱 ID，不能按文件名排序对号入座。

1. 把原图放到 `content/recipe-images/scraped/orig/{recipeId}.jpg`
   （也支持 `.jpeg` / `.png`）。
2. 在 `content/recipe-images/scraped/manifest.json` 的 `entries` 中补充一条：

   ```json
   {
     "id": "30",
     "name": "清炒茭白",
     "status": "ok",
     "source_url": "本人拍摄",
     "error": "",
     "ext": "jpg",
     "match": "manual"
   }
   ```

3. 运行发布脚本，生成三档图片并写入 `recipe.json`：

   ```bash
   python scripts/publish_scraped_images.py --dry-run   # 先确认数量
   python scripts/publish_scraped_images.py             # 正式生成
   ```

4. 提交改动的文件：原图、`manifest.json`、`recipe_images/` 下新增的 3 个变体、`recipe.json`。

## 图片要求

- 一张**成品照**，不要原料图、过程图、拼图或多图拼接。
- 横向 4:3 或 1:1，长边不少于 800px；不要放大低清图。
- 无水印、无文字贴纸、无夸张滤镜；主体居中，方便 4:3 裁切。
- 必须本人拍摄或已获得授权，并在 Issue/PR 中注明来源。

## 自动抓取（维护者用）

`scripts/download_recipe_images.py` 会按菜名从 360/Bing 图片搜索抓取候选，做标题相关性过滤、
内容去重和人工审核页（`content/recipe-images/scraped/review.html`）：

```bash
python scripts/download_recipe_images.py --limit 15
python scripts/download_recipe_images.py --only-error "下载失败/超时"
```

抓取图存在版权不确定性，仅作为**人工核对后的补充**；核对不通过时应删除原图并重跑脚本。
优先使用团队实拍或明确授权的图片。
