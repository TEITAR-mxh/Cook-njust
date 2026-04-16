# AUV 您吃了么

基于 HarmonyOS NEXT (API 22) 的 ArkTS 菜谱应用。用户从冰箱已有食材出发，匹配可做菜谱，查看步骤并进入专注烹饪模式。

---

## 项目信息

| 项目 | 值 |
|---|---|
| 平台 | HarmonyOS NEXT — API 22 |
| 语言 | ArkTS |
| 构建工具 | Hvigor |
| 设备类型 | Phone |
| 版本 | V1.0（开发中） |

---

## 功能清单

### 已交付

| 模块 | 功能描述 | 状态 |
|:---|:---|:---:|
| 启动页 | 品牌动画（光晕 1200ms → Logo 弹入 880ms → 副标题 660ms → 状态行 500ms；最短停留 2400ms） | ✅ |
| 启动页 | 首次启动隐私同意弹窗（拒绝退出 / 同意进入） | ✅ |
| 启动页 | 离场淡出过渡 | ✅ |
| 法律文档 | 隐私政策 / 用户协议独立页面 | ✅ |
| 冰箱 Tab | 食材多选标签（三类颜色编码） | ✅ |
| 冰箱 Tab | 随机食材抽取 | ✅ |
| 冰箱 Tab | 严格 / 宽松 / 生存三种搜索模式 | ✅ |
| 菜谱 Tab | 食谱列表（RecipeCard 大/小双模式） | ✅ |
| 菜谱 Tab | 关键词全文搜索 | ✅ |
| 菜谱 Tab | 卡片点击进入详情弹窗 | ✅ |
| 发现 Tab | 随机食谱抽取（淡入淡出动画） | ✅ |
| 餐桌 Tab | 收藏网格 + 历史入口 + 设置入口 | ✅ |
| 详情弹窗 | 标签行 / 食材 / 工具 / 步骤三态渲染（Loading / 空态 / 数据） | ✅ |
| 详情弹窗 | selectedStuff 单向透传，新数组引用保障 ArkUI 响应性 | ✅ |
| 专注烹饪 | 全屏覆盖 + Swiper 大字翻页 + 屏幕常亮锁 | ✅ |
| 采购清单 | 缺料对比 / 缺料列表输出 / 剪贴板导出 / Toast 反馈 | ✅ |
| 通知 | 毛玻璃 Toast 组件 | ✅ |
| 沉浸式 UI | 透明导航栏 + 安全区适配 | ✅ |
| 持久化 | CookPreferences（收藏 / 历史 / 搜索模式 / 隐私确认状态） | ✅ |
| 数据层 | RecipeRepository 单例（JSON 索引化加载） | ✅ |
| 数据层 | RecipeDBManager（SQLite，含 steps 字段，SHA256 增量导入） | ✅ |
| 数据层 | methods 字段扩展为 `string[]`，兼容 recipe.json 全部 24 种烹饪方式 | ✅ |
| 设置 | SettingsPage（数据统计 / keepLocalData 开关 / 关于） | ✅ |

### 组件库

| 组件 | 描述 | 状态 |
|:---|:---|:---:|
| `RecipeCard.ets` | 大/小双模式，含收藏星标、difficulty 三色标签、methods 标签 | ✅ |
| `RecipeDetailSheet.ets` | 底部弹窗，含步骤区、采购清单、专注烹饪入口 | ✅ |
| `CookingFocusView.ets` | 全屏专注覆盖层（Swiper + 屏幕常亮） | ✅ |
| `IngredientTag.ets` | 颜色编码食材标签 | ✅ |
| `ToastView.ets` | 毛玻璃通知 | ✅ |
| `PlateCard.ets` | 3D 盘子效果卡片 | ✅ |
| `RandomPickerButton.ets` | 随机食材抽取触发器 | ✅ |

---

## 已知问题

### P1 — 数据

| # | 问题 | 文件 | 状态 |
|:---:|:---|:---|:---:|
| 1 | ~~methods 类型限制为 4 种枚举，导致 DB 导入过滤丢弃~~ | `model/recipe.ets` | ✅ 已修复 |
| 2 | 收藏列表 `.slice(0, 6)` 硬截断，未适配 500 条上限 | `FavoritesPage.ets` | ❌ 待修复 |
| 3 | `foodCatalog.ets` 存在 `Todo` 占位符，厨具 emoji 缺失 | `data/foodCatalog.ets` | ❌ 待修复 |

### P2 — 交互

| # | 问题 | 状态 |
|:---:|:---|:---:|
| 1 | 设置页用户名 / ID / 版本号硬编码 | ❌ 待修复 |
| 2 | 搜索后强制切换 Tab，缺少就地视觉反馈 | ❌ 待修复 |

### 合规上架

| 审核项 | 状态 | 风险 |
|:---|:---:|:---:|
| 首次启动隐私同意弹窗 | ✅ | — |
| 隐私政策 / 用户协议页面 | ✅ | — |
| `app.json5` 描述 / 图标 / 标签完整性 | ⚠️ 待核查 | 可能阻塞 |
| AGC 后台数据安全说明 | ❌ 缺失 | 可能阻塞 |

