# AUV 您吃了么

基于 HarmonyOS NEXT (API 22) 的 ArkTS 菜谱应用。用户从冰箱已有食材出发，匹配可做菜谱，查看步骤并进入专注烹饪模式。

---

## 项目信息

| 项目 | 值 |
|---|---|
| 平台 | HarmonyOS NEXT — API 22 |
| 语言 | ArkTS (严格模式) |
| 构建工具 | Hvigor |
| 设备类型 | Phone |
| 版本 | V1.0（开发中） |

---

## 功能清单

### 已交付

| 模块 | 功能描述 | 状态 |
|:---|:---|:---:|
| **工程架构** | **ArkTS API 22 严格模式适配（强类型规范、消除 any、UI Builder 隔离）** | ✅ |
| **视觉体系** | **全面升级 Linear/Vercel 现代风格（格式塔排版、去阴影化、呼吸感间距）** | ✅ |
| 启动页 | 品牌动画（光晕 1200ms → Logo 弹入 880ms → 副标题 660ms → 状态行 500ms；最短停留 2400ms） | ✅ |
| 启动页 | 首次启动隐私同意弹窗（拒绝退出 / 同意进入） | ✅ |
| 启动页 | 离场淡出过渡 | ✅ |
| 法律文档 | 隐私政策 / 用户协议独立页面 | ✅ |
| 冰箱 Tab | 食材多选标签（三类颜色编码），UI 居中对称排版 | ✅ |
| 冰箱 Tab | 随机食材抽取及滚动动画 | ✅ |
| 冰箱 Tab | 严格 / 宽松 / 生存三种搜索模式 | ✅ |
| 菜谱 Tab | 食谱列表（RecipeCard 大/小双模式），**高度自适应修复，间距紧凑** | ✅ |
| 菜谱 Tab | 关键词全文搜索，**系统级原生搜索栏 UI** | ✅ |
| 菜谱 Tab | 卡片点击进入详情弹窗，**带阻尼的系统级半模态 (bindSheet)** | ✅ |
| 发现 Tab | 随机食谱抽取（淡入淡出动画） | ✅ |
| 餐桌 Tab | 收藏网格 + 历史入口 + 设置入口 | ✅ |
| 详情弹窗 | 标签行 / 食材 / 工具 / 步骤三态渲染（Loading / 空态 / 数据） | ✅ |
| 详情弹窗 | selectedStuff 单向透传，新数组引用保障 ArkUI 响应性，**修复嵌套滑动冲突** | ✅ |
| 专注烹饪 | 全屏覆盖 + Swiper 大字翻页 + 屏幕常亮锁 | ✅ |
| 采购清单 | 缺料对比 / 缺料列表输出 / 剪贴板导出 / Toast 反馈 | ✅ |
| 通知 | 毛玻璃 Toast 组件 | ✅ |
| 沉浸式 UI | 透明导航栏 + 安全区适配，**系统原生 BlurStyle 导航栏** | ✅ |
| 持久化 | CookPreferences（收藏 / 历史 / 搜索模式 / 隐私确认状态） | ✅ |
| 数据层 | RecipeRepository 单例（JSON 索引化加载） | ✅ |
| 数据层 | RecipeDBManager（SQLite，含 steps 字段，SHA256 增量导入） | ✅ |
| 设置 | SettingsPage（数据统计 / keepLocalData 开关 / 关于） | ✅ |

### 组件库

| 组件 | 描述 | 状态 |
|:---|:---|:---:|
| `RecipeCard.ets` | 大/小双模式，修复 `.height('100%')` 溢出问题，高度自适应 | ✅ |
| `RecipeDetailSheet.ets` | 底部弹窗，采用原生 `bindSheet` + `nestedScroll`，支持弹簧阻尼动画 | ✅ |
| `CookingFocusView.ets` | 全屏专注覆盖层（Swiper + 屏幕常亮） | ✅ |
| `IngredientTag.ets` | 颜色编码食材标签，对称式布局 | ✅ |
| `ToastView.ets` | 毛玻璃通知 | ✅ |
| `PlateCard.ets` | 3D 盘子效果卡片 | ✅ |
| `RandomPickerButton.ets` | 随机食材抽取触发器 | ✅ |

---

## 已知问题

### P1 — 交互

| # | 问题 | 状态 |
|:---:|:---|:---:|
| 1 | 设置页用户名 / ID / 版本号硬编码 | ❌ 待修复 |
| 2 | ~~搜索后强制切换 Tab，缺少就地视觉反馈~~ | ✅ 已修复 (平滑过渡动画) |

### 合规上架

| 审核项 | 状态 | 风险 |
|:---|:---:|:---:|
| 首次启动隐私同意弹窗 | ✅ | — |
| 隐私政策 / 用户协议页面 | ✅ | — |
| `app.json5` 描述 / 图标 / 标签完整性 | ⚠️ 待核查 | 可能阻塞 |
| AGC 后台数据安全说明 | ❌ 缺失 | 可能阻塞 |

---

## 团队分工

