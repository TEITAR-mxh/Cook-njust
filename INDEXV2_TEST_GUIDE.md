# IndexV2.ets 测试指南

## 当前完成进度

✅ **已完成的组件**:
1. `AppColors.ets` - 品牌色定义系统
2. `IngredientTag.ets` - 食材标签组件(带颜色分类和点击动效)
3. `ToastView.ets` - 毛玻璃Toast提示
4. `RandomPickerButton.ets` - 随机搭配按钮
5. `RecipeDetailSheet.ets` - 半模态菜谱详情页
6. `PlateCard.ets` - 餐桌瓷盘3D效果
7. `RecipeCard.ets` - 菜谱卡片组件(大图/小图模式)
8. `IngredientTypeMapper.ets` - 食材类型映射工具
9. `IndexV2.ets` - 主页面(全部4个Tab已完成)

✅ **已修复的编译错误**:
- `Color.White` 类型错误 → 改用 `'#FFFFFF'` 字符串
- `opacity` 属性冲突 → 重命名为 `opacityValue`
- `onClick` 属性冲突 → 重命名为 `onCardClick` / `onPlateClick`
- 缺失的 `table_texture.png` 资源 → 移除可选的背景图片引用

## 如何启用 IndexV2

✅ **已配置完成，开箱即用！**

IndexV2 已经被设置为应用的默认主页面，配置文件已更新：

1. **entry/src/main/resources/base/profile/main_pages.json**:
   ```json
   {
     "src": [
       "pages/IndexV2",  // ✅ IndexV2 已设为首页
       "pages/Index",
       "pages/HistoryPage",
       "pages/FavoritesPage"
     ]
   }
   ```

2. **entry/src/main/ets/entryability/EntryAbility.ets**:
   ```typescript
   windowStage.loadContent('pages/IndexV2', (err) => {  // ✅ 加载 IndexV2
     // ...
   });
   ```

### 运行项目

直接构建即可使用 IndexV2:

```bash
node ./hvigor/hvigor-wrapper.js --mode module -p module=entry@default -p product=default assembleHap
```

### 切回旧版 Index (如需要)

如果需要切换回旧版 Index 页面，修改 `EntryAbility.ets`:

```typescript
// 将这一行
windowStage.loadContent('pages/IndexV2', (err) => {

// 改为
windowStage.loadContent('pages/Index', (err) => {
```

## 已实现的视觉特性

### 「做菜」Tab
- ✅ 大标题区域("准备做点什么?")
- ✅ 清空按钮(圆角胶囊样式)
- ✅ 随机搭配按钮(渐变背景 + 骰子图标)
- ✅ 食材标签彩色分类:
  - 🥩 肉蛋水产 - 红色系
  - 🥬 新鲜蔬菜 - 绿色系
  - 🍚 碳水辅料 - 黄色系
- ✅ 标签点击缩放动效(scale 0.92)
- ✅ 搜索模式切换(严格/宽松/生存模式)
- ✅ 底部悬浮生成按钮(品牌色渐变 + 阴影)
- ✅ 搜索结果实时显示

### 「菜谱」Tab
- ✅ 搜索框(支持菜名搜索)
- ✅ 菜谱卡片大图模式(第一张)
- ✅ 菜谱卡片小图模式(后续列表)
- ✅ 视频播放量标签
- ✅ 收藏功能集成

### 「发现」Tab
- ✅ 随机推荐功能
- ✅ "换一道"按钮(带随机动画)
- ✅ 仅显示有视频链接的菜谱
- ✅ 卡片点击查看详情

### 「我的」Tab (餐桌页面)
- ✅ 木纹背景渐变色
- ✅ 瓷盘3D效果卡片
- ✅ 收藏菜品网格展示
- ✅ 浏览历史入口
- ✅ 统计信息(菜谱总数/收藏数)

### 底部导航
- ✅ 毛玻璃效果(BlurStyle.Thick)
- ✅ Emoji图标替代传统SVG
- ✅ iOS风格小白条
- ✅ 安全区适配(expandSafeArea)
- ✅ 选中状态高亮

### 全局组件
- ✅ Toast提示(原生感毛玻璃弹窗)
- ✅ 半模态菜谱详情(从底部弹出,带拖拽指示器)
- ✅ 收藏/取消收藏功能
- ✅ B站视频跳转

## 待优化功能(可选)

1. **随机搭配动画**: 盲盒闪烁效果(10轮动画) - 当前仅显示Toast
2. **木纹背景纹理**: 可添加 `table_texture.png` 图片资源增强视觉效果
3. **视频播放量**: 当前显示固定值，可接入真实数据
4. **用户头像**: 可接入用户系统替换默认emoji

## 已知提示

1. **IDE拼写检查**: "rgba", "BILI" 等单词可能显示下划线
   - 这是拼写检查器的提示，不影响编译和运行
   - 可以在 `.vscode/settings.json` 中忽略:
   ```json
   {
     "cSpell.words": ["rgba", "BILI", "Hvigor"]
   }
   ```

2. **属性命名约定**:
   - ArkUI保留了 `opacity`, `onClick` 等属性名作为内置修饰符
   - 组件自定义属性使用 `opacityValue`, `onCardClick` 等命名避免冲突

## 对比原型图的实现度

| 功能模块 | 原型设计 | 实现状态 |
|---------|---------|---------|
| 食材标签颜色分类 | ✓ | ✅ 100% |
| 标签点击动效 | ✓ | ✅ 100% |
| 搜索模式切换 | ✓ | ✅ 100% |
| 随机搭配按钮 | ✓ | 🟡 80% (UI完成,完整动画可选) |
| 菜谱搜索 | ✓ | ✅ 100% |
| 菜谱卡片(大图/小图) | ✓ | ✅ 100% |
| 随机发现 | ✓ | ✅ 100% |
| 底部毛玻璃导航 | ✓ | ✅ 100% |
| Toast提示 | ✓ | ✅ 100% |
| 半模态详情页 | ✓ | ✅ 100% |
| 瓷盘3D效果 | ✓ | ✅ 100% |
| 木纹背景 | ✓ | ✅ 90% (渐变色完成,纹理图可选) |
| 收藏功能 | ✓ | ✅ 100% |
| 浏览历史 | ✓ | ✅ 100% |

## 技术亮点

1. **纯ArkTS实现**: 完全使用HarmonyOS NEXT原生组件，无Web依赖
2. **响应式设计**: 状态管理使用 `@State` / `@Prop` / `@Link` 确保UI实时更新
3. **性能优化**:
   - 使用单例模式(RecipeRepository, CookPreferences)
   - ForEach列表渲染优化
   - 懒加载滚动容器
4. **原生动效**:
   - animateTo API实现流畅过渡动画
   - 点击缩放反馈(Scale Transform)
   - 毛玻璃背景模糊(BlurStyle)
5. **安全区适配**: 支持全面屏手势区和状态栏动态适配
