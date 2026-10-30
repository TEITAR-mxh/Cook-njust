/**
 * 食材标签组件 - 基于原型中的 tag-base 样式
 * 支持三种类型:肉类(meat)、蔬菜(veg)、碳水(carb)
 * 包含原生级点击缩放动效
 */
import { AppColors } from '../constants/AppColors'

import { TagType } from '../model/ingredient'
export { TagType } from '../model/ingredient'

@Component
export struct IngredientTag {
  @Prop label: string = ''
  @Prop tagType: TagType = TagType.DEFAULT
  @Prop isActive: boolean = false
  @Prop isHighlighted: boolean = false
  @Prop emoji: string = ''
  @Prop isDark: boolean = false
  onTagClick?: () => void

  @State scaleValue: number = 1.0

  private getBackgroundColor(): string {
    if (this.isHighlighted) {
      return this.isDark ? AppColors.DARK_GRAY_300 : AppColors.GRAY_300
    }

    if (!this.isActive) {
      return this.isDark ? AppColors.DARK_CARD_BG : AppColors.CARD_BG
    }
    switch (this.tagType) {
      case TagType.MEAT:
        return this.isDark ? AppColors.DARK_MEAT_BG : AppColors.MEAT_BG
      case TagType.VEG:
        return this.isDark ? AppColors.DARK_VEG_BG : AppColors.VEG_BG
      case TagType.CARB:
        return this.isDark ? AppColors.DARK_CARB_BG : AppColors.CARB_BG
      case TagType.TOOL:
        return this.isDark ? AppColors.DARK_TOOL_BG : AppColors.TOOL_BG
      default:
        return this.isDark ? AppColors.DARK_CARD_BG : AppColors.CARD_BG
    }
  }

  private getBorderColor(): string {
    if (!this.isActive) {
      return this.isDark ? AppColors.DARK_GRAY_200 : AppColors.GRAY_200
    }
    switch (this.tagType) {
      case TagType.MEAT:
        return this.isDark ? AppColors.DARK_MEAT_BORDER : AppColors.MEAT_BORDER
      case TagType.VEG:
        return this.isDark ? AppColors.DARK_VEG_BORDER : AppColors.VEG_BORDER
      case TagType.CARB:
        return this.isDark ? AppColors.DARK_CARB_BORDER : AppColors.CARB_BORDER
      case TagType.TOOL:
        return this.isDark ? AppColors.DARK_TOOL_BORDER : AppColors.TOOL_BORDER
      default:
        return this.isDark ? AppColors.DARK_GRAY_200 : AppColors.GRAY_200
    }
  }

  private getTextColor(): string {
    if (this.isHighlighted) {
      return '#FFFFFF'
    }

    if (!this.isActive) {
      return this.isDark ? AppColors.DARK_GRAY_600 : AppColors.GRAY_600
    }
    switch (this.tagType) {
      case TagType.MEAT:
        return this.isDark ? AppColors.DARK_MEAT_TEXT : AppColors.MEAT_TEXT
      case TagType.VEG:
        return this.isDark ? AppColors.DARK_VEG_TEXT : AppColors.VEG_TEXT
      case TagType.CARB:
        return this.isDark ? AppColors.DARK_CARB_TEXT : AppColors.CARB_TEXT
      case TagType.TOOL:
        return this.isDark ? AppColors.DARK_TOOL_TEXT : AppColors.TOOL_TEXT
      default:
        return this.isDark ? AppColors.DARK_GRAY_600 : AppColors.GRAY_600
    }
  }

  build() {
    Text(`${this.emoji.length > 0 ? this.emoji + ' ' : ''}${this.label}`)
      .fontSize(14)
      .fontColor(this.getTextColor())
      .fontWeight(this.isActive ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor(this.getBackgroundColor())
      .borderRadius(100)
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