| 编号 | 职责域 | 负责任务 | 协作关系 | 交付物 |
|:---:|:---|:---|:---:|:---|
| 1 | 技术架构 — RDB 与数据稳定性 | 1. ~~methods 类型扩展为 string[]~~ ✅<br>2. 数据迁移 SHA256 哈希校验维护<br>3. 与成员 2 协同处理 DB 层 Bug 修复 | 与 2 协作 | 稳定运行的 RDB 模块；增量导入无异常 |
| 2 | 技术架构 — 前端 Bug 治理 | 1. 修复收藏列表 `.slice(0,6)` 截断，适配 500 条上限（P1）<br>2. 设置页用户信息 / 版本号动态化（P2）<br>3. 与成员 1 协同处理数据层联调 | 与 1 协作 | 收藏列表无截断；设置页无硬编码 |
| 3 | 交互体验与视觉精进 | 1. ~~全局文本重写：去除冗长话术，统一为工业化表述~~ ✅<br>2. ~~Emoji 减负：全局使用系统原生 SymbolGlyph 替代~~ ✅<br>3. ~~参照 Linear 风格重审动效与阴影层级，重构卡片间距体系~~ ✅<br>4. ~~修复搜索后 Tab 跳转，补足就地视觉反馈（P2）~~ ✅ | 独立 | UI 视觉降噪产出物；极致流畅的交互体验 |
| 4 | 内容治理 | 1. 人工 review 全部 steps 内容：校验逻辑正确性，修剪冗余，统一粒度（目标 3–5 步/菜）<br>2. 补齐 foodCatalog emoji 字典，清理 Todo 占位符<br>3. 持续维护 recipe.json 与 RDB 增量数据包 | 独立 | steps 质量审核报告；完整 emoji 字典 |
| 5 | 合规上架（专职） | 1. AGC 后台数据安全说明填报（P1 阻塞项）<br>2. `app.json5` 描述 / 图标 / 标签完整性核查<br>3. 汇总审核材料（截图 / 隐私清单 / 功能说明）<br>4. 提审提交与审核进度跟进 | 独立 | AGC 合规材料完整；审核包通过率 |

---

## Sprint 计划

```text
[Week 1] ✅ 归档
  A  RecipeDBManager 实现 / 表结构 / SHA256 增量导入
  B  RecipeCard 升级 / difficulty·methods 字段渲染
  C  steps 批量生成 / 数据入库验证

[Week 2] ✅ 归档
  A  开机动画时序精调 / 采购清单数据透传修复
  B  专注烹饪全屏覆盖 + 屏幕常亮 / 采购清单 UI 闭环
  C  隐私弹窗验收 / 合规缺口识别

[Week 3] ← 当前阶段  P1 数据封堵 / UI 降噪 / AGC 合规闭环
  1+2  收藏列表截断修复（P1）/ 设置页动态化（P2）/ DB 层联调
  3    ✅ 全局文本去 AI 化 / Emoji 减负 / UI 极简风格重构 / ArkTS 严格模式适配
  4    steps 全量人工 review / emoji 字典补全
  5    AGC 数据安全说明填报 / app.json5 核查 / 审核材料汇总
```

---

## V1.0 交付标准

- **数据层** — RDB 初始化稳定；所有食谱含有效 steps；methods 兼容全部 24 种烹饪方式 ✅
- **架构层** — 符合 HarmonyOS API 22 规范，零 `any`，严格 UI Builder 作用域 ✅
- **列表** — 收藏上限 500 条，无 .slice 截断；RecipeCard 正确渲染 difficulty / methods
- **详情** — 步骤有序可读；采购清单剪贴板导出正常；半模态嵌套滚动丝滑无冲突 ✅
- **设置** — 用户信息与版本号从系统 / Preferences 动态读取
- **合规** — 隐私弹窗 ✅；法律文档页 ✅；AGC 数据安全说明完整；app.json5 通过核查
- **质量** — 全链路回归（选材 → 搜索 → 详情 → 步骤 → 采购清单 → 专注烹饪 → 收藏 → 历史）

---

## 项目结构

```text
entry/src/main/ets/
├── components/
│   ├── RecipeCard.ets           # 大/小双模式卡片（已修复自适应高度）
│   ├── RecipeDetailSheet.ets    # 底部弹窗（原生 bindSheet 适配）
│   ├── CookingFocusView.ets     # 全屏专注覆盖层
│   ├── IngredientTag.ets
│   ├── ToastView.ets
│   ├── PlateCard.ets
│   └── RandomPickerButton.ets
├── constants/
│   ├── AppColors.ets
│   └── DesignSystem.ets         # 全局视觉 Token 控制中心
├── data/
│   ├── RecipeRepository.ets     # JSON 索引化加载
│   ├── RecipeDBManager.ets      # SQLite（steps / SHA256 增量）
│   └── foodCatalog.ets          # 食材厨具目录（emoji 字典，Todo 待清理）
├── model/
│   └── recipe.ets               # RecipeItem / RecipeWithId / SearchMode
├── pages/
│   ├── StartupPage.ets          # 启动动画 + 隐私弹窗
│   ├── LegalDocPage.ets
│   ├── IndexV2.ets              # 主入口 (API 22 严格模式重构版)
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