# AUV 您吃了么：维护接手指南

盘点日期：2026-10-20。代码基线：`c25dfb1`。本文依据本地源码和菜谱检查结果；未进行本轮 HAP 构建、模拟器或真机验收。

## 1. 先理解主链路

项目已经具备四 Tab、收藏夹、今日餐桌、烹饪模式和食物识别等模块。接手阶段优先保证菜谱更新后数据正确、用户记录可用，再扩大内容规模。

```text
entry/src/main/resources/rawfile/recipe.json
  → RecipeDBManager.ensureReady（版本检查、内容哈希、事务导入）
  → cook_recipes.db
  → RecipeRepository.load / getAll / getById
  → RecipeSearchService / RecipeRecommendationService
  → IndexV2 → RecipeDetailSheet → CookingFocusView

CookPreferences：收藏、收藏夹、历史、今日餐桌、推荐历史等
DietDatabaseHelper：饮食记录（独立于菜谱 RDB）
```

### 按维护任务找文件

以下路径相对于 `entry/src/main/ets/`。

| 任务 | 首先查看 | 联动检查 |
|---|---|---|
| 菜谱导入/字段缺失 | `data/RecipeDBManager.ets`、`model/recipe.ets` | `data/RecipeRepository.ets`、rawfile 数据 |
| 冰箱筛选/搜索语义 | `service/RecipeSearchService.ets` | `data/IngredientSynonyms.ets`、`pages/IndexV2.ets` |
| 缺料清单/份量 | `service/ShoppingListService.ets`、`service/IngredientAmountService.ets` | `components/RecipeDetailSheet.ets`、`components/ExportShoppingListDialog.ets` |
| 收藏/历史/餐桌串位 | `store/CookPreferences.ets` | RDB ID、通知携带的菜谱 ID |
| 推荐与随机选菜 | `service/RecipeRecommendationService.ets`、`service/DailyRecommendService.ets` | `pages/IndexV2.ets`、`service/ReminderService.ets` |
| UI/列表性能 | `pages/IndexV2.ets`、`components/RecipeCard.ets` | 数据量、列表构建、图片资源 |
| 识别失败/降级 | `service/HybridRecognizer.ets`、各识别引擎 | `pages/CalorieScanPage.ets`、模型资源 |
| 启动/通知跳转 | `entryability/EntryAbility.ets`、`pages/StartupPage.ets` | `resources/base/profile/main_pages.json`（位于 `ets` 外） |

## 2. 本地初始化与验证

1. 用 DevEco Studio 打开仓库根目录，核对 `oh-package.json5` 和 `hvigor/hvigor-config.json5` 的 `modelVersion: 6.0.2`。
2. 安装支持 HarmonyOS `6.0.2(22)` 的 SDK。当前本地 `build-profile.json5` 中 target/compatible 均为该版本；该文件被 Git 忽略，新克隆需要通过项目设置配置 product、entry 模块和签名。
3. 执行 IDE 依赖同步，确认 `@ohos/hypium` 可解析；选择 `entry/default` 运行并保留构建日志。
4. 运行本地单元测试入口 `entry/src/test/List.test.ets`，其中已注册 `RecipeDataGovernance.test.ets`。设备测试入口在 `entry/src/ohosTest/ets/test/`。
5. 分别验证全新安装与保留用户数据的覆盖升级。只有卸载重装通过，不能证明 ID/数据库升级正确。

### 当前可执行的数据检查

本工作区存在以下脚本，可以在仓库根目录运行：

```powershell
node tools/verify_recipe_bundle.js
```

2026-10-20 实际运行结果（退出码 0）：

| 指标 | 结果 |
|---|---:|
| 菜谱数 | 996 |
| 不同烹饪方式数 | 24 |
| 空步骤菜谱数 | 0 |
| 模拟序列化损坏数 | 0 |

数据 SHA-256：`4656d6f4a5ab483424d96388988f698486a8bda17126cf35160faadfdadf6f44`。

此脚本是 Node 内存模拟，不能验证 HarmonyOS RDB API、升级迁移或界面行为。`.gitignore` 忽略整个 `tools/`，且该脚本当前未被 Git 跟踪，因此新克隆不能依赖它。建议将经过整理的校验器放入受版本管理的 `scripts/`，或只放行需要共享的工具文件。

## 3. 已核实的维护清单

P0：接入或重排外部菜谱前完成。P1：近期功能修正。P2：测量后优化。

### M01 · P0 · ID 来源不一致，数据更新有引用错位风险

- **证据**：`recipe.json` 第一条“清炒西兰花”的 `id` 为 1；`RecipeDBManager.importFromParsed()` 写入的是 `id: i`，第一条实际为 0。`RawRecipeRow` 未声明源 ID。`RecipeRepository.getById()` 根据已加载对象的 ID 查找，但不能改变导入时的编号规则。
- **影响**：重排、插入、删除菜谱后，同一整数可能指向另一道菜；收藏、收藏夹、历史、餐桌和推荐引用都会受影响。
- **处理**：固定现有“下标 → 菜谱”快照，选择不可复用的稳定 ID，保存显式映射与迁移版本。不可只把 `id: i` 改成 `item.id` 后直接发布。
- **验收**：预置收藏/分组/日期历史/餐桌/推荐记录，执行数据重排与覆盖升级后仍指向原菜；删除条目明确显示不可用，不能指向其他菜。检查旧通知中的 ID 兼容或重新发布策略。

