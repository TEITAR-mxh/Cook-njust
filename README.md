<div align="center">

# 🍳 AUV 您吃了么

**HarmonyOS NEXT 本地菜谱助手** · 从冰箱已有食材出发，智能匹配可做菜谱，支持热量识别、营养评估、个性化推荐与专注烹饪模式。

[![HarmonyOS NEXT](https://img.shields.io/badge/HarmonyOS%20NEXT-API%2022-007DFF?logo=harmonyos&logoColor=white)](https://developer.huawei.com/consumer/cn/harmonyos/)
[![Language](https://img.shields.io/badge/Language-ArkTS-3178C6)](https://developer.huawei.com/consumer/cn/arkts/)
[![License](https://img.shields.io/badge/License-MIT-2ea44f)](./LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-brightgreen)](./docs/CONTRIBUTING_IMAGES.md)

</div>

---

## ✨ 简介

「AUV 您吃了么」是一款面向日常下厨场景的鸿蒙原生应用。它把**冰箱里有什么**作为起点，反向匹配**能做什么菜**，并在识别、营养、推荐、采购与烹饪全程提供辅助：

- 拍照或手动录入食材 → 识别菜品 → 自动计算热量与 Nutri-Score 营养评级
- 从「今天吃什么」到「猜你喜欢」，基于内容的个性化推荐
- 菜系经典、采购清单导出、专注烹饪模式等实用功能开箱即用

全部数据本地处理，**无需联网即可使用**（云端识别为可选兜底）。

---

## 🎯 功能

| 模块 | 说明 |
|---|---|
| 🧊 **冰箱 Tab** | 37 种食材多选（肉蛋水产 / 蔬菜 / 碳水辅料三色）、厨具筛选、严格 / 模糊 / 生存三种搜索、24 组食材同义词、加权随机抽取 |
| 📖 **菜谱 Tab** | 1008 道菜谱大图卡 / 列表双模式、菜名关键词 + 历史联想、标签筛选、8 类烹饪方式分组筛选 |
| 🧭 **发现 Tab** | 菜系经典页（15 大菜系 · 经典菜排行）、猜你喜欢（Jaccard 相似度推荐）、随机推荐动画、饮食结构建议 |
| 🍽️ **餐桌 Tab** | 今日饮食圆环 + 三大营养素进度条、收藏网格（最多 500）、浏览历史（最近 50）、12 周热力图、主题切换 |
| 📋 **详情弹窗** | 食材用量 → 厨具 → 加入餐桌 → 步骤卡片 → 营养信息，人数调节（1–6 人）用量等比换算，Nutri-Score A–E 评级 |
| 🛒 **采购清单** | 缺料对比 + 剪贴板导出 + Canvas 绘制 1080×1920 图片导出（三种风格） |
| 🎬 **专注烹饪** | 全屏 Swiper 分步浏览、任意步骤跳入、屏幕常亮锁 |
| 📷 **热量识别** | HiAI NPU（≥0.55）→ MindSpore Lite CPU（≥0.20）→ 百度云端三级降级，识别结果 Nutri-Score 即时评级，本地 RDB 持久化 |
| 🔔 **每日推荐** | 系统级定时推送、四级优先级选菜、自动排除近 7 天、点击直达详情 |

---

## 🛠️ 技术架构

```
Pages（13 页）
        ↕
Components（可复用组件）
        ↕
Service（业务模块）          Store（CookPreferences 单例）
        ↕
Data（数据层）               Model（类型定义）
```

**关键设计**

- **跨页面状态同步**：AppStorage + `@StorageProp` / `@Watch`，零轮询
- **营养评分**：Ofcom Nutri-Score 简化模型，负分（热量 / 饱和脂肪 / 糖 / 钠）− 正分（蛋白质 / 膳食纤维 / 蔬菜标签）
- **混合识别**：`HybridRecognizer` 编排三级降级，模型缺失自动跳过，识别来源可视化
- **食材营养聚合**：`IngredientNutritionService` 按食材经验份量聚合整份菜营养，389 条食材库（成分表精确值 + 类别估算）
- **沉浸式适配**：`setWindowLayoutFullScreen(true)` + 状态栏安全区动态计算
- **主题系统**：`@StorageProp` + `ThemeManager` 动态配色，浅色 / 深色 / 跟随系统

---

## 📦 项目信息

| 项 | 值 |
|---|---|
| 平台 | HarmonyOS NEXT API 22（HarmonyOS 6.0.2） |
| 语言 | ArkTS（零 `any`，全类型推断） |
| 包名 | `com.example.cook_njust_project` |
| 版本 | 1.0.1 |
| 构建工具 | Hvigor |
| 入口 | `StartupPage` → `IndexV2` |
| 菜谱规模 | 1008 道（去重后，覆盖 15 大菜系） |

---

## 🚀 快速开始

### 环境要求

- DevEco Studio（支持项目模型版本 6.0.2 与目标 SDK）
- HarmonyOS SDK API 22

### 构建

1. 用 DevEco Studio 打开仓库根目录，完成依赖同步
2. 在项目设置中配置 SDK、`product` 与自己的签名
3. 运行 `entry`

> 命令行构建需使用本地安装的 DevEco/Hvigor 工具链（仓库不含 `hvigor-wrapper.js`）。初始化与验证详见 [维护接手指南](docs/MAINTENANCE.md)。

### 注意事项

- 首次安装前请卸载旧版本，避免应用名称缓存
- 名称显示异常时执行 `Run → Clean Project` 后重装

---

## 📁 目录结构

```
entry/src/main/
├── ets/
│   ├── components/          # 可复用组件（卡片 / 详情弹窗 / 识别组件等）
│   ├── constants/           # 品牌色 + 设计系统常量
│   ├── config/              # 云端 API 配置（密钥用 .example 模板）
│   ├── data/                # 数据层（菜谱仓库 / RDB / 食材同义词 / 目录）
│   ├── model/               # 类型定义
│   ├── pages/               # 13 个页面
│   ├── service/             # 业务模块（识别 / 营养 / 推荐 / 采购 / 提醒等）
│   ├── store/               # Preferences 持久化
│   ├── util/                # 安全区 / 主题工具
│   ├── utils/               # 热量计算 / 图片预处理等
│   └── entryability/        # 入口 + 沉浸式 + 主题监听 + 通知跳转
└── resources/rawfile/
    ├── recipe.json           # 1008 道菜谱
    ├── cuisine_classics.json # 菜系经典页数据
    ├── ingredient_nutrition.json # 食材营养库（389 条）
    ├── recipe_images/        # 菜谱配图
    └── ...                   # MindSpore 模型与标签
```

---

## 📊 数据与图片

- **菜谱内容**整理自开源项目 [HowToCook](https://github.com/YunYouJun/cook)（MIT License）并补全扩展，版权归原作者所有。
- **菜品配图**通过多渠道采集与用户贡献补充，详见 [菜品配图贡献说明](docs/CONTRIBUTING_IMAGES.md)。

---

## 🤝 贡献

欢迎提交 Issue 与 PR。为菜谱补充配图请使用「菜品配图补充」Issue 模板，并确保图片为**本人拍摄**或**已获授权**。

---

## ⚖️ 许可证

本项目代码以 [MIT License](./LICENSE) 开源。

```
MIT License
Copyright (c) 2026 AUV您吃了么 项目组 · 南京理工大学
```

> 菜谱内容版权归属其原始作者，使用时请遵循 [HowToCook](https://github.com/YunYouJun/cook) 的开源协议。

---

---

<div align="center">

**AUV 您吃了么 · 南京理工大学**

[https://github.com/TEITAR-mxh/Cook-njust.git](https://github.com/TEITAR-mxh/Cook-njust.git)

</div>
