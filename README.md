# AUV 您吃了么

> 基于 HarmonyOS NEXT (API 22) ArkTS 开发的本地菜谱助手应用。用户从冰箱已有食材出发，智能匹配可做菜谱，支持热量识别、营养评价、个性化推荐与专注烹饪模式。

---

## 项目概览

| 项 | 值 |
|---|---|
| 平台 | HarmonyOS NEXT — API 22 (HarmonyOS 6.0.2) |
| 语言 | ArkTS 严格模式（零 `any`，强类型规范） |
| 包名 | `com.example.cook` |
| 版本 | 1.0.0 |
| 构建工具 | Hvigor |
| 设备类型 | Phone |
| 入口页面 | `StartupPage` → `IndexV2` |

---

## 功能特性

### 冰箱 Tab — 智能匹配
- 食材多选标签（肉蛋水产 / 新鲜蔬菜 / 碳水辅料三类颜色编码）
- 厨具筛选（炒锅 / 蒸锅 / 烤箱等）
- 三种搜索模式：**严格**（全部食材都有）/ **模糊**（任一食材匹配）/ **生存**（仅用所选食材）
- **食材同义词库**：24 组同义词（番茄↔西红柿、土豆↔马铃薯等），三种模式均自动扩展，告别因叫法差异搜不到菜
- 随机食材抽取动画

### 菜谱 Tab — 浏览探索
- 全量菜谱列表，RecipeCard 大/小双模式
- 关键词全文搜索，含**搜索历史联想**（最多 20 条，TextInput 聚焦时弹出，支持一键清空）
- 标签筛选（今日推荐 / 减脂餐 / 快手早餐 / 广式 / 川香 / 烘焙 / 汤羹）
- 点击卡片打开系统原生半模态详情弹窗（`bindSheet`）

### 发现 Tab — 随机推荐
- 随机抽取菜谱，淡入淡出切换动画
- **猜你喜欢**：基于 Jaccard 协同过滤算法，对比历史浏览 + 收藏记录推荐相似菜谱，单列展示 Top 3，标题行显示推荐数量角标
- 右上角「?」快捷入口，跳转**饮食结构建议页**

### 餐桌 Tab — 个人中心
- **今日饮食卡片**：圆环进度展示今日热量 / 蛋白质 / 脂肪 / 碳水摄入；下方内联今日菜单列表（加入餐桌的菜谱、营养汇总、个性化饮食建议），替代原独立的「今日餐桌」区块
- 收藏网格（最多 500 条，按收藏时间排序）
- 浏览历史（最近 50 条）
- **历史足迹热力图**：Canvas 绘制近 12 周浏览热力格子，点击格子查看当天浏览的菜谱列表
- 用户资料（昵称 / 头像 Emoji / 相册图片）
- 主题切换（浅色 / 深色 / 跟随系统）
- 数据管理（保留本地数据开关 / 缓存清理）

### 详情弹窗
- **步骤卡片**：编号气泡（品牌色圆形）+ 步骤文本，交替底色区分行；点击任一步骤直接跳入对应步骤的专注模式
- **内容顺序**：食材用量 → 烹饪工具 → 加入餐桌按钮 → 步骤卡片 → 营养信息
- **加入今日餐桌**：通栏按钮，居中显示；已加入时变为品牌色填充态（"已加入今日餐桌"）
- **食材用量归一化**：人数调节器（1–6 人），食材用量实时等比换算（支持克 / 毫升 / 个 / 勺 / 块等 20+ 中英文单位）
- **Nutri-Score 营养评级**（A–E 五档，参考 Ofcom 模型）
- **营养成分卡片**：热量 / 蛋白质 / 脂肪 / 碳水 / 膳食纤维 / 钠 六项数据
- 收藏切换（即时同步，使用 `FAVORITE_ACTIVE` 色）

### 专注烹饪模式
- 全屏 Swiper 分步骤浏览，支持从详情弹窗任意步骤直接跳入
- 屏幕常亮锁（`runningLock`），防止操作中途熄屏

### 热量识别与饮食记录
- **拍照 / 图库识别**：调用相机或系统图库选取食物照片，本地初步识别 + 云端 AI 二次分析
- **每日饮食记录**：本地 RDB 持久化，按日期分组查询
- **饮食结构建议页**：中国居民平衡膳食宝塔、三大营养素供能比可视化、11 类食物推荐摄入量（依据《中国居民膳食指南（2022）》，纯静态展示）

