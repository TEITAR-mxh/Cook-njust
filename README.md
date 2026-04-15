# AUV 您吃了么

> 基于 **HarmonyOS NEXT** 的 ArkTS 菜谱应用，帮助用户根据冰箱食材快速发现并学习烹饪食谱。

---

## 项目概览

| 项目 | 信息 |
|---|---|
| 应用名称 | AUV 您吃了么 |
| 平台 | HarmonyOS NEXT（API 22） |
| 语言 | ArkTS |
| 构建工具 | Hvigor |
| 设备类型 | 手机 |
| 当前版本 | V1.0（开发中） |

---

## 已完成功能

### 核心功能

| 模块 | 功能 | 状态 |
|:---|:---|:---:|
| 开机页 | StartupPage 品牌动画（Logo 弹入 + 副标题上滑 + 装饰光晕，最短停留 2400ms） | ✅ |
| 开机页 | 首次启动隐私同意弹窗（含拒绝退出 / 同意进入） | ✅ |
| 开机页 | 离场淡出动画（缩小 + 透明度过渡后跳转首页） | ✅ |
| 法律文档页 | LegalDocPage 隐私政策 / 用户协议页面 | ✅ |
| 冰箱 Tab | 食材 Tag 多选（三类颜色编码） | ✅ |
| 冰箱 Tab | 随机食材抽取按钮 | ✅ |
| 冰箱 Tab | 严格 / 宽松 / 生存三种搜索引擎 | ✅ |
| 菜谱 Tab | 食谱列表（RecipeCard 大/小双模式） | ✅ |
| 菜谱 Tab | 关键词全文搜索 | ✅ |
| 菜谱 Tab | 点击卡片跳转详情弹窗 | ✅ |
| 发现 Tab | 随机食谱抽取（含淡入淡出动画） | ✅ |
| 餐桌 Tab | 收藏网格 + 历史入口 + 设置入口 | ✅ |
| 全局 | RecipeDetailSheet 底部弹窗详情页 | ✅ |
| 全局 | 详情页烹饪步骤区（含 Loading / 空态） | ✅ |
| 全局 | 专注烹饪模式（全屏 Swiper 大字步骤 + 屏幕常亮） | ✅ |
| 全局 | 采购清单（对比已选食材 / 输出缺料 / 剪贴板导出） | ✅ |
| 全局 | Toast 毛玻璃通知组件 | ✅ |
| 全局 | 沉浸式 UI（透明导航栏 + 安全区适配） | ✅ |
| 数据 | CookPreferences 持久化（收藏 / 历史 / 搜索模式 / 隐私协议确认状态） | ✅ |
| 数据 | RecipeRepository 单例（JSON 索引化加载） | ✅ |
| 数据 | RecipeDBManager SQLite 库（含 steps 字段，SHA256 哈希增量导入） | ✅ |
| 设置 | SettingsPage 独立设置页（数据统计 + keepLocalData 开关 + 关于） | ✅ |

### UI 组件库

| 组件 | 说明 | 状态 |
|:---|:---|:---:|
| `RecipeCard.ets` | 大/小双模式食谱卡片，含收藏星标、difficulty 难度标签（三色）、methods 烹饪方式标签 | ✅ |
| `RecipeDetailSheet.ets` | 底部弹窗，含标签行、食材/工具、烹饪步骤、采购清单、专注烹饪入口 | ✅ |
| `CookingFocusView.ets` | 全屏专注烹饪覆盖层，Swiper 翻页 + 大字阅读 + 屏幕常亮 | ✅ |
| `IngredientTag.ets` | 颜色编码食材标签 | ✅ |
| `ToastView.ets` | 毛玻璃风格通知 | ✅ |
| `PlateCard.ets` | 3D 盘子效果卡片 | ✅ |
| `RandomPickerButton.ets` | 随机食材抽取按钮 | ✅ |

---

## 待解决问题

### P1 — 数据与展示问题

- `model/recipe.ets` 中 `methods` 类型仅限 `('炒' | '煎' | '烘' | '炸')[]`（4 种），但 `recipe.json` 实际含 24 种烹饪方式，超出部分在 DB 导入时被过滤丢弃
- 收藏列表被 `.slice(0, 6)` 硬截断，未适配 500 条存储上限
- `foodCatalog` 部分食材存在 `Todo` 占位符，厨具 emoji 缺失

### P2 — 体验

- 设置页用户名 / ID 硬编码（"美食达人" / "cook_2024"），版本号静态写死（"v1.0.0"）
- 搜索后强制切换 Tab，缺乏就地反馈

### 合规上架状态