---

## 团队分工

| 席位 | 职责域 | 负责任务 | 交付物 |
|:---:|:---|:---|:---|
| A | 技术架构与稳定性 | 1. ~~methods 类型扩展为 string[]~~ ✅<br>2. 修复收藏列表 .slice(0,6) 截断（P1）<br>3. 设置页用户信息 / 版本号动态化（P2）<br>4. 数据迁移 SHA256 哈希校验维护 | 稳定运行的 RDB 模块；设置页无硬编码 |
| B | 交互体验与视觉精进 | 1. 全局文本重写：去除冗长话术，统一为工业化表述<br>2. Emoji 减负：全局使用率降至 ≤30%，仅保留导航级功能性图标<br>3. 参照 Linear 风格重审动效与阴影层级<br>4. 修复搜索后 Tab 跳转，补足就地视觉反馈（P2） | UI 视觉降噪产出物；Tab 跳转平顺性验收 |
| C | 内容治理与合规 | 1. 人工 review 全部 steps 内容：校验逻辑正确性，修剪冗余，统一粒度（目标 3–5 步/菜）<br>2. 补齐 foodCatalog emoji 字典，清理 Todo 占位符<br>3. AGC 后台数据安全说明填报<br>4. app.json5 合规核查 + 审核材料准备 | steps 质量审核报告；AGC 合规材料；提审包 |

---

## Sprint 计划

```
[Week 1] ✅ 归档
  A  RecipeDBManager 实现 / 表结构 / SHA256 增量导入
  B  RecipeCard 升级 / difficulty·methods 字段渲染
  C  steps 批量生成 / 数据入库验证

[Week 2] ✅ 归档
  A  开机动画时序精调 / 采购清单数据透传修复
  B  专注烹饪全屏覆盖 + 屏幕常亮 / 采购清单 UI 闭环
  C  隐私弹窗验收 / 合规缺口识别

[Week 3] ← 当前阶段  P1 数据封堵 / UI 降噪 / AGC 合规闭环
  A  收藏列表截断修复（P1）/ 设置页动态化（P2）
  B  全局文本去 AI 化 / Emoji 减负 / Tab 跳转反馈修复
  C  steps 全量人工 review / emoji 字典补全 / AGC 提审材料
```

---

## V1.0 交付标准

- **数据层** — RDB 初始化稳定；所有食谱含有效 steps；methods 兼容全部 24 种烹饪方式 ✅
- **列表** — 收藏上限 500 条，无 .slice 截断；RecipeCard 正确渲染 difficulty / methods
- **详情** — 步骤有序可读；采购清单剪贴板导出正常；无废弃字段残留
- **设置** — 用户信息与版本号从系统 / Preferences 动态读取
- **合规** — 隐私弹窗 ✅；法律文档页 ✅；AGC 数据安全说明完整；app.json5 通过核查
- **质量** — 全链路回归（选材 → 搜索 → 详情 → 步骤 → 采购清单 → 专注烹饪 → 收藏 → 历史）

---

## 项目结构

```
entry/src/main/ets/
├── components/
│   ├── RecipeCard.ets           # 大/小双模式卡片（difficulty / methods 标签）
│   ├── RecipeDetailSheet.ets    # 底部弹窗（步骤三态 / 采购清单 / 专注烹饪）
│   ├── CookingFocusView.ets     # 全屏专注覆盖层
│   ├── IngredientTag.ets
│   ├── ToastView.ets
│   ├── PlateCard.ets
│   └── RandomPickerButton.ets
├── constants/
│   └── AppColors.ets
├── data/
│   ├── RecipeRepository.ets     # JSON 索引化加载
│   ├── RecipeDBManager.ets      # SQLite（steps / SHA256 增量）
│   └── foodCatalog.ets          # 食材厨具目录（emoji 字典，Todo 待清理）
├── model/
│   └── recipe.ets               # RecipeItem / RecipeWithId / SearchMode
├── pages/
│   ├── StartupPage.ets          # 启动动画 + 隐私弹窗
│   ├── LegalDocPage.ets
│   ├── IndexV2.ets              # 主入口
│   ├── SettingsPage.ets         # 设置（用户信息待动态化）
│   ├── FavoritesPage.ets        # 收藏列表（截断问题待修复）
│   └── HistoryPage.ets
├── service/
│   ├── RecipeSearchService.ets  # 严格 / 宽松 / 生存搜索
│   └── ShoppingListService.ets  # 缺料对比 + 剪贴板导出
├── store/
│   └── CookPreferences.ets
├── utils/
│   └── IngredientTypeMapper.ets
└── entryability/
    └── EntryAbility.ets         # 沉浸式 UI 初始化
```

---

## 开发环境

| 项 | 值 |
|---|---|
| IDE | DevEco Studio |
| SDK | HarmonyOS 6.0.2 (API 22) |
| 构建命令 | `node ./hvigor/hvigor-wrapper.js --mode module -p module=entry@default assembleHap` |
