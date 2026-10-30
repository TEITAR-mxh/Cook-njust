/**
 * 菜谱图片组件：统一处理 rawfile 资源解析、emoji 占位与加载失败回退。
 *
 * 约定（见 model/recipe.ets 中 imageUri 字段说明）：
 * - 随包图片：imageKey 为 rawfile 基础键（无扩展名），按 variant 解析为
 *   `recipe_images/{key}-{thumb|card|detail}.jpg`；
 * - 远端图片：imageKey 以 http(s):// 开头，直接作为 URL；
 * - 沙箱图片：imageKey 以 file:// 开头，直接作为本地路径。
 *
 * 无图、坏图、错误路径时：有 emoji 则显示 emoji，否则回退中性空盘占位，不阻塞列表渲染。
 */
export enum RecipeImageVariant {
  THUMB = 'thumb',
  CARD = 'card',
  DETAIL = 'detail',
}

@Component
export struct RecipeImage {
  /** 图片引用（rawfile 基础键 / URL / file 路径），为空时显示占位 */
  @Prop imageKey: string = ''
  /** 无图时展示的 emoji（由菜谱食材推导，空串则回退中性空盘） */
  @Prop emoji: string = ''
  /** 尺寸变体，决定 rawfile 文件名后缀 */
  @Prop variant: RecipeImageVariant = RecipeImageVariant.CARD
  /** 占位层背景色 */
  @Prop placeholderBg: string = '#F0FDF4'
  /** 图片裁切方式 */
  @Prop objectFit: ImageFit = ImageFit.Cover
  /** 圆角半径（vp）；> 0 时裁切子图 */
  @Prop cornerRadius: number = 0

  private hasImage(): boolean {
    return this.imageKey.trim().length > 0
  }

  /** 占位 emoji 字号按变体拆分，避免在 32px 缩略图等小容器里被裁切 */
  private emojiFontSize(): number {
    switch (this.variant) {
      case RecipeImageVariant.THUMB:
        return 28
      case RecipeImageVariant.DETAIL:
        return 72
      default:
        return 48
    }
  }

  private emojiLineHeight(): number {
    switch (this.variant) {
      case RecipeImageVariant.THUMB:
        return 32
      case RecipeImageVariant.DETAIL:
        return 80
      default:
        return 56
    }
  }

  /** 将 imageKey 解析为 Image 可接受的 Resource 或 URL/路径字符串 */
  private resolveSource(): Resource | string {
    const key = this.imageKey.trim()
    if (key.startsWith('http://') || key.startsWith('https://') ||
      key.startsWith('file://') || key.startsWith('data:')) {
      return key
    }
    return $rawfile(`recipe_images/${key}-${this.variant}.jpg`)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 占位层：始终在底层，图片加载成功后被覆盖，失败/无图时可见。
      // 有 emoji 显示 emoji，否则回退中性空盘。
      Column() {
        if (this.emoji.length > 0) {
          Text(this.emoji)
            .fontSize(this.emojiFontSize())
            .lineHeight(this.emojiLineHeight())
        } else {
          Column()
            .width('52%')
            .height('52%')
            .borderRadius(1000)
            .backgroundColor('rgba(255, 255, 255, 0.55)')
            .border({ width: 1, color: 'rgba(0, 0, 0, 0.06)' })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.placeholderBg)

      // 图片层：仅在有关键字时渲染，解析失败由系统 Image 显示为空并露出占位
      if (this.hasImage()) {
        Image(this.resolveSource())
          .width('100%')
          .height('100%')
          .objectFit(this.objectFit)
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.cornerRadius)
    .clip(this.cornerRadius > 0)
  }
}