### 每日推荐通知
- **系统级定时推送**：通过 `reminderAgentManager` 设置每日闹钟，在用户设定时间触发后台服务
- **动态选菜算法**：冰箱食材全匹配 → 冰箱食材任意匹配 → 精选标签 → 全局随机，自动排除近 7 天已推荐菜谱
- **两种推荐偏好**：「冰箱优先」（结合用户已选食材）/ 「随机精选」（从有标签菜谱中随机）
- **点击通知直达**：通知携带菜谱 ID，点击后跳转主界面并自动打开对应菜谱详情
- **设置入口**：SettingsPage 新增推送开关、时间选择器（TimePickerDialog）、偏好切换

### 合规
- 首次启动隐私同意弹窗（拒绝退出 / 同意进入）
- 独立隐私政策页面（符合《个人信息保护法》）
- 独立用户协议页面（具备合同效力条款）

---

## 技术架构

### 分层设计

```
┌─────────────────────────────────────────┐
│               Pages / UI                │  ArkUI 声明式 UI
├─────────────────────────────────────────┤
│             Components                  │  可复用 UI 组件
├────────────────────┬────────────────────┤
│      Service       │      Store         │  业务逻辑 / 持久化
├────────────────────┼────────────────────┤
│        Data        │      Model         │  数据加载 / 类型定义
└─────────────────────────────────────────┘
```

### 核心设计决策

| 问题 | 方案 |
|------|------|
| 菜谱 ID 稳定性 | 数组下标作为稳定 ID（与 Web 端 Dexie 对齐） |
| 跨页面主题同步 | `AppStorage` + `@StorageProp` / `@Watch`，零轮询；`onPageShow` 同步读取 AppStorage 消除异步闪烁 |
| 系统主题监听 | `EntryAbility.onConfigurationUpdate` 写入 `AppStorage('isSystemDarkMode')` |
| 收藏/历史并发安全 | `CookPreferences` Promise 链式单例，防止竞态写入 |
| ArkUI 响应性 | `@State` 赋值使用深拷贝，避免引用未变导致 UI 不刷新 |
| 同义词搜索 | `IngredientSynonyms` 24 组双向映射，搜索前扩展为等价词集合 |
| 协同过滤推荐 | 基于 tag + stuff + methods 构建特征集，Jaccard 相似度排序 |
| 营养评分 | 简化版 Ofcom Nutri-Score：负分（热量/饱和脂肪/糖/钠）减正分（蛋白质/膳食纤维/蔬菜标签） |
| Builder 限制规避 | ArkTS Builder lambda 内禁止 `const`，改用 `@State` 预计算或直接调用方法 |
| 沉浸式底栏 | `setWindowLayoutFullScreen(true)` + 透明导航栏 + 安全区适配 |
| 每日推荐调度 | `reminderAgentManager.publishReminder(ReminderRequestAlarm)` 系统级闹钟，`wantAgent` 指向 `EntryAbility`，不依赖应用进程 |
| 通知跳转菜谱 | 系统通知点击后 `EntryAbility.handleRecommendIntent` 写 `AppStorage('pendingDailyReminder')`，`IndexV2.onPageShow` 读取后调用 `DailyRecommendService` 选菜并打开详情 |

---

## 项目结构

