import { common } from '@kit.AbilityKit'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { CookPreferences } from '../store/CookPreferences'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

/** 常用收藏夹名称，点选即填入，减少手动输入 */
const QUICK_NAMES: string[] = ['减脂餐', '家常菜', '宴客菜', '快手菜', '烘焙甜点', '儿童餐', '汤羹', '早餐']

@Entry
@Component
struct CreateFolderPage {
  @State folderName: string = ''
  @State topInset: number = 48
  @State saving: boolean = false
  @State focused: boolean = false

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
  @State private brandSoft: string = AppColors.BRAND_COLOR_LIGHT

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
    this.brandSoft = ThemeManager.getColor(AppColors.BRAND_COLOR_LIGHT, '#2A1215', this.storedThemeMode)
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

      // 输入区域（紧凑布局，避免大面积留白）
      Scroll() {
        Column({ space: 16 }) {
          // 标题行：图标与引导文案横向排列
          Row({ space: 12 }) {
            Column() {
              Text('📁').fontSize(22)
            }
            .width(48).height(48).borderRadius(16)
            .backgroundColor(this.brandSoft)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

            Column({ space: 3 }) {
              Text('给收藏夹起个名字')
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              Text('把喜欢的菜谱分门别类，方便查找')
                .fontSize(12).fontColor(this.secondaryColor)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          // 输入框（聚焦态品牌色描边）
          Column({ space: 6 }) {
            TextInput({ placeholder: '例如：减脂餐、家常菜、宴客菜', text: this.folderName })
              .fontSize(16)
              .fontColor(this.textColor)
              .placeholderColor(this.placeholderColor)
              .caretColor(AppColors.BRAND_COLOR)
              .backgroundColor(this.cardBg)
              .borderRadius(12)
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .maxLength(20)
              .onChange((v: string) => { this.folderName = v })
              .onFocus(() => { this.focused = true })
              .onBlur(() => { this.focused = false })
              .border({ width: 1.5, color: this.focused ? AppColors.BRAND_COLOR : this.dividerColor })
              .width('100%')

            Text(`${this.folderName.length}/20`)
              .fontSize(12)
              .fontColor(this.placeholderColor)
              .alignSelf(ItemAlign.End)
          }.width('100%')

          // 常用名称快捷填入
          Column({ space: 8 }) {
            Text('常用名称')
              .fontSize(12)
              .fontColor(this.secondaryColor)
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(QUICK_NAMES, (name: string) => {
                Text(name)
                  .fontSize(13)
                  .fontColor(this.folderName === name ? Color.White : this.textColor)
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .backgroundColor(this.folderName === name ? AppColors.BRAND_COLOR : this.cardBg)
                  .borderRadius(16)
                  .border({
                    width: 1,
                    color: this.folderName === name ? AppColors.BRAND_COLOR : this.dividerColor
                  })
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => { this.folderName = name })
              }, (name: string) => name)
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 轻量说明，替代底部空白
          Row({ space: 8 }) {
            Text('💡').fontSize(13)
            Text('收藏夹会自动同步已收藏的菜谱，之后可随时重命名或删除')
              .fontSize(11)
              .fontColor(this.secondaryColor)
              .lineHeight(17)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.cardBg)
          .borderRadius(12)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }
}
