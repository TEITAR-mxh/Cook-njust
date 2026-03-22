/**
 * 食材标签组件 - 基于原型中的 tag-base 样式
 * 支持三种类型:肉类(meat)、蔬菜(veg)、碳水(carb)
 * 包含原生级点击缩放动效
 */
import { AppColors } from '../constants/AppColors'

export enum TagType {
  MEAT = 'meat',
  VEG = 'veg',
  CARB = 'carb',
  DEFAULT = 'default'
}

@Component
export struct IngredientTag {
  @Prop label: string = ''
  @Prop tagType: TagType = TagType.DEFAULT
  @Prop isActive: boolean = false
  @Prop isHighlighted: boolean = false  // 随机动画中的高亮状态
  @Prop emoji: string = ''
  onTagClick?: () => void

  // 用于点击动效的状态
  @State scaleValue: number = 1.0

  /**
   * 根据激活状态和类型返回背景色
   */
  private getBackgroundColor(): string {
    // 高亮状态(随机动画中)
    if (this.isHighlighted) {
      return AppColors.GRAY_300
    }

    if (!this.isActive) {
      return AppColors.CARD_BG
    }
    switch (this.tagType) {
      case TagType.MEAT:
        return AppColors.MEAT_BG
      case TagType.VEG:
        return AppColors.VEG_BG
      case TagType.CARB:
        return AppColors.CARB_BG
      default:
        return AppColors.CARD_BG
    }
  }

  /**
   * 根据激活状态和类型返回边框色
   */
  private getBorderColor(): string {
    if (!this.isActive) {
      return AppColors.GRAY_200
    }
    switch (this.tagType) {
      case TagType.MEAT:
        return AppColors.MEAT_BORDER
      case TagType.VEG:
        return AppColors.VEG_BORDER
      case TagType.CARB:
        return AppColors.CARB_BORDER
      default:
        return AppColors.GRAY_200
    }
  }

  /**
   * 根据激活状态和类型返回文字色
   */
  private getTextColor(): string {
    // 高亮状态(随机动画中)
    if (this.isHighlighted) {
      return '#FFFFFF'
    }

    if (!this.isActive) {
      return AppColors.GRAY_600
    }
    switch (this.tagType) {
      case TagType.MEAT:
        return AppColors.MEAT_TEXT
      case TagType.VEG:
        return AppColors.VEG_TEXT
      case TagType.CARB:
        return AppColors.CARB_TEXT
      default:
        return AppColors.GRAY_600
    }
  }

  build() {
    Text(`${this.emoji.length > 0 ? this.emoji + ' ' : ''}${this.label}`)
      .fontSize(14)
      .fontColor(this.getTextColor())
      .fontWeight(this.isActive ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor(this.getBackgroundColor())
      .borderRadius(100) // 原型中的 rounded-full
      .borderWidth(1)
      .borderColor(this.getBorderColor())
      .shadow({
        radius: this.isActive ? 0 : 2,
        color: 'rgba(0,0,0,0.02)',
        offsetX: 0,
        offsetY: 2
      })
      .scale({ x: this.scaleValue, y: this.scaleValue })
      .animation({
        duration: 200,
        curve: Curve.FastOutSlowIn
      })
      .onTouch((event) => {
        if (event.type === TouchType.Down) {
          // 原型中的 :active { transform: scale(0.92) }
          this.scaleValue = 0.92
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.scaleValue = 1.0
          if (event.type === TouchType.Up && this.onTagClick) {
            this.onTagClick()
          }
        }
      })
  }
}