| 审核要求 | 当前状态 | 风险等级 |
|:---|:---:|:---:|
| 首次启动隐私同意弹窗 | ✅ 已完成 | — |
| 隐私政策 / 用户协议页面 | ✅ 已完成 | — |
| `app.json5` 描述、图标、标签完整性 | ⚠️ 需核查 | 🟡 可能阻塞 |
| AGC 后台数据安全说明 | ❌ 缺失 | 🟡 可能阻塞 |

---

## 团队分工

| 编号 | 成员角色 | 核心职责 | 具体负责任务 | 交付物 |
|:---:|:---|:---|:---|:---|
| 1 | 数据库工程师 | RDB 架构搭建与数据生命周期管理 | 1. 设计并实现 `RecipeDBManager.ets` ✅<br>2. 定义包含 `id`、`name`、`steps` 等字段的表结构（移除 `bv` 字段）✅<br>3. 编写首次启动时 JSON 读取与 DB 写入初始化逻辑（SHA256 哈希增量导入）✅<br>4. 将 `model/recipe.ets` 中 `methods` 类型扩展为 `string[]`（待完成） | 稳定运行的关系型数据库模块及表结构定义 |
| 2 | 内容 / 数据策略研发 | AI 数据清洗与批量生成 | 1. 编写数据处理脚本，在初始数据填充阶段拦截原始 JSON<br>2. 运用 AI 能力为每道菜批量生成 3–5 步真实 `steps`<br>3. 确保内容符合烹饪常识，封装为数组入库 | 包含高质量做菜步骤的初始化数据集 |
| 3 | 鸿蒙前端开发 A | 首页（Index / Home）页面重构 | 1. 升级 `RecipeCard` 组件 ✅<br>2. 新增 `difficulty`（难度）和 `methods`（烹饪方式）UI 元素 ✅<br>3. 保证首页列表对数据库异步查询结果的正确响应与渲染 ✅ | 升级后的首页列表 UI 组件（支持新字段渲染） |
| 4 | 鸿蒙前端开发 B | 详情页（RecipeDetailSheet）重构 | 1. 彻底移除原视频跳转（`bv`）相关 UI 与交互逻辑 ✅<br>2. 重新排版基础信息（`name`、`stuff`、`tags`、`tools` 等）✅<br>3. 页面下方新增「烹饪步骤」区域，接入 DB 查询与三态渲染 ✅ | 清爽、无冗余代码且包含详细步骤的详情页 |
| 5 | QA / 测试工程师 | 数据流转验证、全链路质量保障与应用上架合规优化 | 1. 测试 JSON → RDB 迁移数据完整性（无遗漏、无乱码）<br>2. 抽查生成烹饪步骤是否符合现实逻辑<br>3. 验证前后端数据流转，检查异步查询时 UI 是否闪烁或崩溃<br>4. 负责应用上架 | 数据迁移专项测试报告、端到端 UI 验收报告、应用上架 |

---

## 冲刺路线

```
[Week 1：开发与内容补全]
成员 1 (DB)    ──── [RecipeDBManager] ✅ ── [表结构 & 初始化逻辑] ✅ ── [methods 类型扩展] ──▶
成员 2 (内容)  ──── [steps 批量生成] ───── [数据入库验证] ─────────────────────────────────▶
成员 3 (前端A) ──── [RecipeCard 升级] ✅ ── [难度/方式字段渲染] ✅ ──────────────────────────▶
成员 4 (前端B) ──── [基础信息重排版] ✅ ── [步骤区域接入 DB] ✅ ──────────────────────────────▶
成员 5 (QA)   ──── [测试用例编写] ──────── [迁移测试方案] ──────────────────────────────────▶

[Week 2：联调、测试与提审]
成员 1-4      ──── [功能联调] ─────────── [Bug 修复] ────────────────────────────────────────▶
成员 5 (QA)   ──── [全链路测试] ─────────  [上架素材准备] ──────────────────────────────────▶
成员 5 (QA)   ──── [AGC 后台填报] ──────── [审核提交与跟进] ────────────────────────────────▶
```

## V1.0 完成标准

- **数据层**：RDB 初始化完成 ✅，全部食谱含 3–5 步 `steps`（待内容补全），`bv` 字段彻底移除 ✅，`methods` 类型扩展为 `string[]`（待成员 1 修复）
- **首页**：`RecipeCard` 正确展示 `difficulty` 与 `methods` ✅，无硬编码占位内容
- **详情页**：烹饪步骤有序列表可读 ✅，无视频跳转残留代码 ✅
- **合规基线**：首次启动隐私同意弹窗 ✅，隐私政策 / 用户协议页面均可访问 ✅
- **质量保障**：全链路测试通过（食材选择 → 搜索 → 详情 → 步骤 → 收藏 → 历史）
- **上架准备**：AGC 应用信息、隐私安全问卷填写完整，审核材料齐备