### M02 · P0 · 可选字段未贯通数据库

- **证据**：`RecipeItem` 声明 `stuffAmount`、`nutrition`、`imageUri`；RDB 建表、导入和查询还原均未包含这些字段。当前菜谱 JSON 也未检索到这些字段。
- **影响**：已有 UI 支持不能等同于完整数据能力；以后仅向 JSON 增加字段，经过 RDB 加载仍会丢失。
- **处理**：同步修改模型、RawRecipeRow、schema 版本、写入、查询和还原；准备至少一条覆盖全部可选字段的样例。明确营养数据是每份、整道菜还是每 100g。
- **验收**：JSON → 真机 RDB → Repository → 详情，新增字段值一致；旧数据缺字段正常显示；升级后重新导入完整字段。现有 schema 变更会重建菜谱表，须同时检查失败恢复过程。

### M03 · P1 · 模糊与严格匹配语义重叠

- **证据**：`RecipeSearchService.search()` 中 `strict` 和 `loose` 都使用 `selectedStuff.every()`；同时选食材与厨具时，两者均要求二者满足。空条件下 strict 返回全库，loose 返回空。
- **建议契约**：严格＝包含全部已选食材；模糊＝包含任一已选食材；生存＝所有必需食材已备齐。厨具作为独立限制；空条件统一采用明确的默认结果。
- **验收**：构造只含 A、只含 B、同时含 A/B、含 A/B/C 的菜谱，测试三模式、空选料、厨具、同义词组合，并核对 UI 提示。此契约为待实现建议。

### M04 · P1 · 搜索与采购使用不同食材匹配规则

- **证据**：搜索调用 `getIngredientAliases()`；`ShoppingListService.isMatched()` 使用字符串相等或互相包含。
- **影响**：番茄/西红柿可能在搜索中命中、清单中仍缺料；“油”与“蚝油”可能因包含关系被误认为相同。
- **处理**：复用统一食材规范化入口，区分别名、食材类别、可替代关系；不能把类别包含当作等价。
- **验收**：番茄/西红柿、土豆/马铃薯结果一致；油/蚝油、肉/鸡肉不因字符串包含就自动互换。

### M05 · P1 · 份量基准和区间用量需要补齐

- **证据**：详情 `getScaledAmount()` 直接以 `servingCount` 为倍率；模型无原始人数/份数基准。换算服务按开头数值解析，不能完整处理 `10-15ml` 这类范围。
- **影响**：HowToCook 中“一份够 2 人”的原料不能直接视作一人用量；范围可能变成只缩放首个数字的错误字符串。
- **处理**：明确基准份量，结构化存储上下界、单位、原文；倍率＝目标份量/基准份量，无法解析的值保留原文并显示不可换算状态。
- **验收**：2 人基准换算到 4 人时加倍；`10-15ml` 加倍为 `20-30ml`；分数、未知单位、可选原料均有预期结果。

### M06 · P1 · 校验与说明可复现性

- **证据**：现有数据检查脚本不在版本管理内；原 README 引用的 `hvigor/hvigor-wrapper.js` 不存在。已有 Hypium 用例覆盖字符串清洗、ID 分页和哈希稳定性，尚未覆盖上述业务边界。
- **处理**：共享校验器、记录实际工具链和构建方式，增加有价值的搜索/导入/迁移测试。README 中的全文搜索已校正为源码实际的菜名搜索。
- **验收**：新克隆可执行同一套数据检查；测试能拦住 ID 重复、必填字段缺失和错误字段往返。

### M07 · P2 · 大页面和全量列表需要测量后拆分

- **证据**：`IndexV2.ets` 当前 2322 行，承载四 Tab 和大量状态；菜谱列表使用 `ForEach(this.libraryHits, ...)`；Repository 的按 ID 查询为线性 `find()`。
- **处理**：先记录首屏、输入到结果显示、长列表滚动数据；逐步拆分 Tab、评估 `LazyForEach` 与 ID Map。推荐算法是基于菜谱内容的 Jaccard 相似度，说明应与实现一致。
- **验收**：相同设备与数据集比较改动前后，列表滚动/筛选改善且收藏、主题、通知跳转无回归。当前没有实测性能结论。

## 4. 每个维护版本的最小回归

- 冷启动加载 996 道当前菜谱，数据更新后数量与预期一致；离线可搜索和查看步骤。
- 三种搜索模式、厨具和难度筛选符合约定；详情与采购清单的食材判断一致。
- 收藏、新建收藏夹、取消收藏、日期历史、今日餐桌在重启后保留。
- 保留用户数据升级，旧 ID 引用正确；新版数据导入失败能够重试并恢复有效内容。
- 用量、营养、图片缺失时有正常空态；样例完整数据在 RDB 往返后仍完整。
- 从详情进入烹饪模式，退出后屏幕常亮状态恢复；检查主题与底部安全区。
- 通知冷启动/热启动跳转到目标菜；食物识别在模型或网络不可用时按预期降级。

按改动范围选择回归项并记录环境、步骤、预期、实际结果。后续功能规划见 [HowToCook 借鉴与优化路线](HOWTOCOOK_ROADMAP.md)。
