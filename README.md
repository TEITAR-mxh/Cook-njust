# AUV 您吃了么

HarmonyOS NEXT (API 22) 本地菜谱助手应用。从冰箱已有食材出发，智能匹配可做菜谱，支持热量识别、营养评估、个性化推荐与专注烹饪模式。

---

## 项目信息

| 项 | 值 |
|---|---|
| 平台 | HarmonyOS NEXT API 22 (HarmonyOS 6.0.2) |
| 语言 | ArkTS（零 `any`，全类型推断） |
| 包名 | `com.example.cook_njust_project` |
| 版本 | 1.0.1 |
| 构建工具 | Hvigor |
| 入口 | `StartupPage` → `IndexV2` |
| 菜谱规模 | 996 道（去重后） |

---

## 功能

### 冰箱 Tab

- 食材多选标签（三类：肉蛋水产红 / 蔬菜绿 / 碳水辅料黄，共 37 种食材）
- 厨具筛选（炒锅 / 炖锅 / 煮锅 / 蒸锅 / 烤箱 / 电饭煲）
- 三种搜索模式：严格（全匹配）、模糊（任选其一）、生存（菜谱食材 ⊆ 已选食材）
- 24 组食材同义词双向映射（番茄↔西红柿、土豆↔马铃薯 等），三种模式均自动扩展
- 加权随机食材抽取：分类均匀随机 + 类内按菜谱频次加权
- 食材搜索过滤

### 菜谱 Tab

- 全量菜谱列表，大图卡 + 列表小卡双模式
- 关键词全文搜索，搜索历史联想（最多 20 条，聚焦 TextInput 时弹出，支持一键清空）
- 标签筛选（今日推荐 / 减脂餐 / 快手早餐 / 广式 / 川香 / 烘焙 / 汤羹 / 下饭神器 / 宵夜小食）
- 烹饪方式分组筛选（8 类：炒 / 炖烧 / 蒸 / 煮 / 凉拌 / 煎炸 / 烤 / 卤），30+ method 自动映射
- 系统原生半模态详情弹窗（bindSheet）

### 发现 Tab

- 随机推荐 + 浅入淡出动画
- 猜你喜欢：Jaccard 协同过滤（tag + 食材 + 烹饪方式 构建特征集），排除已交互菜谱后 Top 3 推荐
- 右上角「?」快捷入口 → 饮食结构建议页

### 餐桌 Tab

- 今日饮食卡片：100vp 圆环（绿 < 60% / 品牌红 60–90% / 橙 > 90%）+ 三大营养素进度条（蛋白质 / 脂肪 / 碳水，含已摄入/目标数值）+ 内联记录按钮
- 收藏网格（最多 500 条）+ 浏览历史（最近 50 条）
- 历史足迹热力图：Canvas 绘制 12 周 × 7 天，点击格子查看当天菜谱
- 用户资料（昵称 / 头像）
- 主题切换（浅色 / 深色 / 跟随系统）+ 数据管理 + 缓存清理

### 详情弹窗

- 食材用量 → 厨具 → 加入餐桌 → 步骤卡片（编号气泡） → 营养信息
- 人数调节（1–6 人），食材用量实时等比换算（覆盖 20+ 计量单位，支持分数）
- Nutri-Score 营养评级（A–E 五档，Ofcom 简化模型，六项指标）
- 采购清单图片导出：Canvas 绘制 1080×1920vp，三种风格（唯美便签 / 极简白卡 / 牛皮纸），保存至系统相册

### 专注烹饪模式

- 全屏 Swiper 分步浏览，支持从详情弹窗任意步骤直接跳入
- 屏幕常亮锁（`setKeepScreenOn`）

### 热量识别

- **混合识别引擎**：HiAI NPU（麒麟芯片本地加速，置信度 ≥ 0.55） → MindSpore Lite CPU（纯 CPU 兜底，置信度 ≥ 0.20） → 百度云端 API（远程兜底），三级智能降级，模型缺失自动跳过
- MindSpore Lite：内置 MobileNet 类 CNN 模型（224×224 输入），中文标签表
- 识别来源可视化：标签颜色动态变化（本地 NPU 绿 / 本地 CPU 琥珀 / 云端蓝 / 手动灰）
- 饮食记录本地 RDB 持久化，按日期分组查询
- 饮食结构建议页：膳食宝塔 + 三大营养素供能比 + 11 类食物推荐量（《中国居民膳食指南 2022》）

### 每日推荐通知

- 系统级定时推送（`reminderAgentManager`），进程无关
- 动态选菜算法（四级优先级）：
  1. 冰箱食材全匹配
  2. 冰箱食材任意匹配
  3. 精选标签
  4. 全局随机
- 自动排除近 7 天已推荐菜谱
- 点击通知直达菜谱详情（`EntryAbility.onNewWant` → `AppStorage` → `IndexV2`）

---

## 技术架构

```
Pages（10 页）
        ↕
Components（12 个可复用组件）
        ↕
Service（14 个业务模块）     Store（CookPreferences 单例）
        ↕
Data（4 个数据层）           Model（类型定义）
```