---

## 项目结构

```
entry/src/main/ets/
├── components/         # 可复用 UI 组件
│   ├── RecipeCard.ets          # 大/小双模式食谱卡片（含 difficulty/methods 标签）
│   ├── RecipeDetailSheet.ets   # 底部弹窗（含步骤三态渲染、采购清单、专注烹饪入口）
│   ├── CookingFocusView.ets    # 全屏专注烹饪覆盖层（Swiper 翻页 + 屏幕常亮）
│   ├── IngredientTag.ets       # 颜色编码食材标签
│   ├── ToastView.ets           # 毛玻璃风格通知
│   ├── PlateCard.ets           # 3D 盘子效果卡片
│   └── RandomPickerButton.ets  # 随机食材抽取按钮
├── constants/          # 设计 Token 与主题色
│   └── AppColors.ets
├── data/               # 数据层
│   ├── RecipeRepository.ets    # JSON 索引化加载（内存搜索，从 DB 读取）
│   ├── RecipeDBManager.ets     # SQLite 库（含 steps，SHA256 哈希增量导入）
│   └── foodCatalog.ets
├── model/              # 类型定义
│   └── recipe.ets              # RecipeItem / RecipeWithId / SearchMode（methods 类型待扩展）
├── pages/              # 页面
│   ├── StartupPage.ets         # 开机品牌动画页（含隐私同意弹窗，最短停留 2400ms）
│   ├── LegalDocPage.ets        # 隐私政策 / 用户协议法律文档页
│   ├── IndexV2.ets             # 主入口（当前）
│   ├── SettingsPage.ets        # 独立设置页（数据统计 + 开关 + 关于）
│   ├── FavoritesPage.ets       # 收藏列表
│   └── HistoryPage.ets         # 浏览历史
├── service/            # 业务逻辑服务
│   ├── RecipeSearchService.ets # 严格 / 宽松 / 生存三种搜索算法
│   └── ShoppingListService.ets # 采购清单（缺料对比 + 文本导出）
├── store/              # 持久化
│   └── CookPreferences.ets     # HarmonyOS Preferences 封装（含隐私协议确认状态）
├── utils/              # 工具函数
│   └── IngredientTypeMapper.ets
└── entryability/       # 应用生命周期
    └── EntryAbility.ets        # 沉浸式 UI 初始化
```

---

## 开发环境

- **IDE**：DevEco Studio
- **SDK**：HarmonyOS 6.0.2 (API 22)
- **构建**：`node ./hvigor/hvigor-wrapper.js --mode module -p module=entry@default assembleHap`

---

## 更新说明

### 5. 开机动画延长（2026-04-16）

- 入场动画各阶段时长整体延长约 30%：
  - 背景光晕淡入：900ms → 1200ms
  - Logo 弹入：680ms（延迟 60ms）→ 880ms（延迟 80ms）
  - 副标题上滑：520ms（延迟 300ms）→ 660ms（延迟 420ms）
  - 状态行淡入：380ms（延迟 520ms）→ 500ms（延迟 720ms）
- 新增最短停留时长 **2400ms**：即使 Preferences 读取极快，也会等待入场动画完整播放后再触发离场跳转

### 4. 专注烹饪模式

- 已保留并继续完善 `entry/src/main/ets/components/CookingFocusView.ets`
- 当前已具备：
  - 全屏覆盖展示
  - `Swiper` 左右翻页
  - 大字号步骤阅读
  - 屏幕常亮锁
- 已在 `RecipeDetailSheet.ets` 中加入：
  - `focusModeVisible` 状态
  - `CookingFocusView` 挂载关系
  - "开始烹饪"入口预留

### 3. 详情页采购清单闭环

- 已在 `RecipeDetailSheet.ets` 的食材区域加入"复制缺料"入口
- 已在详情页内部接入局部 `ToastView` 状态
- 当前逻辑：
  - 食材齐全时提示"食材已齐，可以开做了"
  - 存在缺料时复制采购清单到系统剪贴板
  - 成功或失败均通过详情页内 Toast 反馈

### 2. 详情页数据透传

- 已从 `entry/src/main/ets/pages/IndexV2.ets` 向 `entry/src/main/ets/components/RecipeDetailSheet.ets` 单向透传 `selectedStuff`
- 详情页使用：`@Prop selectedStuff: string[] = []`
- 父级透传时使用新数组引用：`this.selectedStuff.concat([])`

### 1. 采购清单能力

- 已新增 `entry/src/main/ets/service/ShoppingListService.ets`
- 当前已具备：
  - 对比"已选食材"与"菜谱所需食材"
  - 输出缺失食材 `missingItems`
  - 输出已匹配食材 `matchedItems`
- 已提供采购清单文本导出模板
