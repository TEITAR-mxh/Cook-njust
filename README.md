<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:ff4757,100:ffa751&height=170&section=header&text=AUV%20%E6%82%A8%E5%90%83%E4%BA%86%E4%B9%88&fontSize=46&fontColor=ffffff&fontAlignY=38&desc=HarmonyOS%20NEXT%20%E6%9C%AC%E5%9C%B0%E8%8F%9C%E8%B0%B1%E5%8A%A9%E6%89%8B&descAlignY=60&descSize=16&animation=fadeIn" />

[![HarmonyOS NEXT](https://img.shields.io/badge/platform-HarmonyOS%20NEXT-0a9cff?style=flat-square)](https://developer.huawei.com/consumer/cn/harmonyos/)
[![ArkTS](https://img.shields.io/badge/language-ArkTS-3178C6?style=flat-square)](https://developer.huawei.com/consumer/cn/arkts/)
[![License](https://img.shields.io/badge/license-MIT-2ea44f?style=flat-square)](./LICENSE)

</div>

> 打开冰箱，看看今天能做什么菜。

AUV 您吃了么是一个跑在 HarmonyOS NEXT 上的本地菜谱应用。它的出发点是「冰箱里有什么」，而不是「想吃什么」——勾选现有食材，就能筛出今天做得成的菜；做完了，顺手记一笔热量，看一眼营养。

数据全部存在本地，不联网也能正常用。云端识别只是可选兜底。

---

## 目录

- [功能](#功能)
- [技术栈](#技术栈)
- [快速开始](#快速开始)
- [项目结构](#项目结构)
- [数据来源](#数据来源)
- [已知问题与说明](#已知问题与说明)
- [参与贡献](#参与贡献)
- [许可证](#许可证)

---

## 功能

**冰箱**
勾选食材（37 种，分肉蛋水产 / 蔬菜 / 碳水辅料三色），配合厨具筛选，用严格、模糊、生存三种模式找菜。支持 24 组食材同义词，番茄和西红柿都能搜到。

**菜谱**
收录 1008 道菜，大图卡和列表两种浏览方式。支持菜名搜索（带历史联想）、标签筛选和 8 类烹饪方式筛选。

**发现**
按菜系浏览经典菜：川、粤、湘、鲁、苏、浙、闽、东北、京、鄂、客家、西式、台式、东南亚、新疆共 15 个菜系，每个菜系精选经典菜排行，点开就能看做法。「猜你喜欢」基于标签、食材和烹饪方式做相似度推荐。

**餐桌**
今日饮食圆环（按热量完成度变色）、三大营养素进度、收藏与浏览历史、12 周饮食热力图，以及浅色 / 深色 / 跟随系统的主题切换。

**详情与烹饪**
食材用量按人数实时换算（1–6 人），Nutri-Score 给出 A–E 评级；缺料可以生成采购清单并导出为图片；专注烹饪模式按步骤全屏翻页，屏幕常亮。

**拍照识别**
HiAI NPU → MindSpore Lite → 百度云端三级降级。识别结果不可靠时不会硬算热量，而是提示「没认准」，可手动填写。

**每日推荐**
通过系统代理提醒在固定时间推送当天推荐菜谱，可在系统通知设置里随时关闭。

---

<details>
<summary><strong>功能细节（点开查看）</strong></summary>

<br />

**营养计算**

- 菜谱营养由食材营养库按单份经验份量聚合，`ingredient_nutrition.json` 覆盖全部食材名。
- Nutri-Score 采用 Ofcom 简化模型：热量、饱和脂肪、糖、钠为负分项，蛋白质、膳食纤维、蔬菜占比为正分项。
- 识别出的菜品同样会计算评级，在结果卡中以徽章展示。

**识别降级**

| 识别优先级&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | 引擎 | 触发条件 |
| :--- | --- | --- |
| 第一级&nbsp;&nbsp;&nbsp;&nbsp; | HiAI NPU | 初始化试运行通过，置信度 ≥ 0.55 |
| 第二级&nbsp;&nbsp;&nbsp;&nbsp; | MindSpore Lite | 置信度 ≥ 0.20，纯 CPU 兜底 |
| 第三级&nbsp;&nbsp;&nbsp;&nbsp; | 百度云端 | 前两级失败或置信度不足（可选） |

模型文件缺失时自动跳过对应层级，识别来源会以不同颜色标注。

**设计取舍**

- 菜谱 ID 目前使用入库数组下标。调整 `recipe.json` 顺序前，需要迁移已存储的收藏与历史。
- 页面间状态同步走 AppStorage + `@StorageProp` / `@Watch`，避免轮询。
- 打开详情弹窗时延迟写入历史和推荐，优先保证弹窗渲染流畅。

</details>

---

## 技术栈

- **平台**：HarmonyOS NEXT，API 22（HarmonyOS 6.0.2）
- **语言**：ArkTS，无 `any`
- **构建**：Hvigor
- **本地存储**：RDB（菜谱、饮食记录）+ Preferences（收藏、历史、设置）
- **端侧推理**：HiAI Foundation、MindSpore Lite
- **入口**：`StartupPage` → `IndexV2`

应用结构大致是三层：

```
Pages ── Components ── Service ── Data / Model
                                  └── Store（Preferences）
```

---

## 快速开始

**环境**

- DevEco Studio（支持项目模型版本 6.0.2）
- HarmonyOS SDK API 22
- 一台 HarmonyOS NEXT 设备或模拟器

**运行**

1. 用 DevEco Studio 打开仓库根目录，等待依赖同步完成。
2. 在项目设置里配置 SDK、product 和签名。
3. 运行 `entry`。

> 仓库不含 `hvigor-wrapper.js`，命令行构建请使用本机安装的 DevEco / Hvigor 工具链。
> `build-profile.json5` 因包含签名配置未入库，新克隆需要自行配置。

**云端识别（可选）**

复制 `entry/src/main/ets/config/CloudApiConfig.example.ets` 为 `CloudApiConfig.ets`，填入自己的百度 AI Key。不配置也能用，只是识别会走本地引擎。

**安装注意**

首次安装前建议卸载旧版本，避免应用名缓存；名称显示异常时执行 `Run → Clean Project` 后重装。

---

<details>
<summary><strong>项目结构（点开查看）</strong></summary>

<br />

```
entry/src/main/
├── ets/
│   ├── components/      可复用组件（卡片、详情弹窗、识别预览等）
│   ├── constants/       品牌色与设计系统
│   ├── config/          云端 API 配置
│   ├── data/            菜谱仓库、RDB、同义词、食材目录
│   ├── model/           类型定义
│   ├── pages/           页面
│   ├── service/         识别、营养、推荐、采购、提醒等业务模块
│   ├── store/           Preferences 持久化
│   ├── util/            安全区、主题工具
│   ├── utils/           热量计算、图片预处理
│   └── entryability/    入口、沉浸式、主题监听、通知跳转
└── resources/rawfile/
    ├── recipe.json              菜谱数据
    ├── cuisine_classics.json    菜系经典页数据
    ├── ingredient_nutrition.json 食材营养库
    ├── recipe_images/           菜谱配图
    └── food_model.ms / food_labels.txt
```

</details>

---

## 数据来源

- **菜谱做法**来源于开源项目 [HowToCook](https://github.com/Anduin2017/HowToCook)（Unlicense，公有领域），并做了去重、补全和分类。
- **菜谱配图**来自公开渠道采集与用户贡献。如果你发现自己的图片被使用且不希望这样，请提 Issue，我们会尽快移除。
- **营养数据**参考《中国食物成分表（第 6 版）》整理，部分细分类食材为类别估算。

---

## 已知问题与说明

- 营养数值为估算值，仅供日常参考，不构成膳食或医疗建议。
- 识别准确率受拍摄光线、菜品摆盘影响，复杂菜品可能需要手动修正。
- 部分菜谱暂无配图，会显示占位图。
- 代理提醒属于应用市场审核受限能力，仅在审核通过的品类下可用。
- 菜谱 ID 依赖数组顺序，后续如果重构需要做一次迁移。

---

## 参与贡献

欢迎提 Issue 和 PR。补充菜品配图请使用「菜品配图补充」Issue 模板，并确保图片是本人拍摄或已获授权，配图要求见 [贡献说明](docs/CONTRIBUTING_IMAGES.md)。

---

## 许可证

代码以 [MIT License](./LICENSE) 发布，版权归 AUV 您吃了么项目组所有。

菜谱做法来源于 [HowToCook](https://github.com/Anduin2017/HowToCook)，该项目以 Unlicense（公有领域）发布。

---

<div align="center">

<a href="https://github.com/TEITAR-mxh/Cook-njust">
  <img src="https://img.shields.io/badge/GitHub-TEITAR--mxh%2FCook--njust-181717?style=for-the-badge&logo=github" />
</a>

<sub>AUV 您吃了么 · 南京理工大学</sub>

</div>