### 关键设计决策

| 问题 | 方案 |
|---|---|
| 菜谱 ID 稳定性 | 数组下标作稳定 ID（与 Web 端 Dexie 对齐） |
| 跨页面状态同步 | AppStorage + @StorageProp / @Watch，零轮询 |
| 系统主题监听 | EntryAbility.onConfigurationUpdate → AppStorage('isSystemDarkMode') |
| 收藏/历史并发安全 | CookPreferences Promise 链式单例 |
| 同义词搜索 | 24 组双向映射表，搜索前展开查询词集 |
| 协同过滤推荐 | tag + stuff + methods 特征集 → Jaccard 相似度 |
| 营养评分 | Ofcom Nutri-Score 简化模型：负分（热量/饱和脂肪/糖/钠）− 正分（蛋白质/膳食纤维/蔬菜标签） |
| Builder const 限制 | @State 预计算结果，Builder 内只做取值 |
| 沉浸式适配 | setWindowLayoutFullScreen(true) + StatusBarInset 动态计算 + 底部安全区域占位 |
| 通知跳转桥接 | AppStorage('pendingDailyReminder') 作为系统层→应用层桥接 |
| 图片清单导出 | Canvas 绘制 → componentSnapshot.get() → PixelMap → JPEG → photoAccessHelper.createAsset() |
| 防误触 | TouchDown 记坐标，TouchUp 时位移 > 5vp 则拦截点击 |
| 食物识别降级 | HybridRecognizer 编排三级降级，每级失败/置信度不足自动降落 |
| 烹饪方式分组 | METHOD_TO_GROUP 映射表，30+ method → 8 类用户友好分类 |
| 随机算法 v2 | 分类均匀随机 + 类内菜谱频次加权 |
| 主题颜色 | @StorageProp + ThemeManager 动态颜色，替换硬编码色值 |
| 设置异常回滚 | 开关保存失败回滚 UI；清理数据失败不回滚开关 |
| 详情弹窗卡顿优化 | 打开详情时延迟 300ms 写入历史/刷新推荐，优先保证弹窗渲染 |

---

## 项目结构

```
entry/src/main/
├── ets/
│   ├── components/
│   │   ├── RecipeCard.ets              # 菜谱卡片（大/小双模式）
│   │   ├── RecipeDetailSheet.ets       # 详情弹窗
│   │   ├── CookingFocusView.ets        # 专注烹饪全屏覆盖层
│   │   ├── DailyDietCircleCard.ets     # 今日饮食圆环卡片
│   │   ├── HistoryHeatmap.ets          # 历史热力图（Canvas）
│   │   ├── IngredientTag.ets           # 食材标签
│   │   ├── ToastView.ets               # Toast 通知
│   │   ├── PlateCard.ets               # 菜品卡片
│   │   ├── FavoriteToast.ets           # 收藏提示
│   │   ├── FolderPickerSheet.ets       # 收藏夹选择弹窗
│   │   ├── ExportShoppingListDialog.ets # 采购清单导出（Canvas + 相册）
│   │   └── RandomPickerButton.ets      # 随机食材抽取
│   │
│   ├── constants/
│   │   ├── AppColors.ets               # 品牌色 + 语义色
│   │   └── DesignSystem.ets            # 设计系统常量
│   │
│   ├── config/
│   │   └── CloudApiConfig.ets          # 云端 API 配置
│   │
│   ├── data/
│   │   ├── RecipeRepository.ets        # 菜谱数据单例（rawfile JSON → 内存索引）
│   │   ├── IngredientSynonyms.ets      # 食材同义词库（24 组双向映射）
│   │   ├── DietDatabaseHelper.ets      # 饮食记录 RDB 封装
│   │   ├── RecipeDBManager.ets         # 菜谱 RDB 管理
│   │   └── foodCatalog.ets             # 食材/厨具目录（含 emoji）
│   │
│   ├── model/
│   │   └── recipe.ets                  # 类型定义（RecipeItem / Nutrition / NutriScore 等）
│   │
│   ├── pages/
│   │   ├── StartupPage.ets             # 启动页 + 隐私同意
│   │   ├── IndexV2.ets                 # 主入口（四 Tab 导航）
│   │   ├── CalorieScanPage.ets         # 热量识别页
│   │   ├── DietaryStructurePage.ets    # 饮食结构建议
│   │   ├── LegalDocPage.ets            # 隐私政策 & 用户协议
│   │   ├── SettingsPage.ets            # 设置 & 推荐通知配置
│   │   ├── FavoritesPage.ets           # 收藏列表
│   │   ├── FolderDetailPage.ets        # 收藏夹详情
│   │   ├── CreateFolderPage.ets        # 新建收藏夹
│   │   └── HistoryPage.ets             # 浏览历史 + 热力图
│   │
│   ├── service/
│   │   ├── RecipeSearchService.ets     # 搜索（严格/模糊/生存 + 同义词扩展）
│   │   ├── RecipeRecommendationService.ets  # Jaccard 协同过滤推荐
│   │   ├── NutritionCalculator.ets     # Nutri-Score A-E 评级 + DRI 计算
│   │   ├── IngredientAmountService.ets # 食材用量换算（20+ 单位）
│   │   ├── FoodRecognitionService.ets  # 食物识别服务入口
│   │   ├── HybridRecognizer.ets        # 混合识别编排（HiAI NPU → MindSpore CPU → 云端）
│   │   ├── InferenceEngine.ets         # 推理引擎抽象接口
│   │   ├── HiAIFoodEngine.ets          # HiAI NPU 引擎
│   │   ├── MindSporeFoodEngine.ets     # MindSpore Lite CPU 引擎
│   │   ├── CloudFoodAnalyzer.ets       # 百度云端识别封装
│   │   ├── CategoryGroupingService.ets # 烹饪方式分组服务（30+ method → 8 类）
│   │   ├── ShoppingListService.ets     # 缺料对比 + 剪贴板导出
│   │   ├── DailyRecommendService.ets   # 每日推荐选菜算法
│   │   └── ReminderService.ets         # reminderAgentManager 封装
│   │
│   ├── store/
│   │   └── CookPreferences.ets         # Preferences 持久化
│   │
│   ├── util/
│   │   ├── StatusBarInset.ets          # 安全区高度计算
│   │   └── ThemeManager.ets            # 主题切换管理
│   │
│   ├── utils/
│   │   ├── CalorieCalculator.ets       # 热量计算工具
│   │   ├── PhotoPickerHelper.ets       # 系统图库选图
│   │   ├── ImagePreprocessor.ets       # 图片预处理（缩放+归一化 → CHW Float32Array）
│   │   └── IngredientTypeMapper.ets    # 食材类型映射
│   │
│   └── entryability/
│       └── EntryAbility.ets            # 入口 + 沉浸式 + 主题监听 + 通知跳转
│
└── resources/rawfile/
    ├── recipe.json                     # 996 道菜谱
    ├── food_model.ms                   # MindSpore Lite 模型
    └── food_labels.txt                 # 中文标签表
```