```
entry/src/main/ets/
├── components/
│   ├── RecipeCard.ets              # 菜谱卡片（大/小双模式；小卡片收藏按钮 in-flow，不遮挡文字）
│   ├── RecipeDetailSheet.ets       # 底部详情弹窗（编号气泡步骤卡片 / 通栏餐桌按钮 / 用量换算 / 营养卡片）
│   ├── CookingFocusView.ets        # 全屏专注烹饪覆盖层（Swiper + 屏幕常亮锁，支持 initialIndex）
│   ├── DailyDietCircleCard.ets     # 今日饮食圆环卡片（热量 + 三大营养素进度）
│   ├── HistoryHeatmap.ets          # 历史足迹热力图（Canvas 12×7，点击格子查看当日菜谱）
│   ├── IngredientTag.ets           # 颜色编码食材标签
│   ├── ToastView.ets               # 毛玻璃 Toast 通知
│   ├── PlateCard.ets               # 3D 盘子效果卡片
│   ├── FavoriteToast.ets           # 收藏成功提示
│   ├── FolderPickerSheet.ets       # 收藏夹选择弹窗
│   └── RandomPickerButton.ets      # 随机食材抽取触发器
│
├── constants/
│   └── AppColors.ets               # 品牌色 + 深色适配色 + FAVORITE_ACTIVE + ThemeManager 工具类
│
├── data/
│   ├── RecipeRepository.ets        # 菜谱数据单例（rawfile JSON 索引化加载）
│   ├── IngredientSynonyms.ets      # 食材同义词库（24 组，双向查找）
│   ├── DietDatabaseHelper.ets      # 每日饮食记录 RDB 封装
│   └── foodCatalog.ets             # 食材 / 厨具目录（含 emoji 映射）
│
├── model/
│   └── recipe.ets                  # RecipeItem / RecipeWithId / RecipeNutrition / NutriScore 等类型定义
│
├── pages/
│   ├── StartupPage.ets             # 启动页（品牌动画 + 隐私同意对话框）
│   ├── IndexV2.ets                 # 主入口（四 Tab 导航；处理通知跳转推荐菜谱）
│   ├── CalorieScanPage.ets         # 热量识别页（拍照 / 图库 + 识别结果展示）
│   ├── DietaryStructurePage.ets    # 饮食结构建议（膳食宝塔 + 营养素 + 推荐量，纯静态）
│   ├── LegalDocPage.ets            # 隐私政策 & 用户协议阅读页
│   ├── SettingsPage.ets            # 设置与管理（含每日推荐通知配置）
│   ├── FavoritesPage.ets           # 收藏列表
│   ├── FolderDetailPage.ets        # 收藏夹详情页
│   ├── CreateFolderPage.ets        # 新建收藏夹页
│   ├── HistoryPage.ets             # 浏览历史（含热力图）
│   └── Index.ets                   # 旧版入口（保留兼容）
│
├── service/
│   ├── RecipeSearchService.ets     # 纯函数搜索（严格 / 模糊 / 生存，含同义词扩展）
│   ├── RecipeRecommendationService.ets  # 个性化推荐（Jaccard CF）
│   ├── NutritionCalculator.ets     # 营养评价（Nutri-Score A-E / DRI 进度 / 建议文本）
│   ├── IngredientAmountService.ets # 食材用量换算（20+ 单位，支持分数）
│   ├── CloudFoodAnalyzer.ets       # 云端食物识别服务封装
│   ├── FoodRecognitionService.ets  # 本地食物识别逻辑
│   ├── ShoppingListService.ets     # 缺料对比 + 剪贴板导出
│   ├── DailyRecommendService.ets   # 每日推荐选菜算法（冰箱优先 / 精选标签 / 随机）
│   └── ReminderService.ets         # reminderAgentManager 封装（调度 / 取消每日闹钟）
│
├── store/
│   └── CookPreferences.ets         # Preferences 持久化（收藏 / 历史 / 搜索历史 / 今日餐桌 / 推荐通知设置）
│
├── util/
│   └── StatusBarInset.ets          # 系统安全区顶部高度计算
│
├── utils/
│   ├── CalorieCalculator.ets       # 食物热量计算工具
│   └── PhotoPickerHelper.ets       # 系统图库选图封装
│
└── entryability/
    └── EntryAbility.ets             # 沉浸式 UI 初始化 + 系统主题监听 + 通知跳转处理
```

---

## 数据说明

菜谱数据存储于 `entry/src/main/resources/rawfile/recipe.json`，格式与 Web 端共享：

```typescript
interface RecipeItem {
  name: string
  stuff: string[]                    // 所需食材
  stuffAmount?: Record<string, string> // 食材用量（如 "猪肉": "200克"）
  tools: string[]                    // 所需厨具
  steps?: string[]                   // 烹饪步骤
  emojis?: string[]                  // 菜品 Emoji
  difficulty?: '简单' | '普通' | '困难'
  tags?: string[]
  methods?: string[]                 // 烹饪方式（炒/蒸/烤等）
  imageUri?: string
  nutrition?: RecipeNutrition        // 营养成分（热量/蛋白质/脂肪/碳水/膳食纤维/钠）
}
```

数组下标为稳定 ID，收藏与历史均以 `number[]` 形式存储于 Preferences。

营养数据通过 `NutritionCalculator.SAMPLE_NUTRITION_DATA`（内置 20 道菜谱）在启动时注入内存，无需修改 JSON 文件。

---

## 快速开始

### 环境要求

- DevEco Studio 5.0+
- HarmonyOS SDK API 22（HarmonyOS 6.0.2）

### ⚠️ 首次克隆后必须手动创建 build-profile.json5

根目录的 `build-profile.json5` 包含签名证书路径与密钥，已加入 `.gitignore`，**不在版本库中**。每次克隆项目后需手动在项目根目录创建该文件，否则 Hvigor 会报错 `Cannot find project build file build-profile.json5`。

