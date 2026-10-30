/**
 * 菜品配图补充入口
 *
 * 当某道菜没有成品图时，用户可从这里一键：
 *   1. 复制结构化的提交模板（菜名 / 菜品 ID / 素材要求），
 *   2. 打开 GitHub Issue 页面提交实拍或授权图片。
 *
 * 说明：App 内不直接上传图片，避免引入账号与存储服务；
 * 走开源仓库 Issue，便于人工审核来源与授权。
 */
import { common, Want } from '@kit.AbilityKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { AppColors, ThemeManager } from '../constants/AppColors'

const ISSUE_BASE: string = 'https://github.com/Ruheluobixieqing/Cook/issues/new?template=dish-image.yml'

@Component
export struct ImageContributeSheet {
  @Prop recipeName: string = ''
  @Prop recipeId: number = 0
  @Prop @Watch('onVisibleChange') visible: boolean = false
  onClose?: () => void

  @StorageProp('isSystemDarkMode') @Watch('onThemeChange') private sysDark: boolean = false
  @StorageProp('currentThemeMode') @Watch('onThemeChange') private themeMode: string = '系统默认'

  @State private cardBg: string = AppColors.CARD_BG
  @State private titleColor: string = AppColors.GRAY_900
  @State private bodyColor: string = AppColors.GRAY_500
  @State private subColor: string = AppColors.GRAY_400
  @State private dividerColor: string = AppColors.GRAY_100
  @State private toastMsg: string = ''
  @State private toastVisible: boolean = false

  private onThemeChange(): void {
    this.applyTheme()
  }

  private applyTheme(): void {
    this.cardBg = ThemeManager.getCardBackgroundColor(this.themeMode)
    this.titleColor = ThemeManager.getTextColor(this.themeMode)
    this.bodyColor = ThemeManager.getSecondaryTextColor(this.themeMode)
    this.subColor = ThemeManager.getColor(AppColors.GRAY_400, AppColors.DARK_GRAY_400, this.themeMode)
    this.dividerColor = ThemeManager.getBorderColor(this.themeMode)
  }

  private onVisibleChange(): void {
    if (this.visible) {
      this.applyTheme()
    }
  }

  private issueUrl(): string {
    const title = `[配图] ${this.recipeName}`
    return `${ISSUE_BASE}&title=${encodeURIComponent(title)}`
  }

  private templateText(): string {
    return [
      '【菜品配图补充】',
      `菜品名称：${this.recipeName}`,
      `菜品 ID：${this.recipeId}`,
      '图片：随 Issue 附件上传（成品照，横向 4:3 或 1:1，长边 ≥ 800px）',
      '拍摄/来源说明：',
      '授权说明：本人拍摄 / 来源链接与授权，同意用于本项目',
    ].join('\n')
  }

  private async copyTemplate(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.templateText())
      await pasteboard.getSystemPasteboard().setData(data)
      this.showToast('提交信息已复制，粘贴到 Issue 即可')
    } catch (_e) {
      this.showToast('复制失败，请手动填写')
    }
  }

  private async openIssue(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: this.issueUrl(),
      }
      await ctx.startAbility(want)
      if (this.onClose) this.onClose()
    } catch (_e) {
      this.showToast('无法打开浏览器，请访问 GitHub 仓库提交')
    }
  }

  private showToast(msg: string): void {
    this.toastMsg = msg
    this.toastVisible = true
    setTimeout(() => { this.toastVisible = false }, 2400)
  }

  @Builder
  private RequirementRow(text: string) {
    Row({ space: 8 }) {
      Text('·')
        .fontSize(14).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold)
      Text(text)
        .fontSize(13).fontColor(this.bodyColor)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    if (!this.visible) {
      Column().width(0).height(0)
    } else {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%').height('100%')
          .backgroundColor('rgba(0,0,0,0.45)')
          .onClick(() => { if (this.onClose) this.onClose() })

        Column({ space: 14 }) {
          Column()
            .width(44).height(5)
            .backgroundColor('#99B6C1D4')
            .borderRadius(999)
            .margin({ top: 12, bottom: 4 })

          Text('帮助补充成品图')
            .fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(this.titleColor)

          Text(`「${this.recipeName}」还没有配图。你的实拍可以帮助下一位做饭的人。`)
            .fontSize(13).fontColor(this.bodyColor)
            .lineHeight(20)
            .width('100%')

          Column({ space: 6 }) {
            this.RequirementRow('一张成品照，不要原料图或过程图')
            this.RequirementRow('横向 4:3 或 1:1，长边不少于 800px')
            this.RequirementRow('无拼接、无水印、无夸张滤镜')
            this.RequirementRow('本人拍摄，或已获得授权并注明来源')
          }
          .width('100%')
          .padding(12)
          .backgroundColor(ThemeManager.getColor('#F7F8FA', '#242424', this.themeMode))
          .borderRadius(12)

          Row({ space: 12 }) {
            Button('复制提交信息')
              .layoutWeight(1).height(46)
              .fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(AppColors.BRAND_COLOR)
              .backgroundColor(ThemeManager.getColor(AppColors.BRAND_COLOR_LIGHT, '#3A2226', this.themeMode))
              .borderRadius(23)
              .onClick(() => { void this.copyTemplate() })

            Button('去 GitHub 提交')
              .layoutWeight(1).height(46)
              .fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_COLOR)
              .borderRadius(23)
              .onClick(() => { void this.openIssue() })
          }
          .width('100%')

          Text('也可以把原图提交到仓库：content/recipe-images/scraped/orig/')
            .fontSize(11).fontColor(this.subColor)
            .textAlign(TextAlign.Center)
            .width('100%')

          Text('取消')
            .fontSize(15).fontColor(this.subColor)
            .width('100%').textAlign(TextAlign.Center)
            .padding({ top: 8, bottom: 12 })
            .onClick(() => { if (this.onClose) this.onClose() })
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 8 })
        .backgroundColor(this.cardBg)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .alignItems(HorizontalAlign.Center)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])

        if (this.toastVisible) {
          Row() {
            Text(this.toastMsg)
              .fontSize(14).fontColor(Color.White)
              .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          }
          .backgroundColor('#DD333333')
          .borderRadius(20)
          .position({ x: '50%', y: '35%' })
          .translate({ x: '-50%', y: '-50%' })
        }
      }
      .width('100%').height('100%')
    }
  }
}