---

## 数据结构

```typescript
interface RecipeItem {
  name: string                         // 菜名
  stuff: string[]                      // 所需食材
  stuffAmount?: Record<string, string> // 食材用量
  tools: string[]                      // 所需厨具
  steps?: string[]                     // 烹饪步骤
  emojis?: string[]                    // 菜品 emoji
  difficulty?: '简单' | '普通' | '困难'
  tags?: string[]                      // 标签
  methods?: string[]                   // 烹饪方式
  imageUri?: string                    // 配图
  nutrition?: RecipeNutrition          // 营养数据
}
```

数组下标为稳定 ID，收藏与历史以 `number[]` 形式存储于 Preferences。

---

## 快速开始

### 环境要求

- DevEco Studio 5.0+
- HarmonyOS SDK API 22

### 构建

`build-profile.json5` 包含签名配置，已加入 `.gitignore`，需手动创建。签名文件（`.p12` / `.p7b` / `.cer`）从 AppGallery Connect → 证书管理 下载。

```bash
# DevEco Studio 直接运行
# 或命令行构建 HAP
node ./hvigor/hvigor-wrapper.js --mode module \
  -p module=entry@default \
  -p product=default \
  assembleHap
```

### 模拟器注意事项

- 首次安装前卸载旧版本，避免应用名称缓存
- 名称显示异常时执行 Run → Clean Project 后重装

---

## 合规

| 项目 | 状态 |
|---|---|
| 首次启动隐私同意弹窗 | 已完成 |
| 隐私政策页 | 已完成 |
| 用户协议页 | 已完成 |
| 权限声明（相册/相机/屏幕常亮/推送） | 已完成 |
| AGC 数据安全填报 | 上架前需完成 |

---

## 贡献者

| 贡献者 | 职责 |
|---|---|
| Ruheluobixieqing | 项目初始化、recipe.json 数据结构、Preferences 存储、主界面骨架、导航框架、收藏/浏览历史 |
| TEITAR-mxh | IndexV2 重构、详情弹窗、启动页/隐私合规、深色模式/主题系统、餐桌页、热量识别混合引擎（HiAI + MindSpore + 云端三级降级）、热力图、Jaccard 推荐算法、Nutri-Score 营养评级、每日通知系统、购物清单导出、烹饪方式分组、随机算法优化、食材搜索、设置页异常回滚、多组件深色主题适配 |
| TTong | RecipeCard 升级（难度/烹饪方式标签）、食材展示、厨具筛选、标签筛选、收藏夹完整功能 |
| Gaoxuan | 菜谱数据录入与补全（996 道去重菜谱）、菜谱步骤内容完善 |
| Fanbo0419 | 包名确认、隐私/条款修订、证书生成、.app 打包上架 |

---

## 许可证

本项目以学习交流为目的开源，菜谱内容整理自公开烹饪知识。

仓库地址：[https://github.com/Ruheluobixieqing/Cook.git](https://github.com/Ruheluobixieqing/Cook.git)

&copy; 2026 AUV您吃了么 项目组 · 南京理工大学