在项目根目录（与 `hvigor/` 同级）新建 `build-profile.json5`，内容如下，**根据本机实际签名文件路径修改 `material` 字段**：

```json5
{
  "app": {
    "signingConfigs": [
      {
        "name": "default",
        "type": "HarmonyOS",
        "material": {
          "storeFile": "你的/keystore.p12路径",
          "storePassword": "加密后的密钥库密码",
          "keyAlias": "keystore",
          "keyPassword": "加密后的密钥密码",
          "signAlg": "SHA256withECDSA",
          "profile": "你的/cook_profileRelease.p7b路径",
          "certpath": "你的/发布证书.cer路径"
        }
      }
    ],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "targetSdkVersion": "6.0.2(22)",
        "compatibleSdkVersion": "6.0.2(22)",
        "runtimeOS": "HarmonyOS",
        "buildOption": {
          "strictMode": {
            "caseSensitiveCheck": true,
            "useNormalizedOHMUrl": true
          }
        }
      }
    ],
    "buildModeSet": [
      { "name": "debug" },
      { "name": "release" }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        {
          "name": "default",
          "applyToProducts": ["default"]
        }
      ]
    }
  ]
}
```

> 签名文件（`.p12` / `.p7b` / `.cer`）可在 AppGallery Connect → 证书管理 中下载，密码加密格式由 DevEco Studio 的 **Project Structure → Signing Configs** 自动生成填入。

---

### 构建运行

```bash
# 方式一：DevEco Studio 直接运行（推荐）
# 打开项目 → 选择设备/模拟器 → Run

# 方式二：命令行构建 HAP
node ./hvigor/hvigor-wrapper.js --mode module \
  -p module=entry@default \
  -p product=default \
  assembleHap
```

### 模拟器注意事项

- 首次安装前需**卸载旧版本**，避免应用名称缓存为旧值
- 运行后如应用名称显示异常，执行 **Run → Clean Project** 后重新安装

---

## 合规说明

| 合规项 | 状态 |
|--------|------|
| 首次启动隐私同意弹窗 | ✅ |
| 隐私政策页面（独立页） | ✅ |
| 用户协议页面（独立页） | ✅ |
| 权限声明（相册读写 / 相机 / 屏幕常亮 / 推送提醒） | ✅ |
| 应用图标与名称配置 | ✅ |
| AGC 后台数据安全说明 | ⚠️ 上架前需填报 |

---

## 贡献者与更新历史

| 贡献者 | 主要贡献 |
|---|---|
| Ruheluobixieqing | 初始化项目与 `.gitignore`；整理基础菜谱数据；实现 Preferences 本地存储、主界面骨架、导航栏、发现页、菜谱页、收藏与浏览历史；接入 RDB 数据库并处理应用名、包名、构建配置与滑动交互优化。 |
| TEITAR-mxh | 重构 `IndexV2` 主界面与核心组件；切换应用入口；完善设置架构、详情弹窗、DB 接入、启动页、隐私合规、深色模式、饮食结构建议页、餐桌页与审核问题修复；实现热量识别模块（`CalorieScanPage` / `DailyDietCircleCard` / `DietDatabaseHelper` / `CloudFoodAnalyzer`）；实现搜索历史联想、食材同义词库、步骤编号气泡卡片、食材用量归一化、历史热力图、个性化推荐引擎（Jaccard CF）与营养评价系统（Nutri-Score）；实现每日菜谱推荐通知系统（`ReminderService` / `DailyRecommendService`）；优化猜你喜欢布局与 RecipeCard 小卡片文字遮挡；修复颜色模式显示 bug。 |
| TTong | 升级 `RecipeCard`，接入 `difficulty` 与 `methods` 字段；完善首页食材全量展示、厨具筛选、标签与难度筛选；实现收藏夹完整功能。 |
| Gaoxuan | 生成并补充最终菜谱数据；完善菜谱步骤内容，提升菜谱数据完整性。 |
| Fanbo0419 | 更新 `bundleName`；修订隐私政策和开发者联系方式；绑定生成证书并完成 `.app` 软件包生成相关工作。 |

---

## 开源协议

本项目代码以学习交流为目的开源，菜谱内容整理自公开烹饪知识。

仓库地址：[https://github.com/TEITAR-mxh/Cook-njust.git](https://github.com/TEITAR-mxh/Cook-njust.git)

© 2026 AUV 项目组 · 南京理工大学
