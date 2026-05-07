import { common } from '@kit.AbilityKit'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { CookPreferences } from '../store/CookPreferences'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

@Entry
@Component
struct CreateFolderPage {
  @State folderName: string = ''
  @State topInset: number = 48
  @State saving: boolean = false

  // ── 深色模式响应式订阅 ──────────────────────────────────────────────────────
  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @State private bgColor: string = AppColors.BG_COLOR
  @State private cardBg: string = AppColors.CARD_BG
  @State private textColor: string = AppColors.GRAY_900
  @State private secondaryColor: string = AppColors.GRAY_500
  @State private dividerColor: string = AppColors.GRAY_100
  @State private placeholderColor: string = AppColors.GRAY_400

  private onThemeChange(): void {
    this.applyTheme()
  }

  private applyTheme(): void {
    this.bgColor       = ThemeManager.getBackgroundColor(this.storedThemeMode)
    this.cardBg        = ThemeManager.getCardBackgroundColor(this.storedThemeMode)
    this.textColor     = ThemeManager.getTextColor(this.storedThemeMode)
    this.secondaryColor = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
    this.dividerColor  = ThemeManager.getBorderColor(this.storedThemeMode)
    // 输入框 placeholder / 字数统计使用次级文本色
    this.placeholderColor = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
  }

  aboutToAppear(): void {
    this.applyTheme()
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (host) {
      void getSystemSafeTopVp(host).then((vp: number) => { this.topInset = vp })
    }
  }

  private async save(): Promise<void> {
    const name = this.folderName.trim()
    if (name.length === 0 || this.saving) return
    this.saving = true
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) { this.saving = false; return }
    await CookPreferences.createFolder(host, name)
    this.getUIContext().getRouter().back()
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('取消')
          .fontSize(16)
          .fontColor(this.secondaryColor)
          .padding({ left: 20, right: 16, top: 10, bottom: 10 })
          .onClick(() => this.getUIContext().getRouter().back())

        Text('新建收藏夹')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('保存')
          .fontSize(16)
          .fontColor(this.folderName.trim().length > 0 ? AppColors.BRAND_COLOR : this.placeholderColor)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 20, top: 10, bottom: 10 })
          .onClick(() => { void this.save() })
      }
      .width('100%')
      .padding({ top: this.topInset })
      .backgroundColor(this.bgColor)

      Divider().color(this.dividerColor).strokeWidth(1).margin({ top: 8 })

      // 输入区域
      Column({ space: 8 }) {
        Text('收藏夹名称')
          .fontSize(13)
          .fontColor(this.secondaryColor)
          .alignSelf(ItemAlign.Start)

        TextInput({ placeholder: '给收藏夹起个名字吧', text: this.folderName })
          .fontSize(16)
          .fontColor(this.textColor)
          .placeholderColor(this.placeholderColor)
          .caretColor(AppColors.BRAND_COLOR)
          .backgroundColor(this.cardBg)
          .borderRadius(12)
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .maxLength(20)
          .onChange((v: string) => { this.folderName = v })
          .width('100%')

        Text(`${this.folderName.length}/20`)
          .fontSize(12)
          .fontColor(this.placeholderColor)
          .alignSelf(ItemAlign.End)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }
}
