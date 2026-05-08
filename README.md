# AUV 您吃了么

> 基于 HarmonyOS NEXT (API 22) ArkTS 开发的本地菜谱助手应用。用户从冰箱已有食材出发，智能匹配可做菜谱，查看烹饪步骤并一键跳转视频教程。

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
- 随机食材抽取动画

### 菜谱 Tab — 浏览探索
- 全量菜谱列表，RecipeCard 大/小双模式
- 关键词全文搜索
- 标签筛选（今日推荐 / 减脂餐 / 快手早餐 / 广式 / 川香 / 烘焙 / 汤羹）
- 点击卡片打开系统原生半模态详情弹窗（`bindSheet`）

### 发现 Tab — 随机推荐
- 随机抽取含视频教程的菜谱
- 淡入淡出切换动画
- 右上角「?」快捷入口，跳转**饮食结构建议页**

### 饮食结构建议页
- 中国居民平衡膳食宝塔示意图展示
- 三大营养素供能比（碳水 / 蛋白质 / 脂肪）可视化进度条
- 11 类食物每日推荐摄入量清单
- 6 条膳食核心建议（依据《中国居民膳食指南（2022）》）
- 深色模式适配，与全局主题系统联动

### 餐桌 Tab — 个人中心
- 收藏网格（最多 500 条，按收藏时间排序）
- 浏览历史（最近 50 条）
- 用户资料（昵称 / 头像 Emoji / 相册图片）
- 主题切换（浅色 / 深色 / 跟随系统）
- 数据管理（保留本地数据开关 / 缓存清理）

### 详情弹窗
- 食材列表 / 厨具说明 / 分步骤烹饪指引
- 收藏切换（即时同步）
- 跳转 Bilibili 视频教程

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
| 跨页面主题同步 | `AppStorage` + `@StorageProp` / `@Watch`，零轮询 |
| 系统主题监听 | `EntryAbility.onConfigurationUpdate` 写入 `AppStorage('isSystemDarkMode')` |
| UTF-8 解码 | 自定义 `utf8BytesToString()`，规避 SDK 跨版本 `TextDecoder` 差异 |
| 沉浸式底栏 | `setWindowLayoutFullScreen(true)` + 透明导航栏 + 安全区适配 |
| 收藏/历史并发安全 | `CookPreferences` Promise 链式单例，防止竞态写入 |
| ArkUI 响应性 | `@State` 赋值使用深拷贝，避免引用未变导致 UI 不刷新 |

---

## 项目结构

```
entry/src/main/ets/
├── components/
│   ├── RecipeCard.ets           # 菜谱卡片（大/小双模式，收藏按钮，视频播放数角标）
│   ├── RecipeDetailSheet.ets    # 底部详情弹窗（原生 bindSheet + nestedScroll）
│   ├── CookingFocusView.ets     # 全屏专注烹饪覆盖层（Swiper 翻页 + 屏幕常亮锁）
│   ├── IngredientTag.ets        # 颜色编码食材标签
│   ├── ToastView.ets            # 毛玻璃 Toast 通知
│   ├── PlateCard.ets            # 3D 盘子效果卡片
│   └── RandomPickerButton.ets  # 随机食材抽取触发器
│
├── constants/
│   └── AppColors.ets            # 品牌色 + 深色适配色 + ThemeManager 工具类
│
├── data/
│   ├── RecipeRepository.ets     # 菜谱数据单例（rawfile JSON 索引化加载）
│   └── foodCatalog.ets          # 食材 / 厨具目录（含 emoji 映射）
│
├── model/
│   └── recipe.ets               # RecipeItem / RecipeWithId / SearchMode 类型定义
│
├── pages/
│   ├── StartupPage.ets          # 启动页（品牌动画 + 隐私同意对话框）
│   ├── IndexV2.ets              # 主入口（四 Tab 导航）
│   ├── LegalDocPage.ets         # 隐私政策 & 用户协议阅读页
│   ├── SettingsPage.ets         # 设置与管理
│   ├── FavoritesPage.ets        # 收藏列表
│   ├── HistoryPage.ets          # 浏览历史
│   └── DietaryStructurePage.ets # 饮食结构建议（膳食宝塔 + 营养素 + 推荐量）
│
├── service/
│   ├── RecipeSearchService.ets  # 纯函数搜索（严格 / 模糊 / 生存三算法）
│   ├── ShoppingListService.ets  # 缺料对比 + 剪贴板导出
│   └── RecipeVideoLauncher.ets  # Bilibili BV 跳转 / 剪贴板回退
│
├── store/
│   └── CookPreferences.ets      # HarmonyOS Preferences 持久化封装
│
├── util/
│   ├── StatusBarInset.ets       # 系统安全区顶部高度计算
│   └── ThemeManager.ets         # 主题状态读取工具
│
└── entryability/
    └── EntryAbility.ets         # 沉浸式 UI 初始化 + 系统主题监听
```

---

## 数据说明

菜谱数据存储于 `entry/src/main/resources/rawfile/recipe.json`，格式与 Web 端共享：

```typescript
interface RecipeItem {
  name: string
  stuff: string[]       // 所需食材
  tools: string[]       // 所需厨具
  steps?: string[]      // 烹饪步骤
  emojis?: string[]     // 菜品 Emoji
  difficulty?: '简单' | '普通' | '困难'
  tags?: string[]
  methods?: string[]    // 烹饪方式（炒/蒸/烤等）
  imageUri?: string
}
```

数组下标为稳定 ID，收藏与历史均以 `number[]` 形式存储于 Preferences。

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
| 权限声明（相册读写 / 屏幕常亮） | ✅ |
| 应用图标与名称配置 | ✅ |
| AGC 后台数据安全说明 | ⚠️ 上架前需填报 |

---

## 开源协议

本项目代码以学习交流为目的开源，菜谱内容整理自公开烹饪知识。

仓库地址：[https://github.com/Ruheluobixieqing/Cook.git](https://github.com/Ruheluobixieqing/Cook.git)

© 2026 AUV 项目组 · 南京理工大学
