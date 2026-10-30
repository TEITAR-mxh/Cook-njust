import { AppColors, ThemeManager } from '../constants/AppColors'
import { FolderItem } from '../store/CookPreferences'

// ══════════════════════════════════════════════════════════════════════════════
// 新建收藏夹弹窗
// 说明：收藏夹选择器是底部自定义面板，输入框若放在面板内，键盘弹出时整个面板
// 会被系统上推，输入区在列表中位置漂移、容易被键盘遮挡。改为独立弹窗：
// 弹窗由系统负责键盘避让，且只移动自身，面板不会跳动；输入框自动获焦。
// ══════════════════════════════════════════════════════════════════════════════

@CustomDialog
struct CreateFolderDialog {
  controller?: CustomDialogController
  onCreate: (name: string) => void = () => {}

  @State private name: string = ''
  @State private focused: boolean = false

  @StorageProp('currentThemeMode')
  themeMode: string = '系统默认'
  @StorageProp('isSystemDarkMode')
  isSystemDark: boolean = false

  private getBg(): string {
    return ThemeManager.getColor(AppColors.CARD_BG, AppColors.DARK_CARD_BG, this.themeMode)
  }
  private getTextColor(): string {
    return ThemeManager.getColor(AppColors.GRAY_800, AppColors.DARK_GRAY_900, this.themeMode)
  }
  private getSecondaryText(): string {
    return ThemeManager.getColor(AppColors.GRAY_400, AppColors.DARK_GRAY_500, this.themeMode)
  }
  private getInputBg(): string {
    return ThemeManager.getColor(AppColors.GRAY_50, AppColors.DARK_GRAY_50, this.themeMode)
  }
  private getBorderColor(): string {
    return this.focused
      ? AppColors.BRAND_COLOR
      : ThemeManager.getColor(AppColors.GRAY_100, AppColors.DARK_GRAY_100, this.themeMode)
  }
  private getCancelBg(): string {
    return ThemeManager.getColor(AppColors.GRAY_100, AppColors.DARK_GRAY_200, this.themeMode)
  }
  private getCancelText(): string {
    return ThemeManager.getColor(AppColors.GRAY_500, AppColors.DARK_GRAY_500, this.themeMode)
  }

  private focusInput(): void {
    try {
      this.getUIContext().getFocusController().requestFocus('createFolderNameInput')
    } catch (e) {
      console.error(`[CreateFolderDialog] requestFocus failed: ${e}`)
    }
  }

  private submit(): void {
    const name = this.name.trim()
    if (name.length === 0) return
    this.controller?.close()
    this.onCreate(name)
  }

  build() {
    Column({ space: 0 }) {
      Text('新建收藏夹')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getTextColor())
        .margin({ bottom: 6 })

      Text('创建后会同时把这本菜谱加入其中')
        .fontSize(12)
        .fontColor(this.getSecondaryText())
        .margin({ bottom: 16 })

      TextInput({ placeholder: '例如：减脂餐、家常菜', text: this.name })
        .id('createFolderNameInput')
        .width('100%')
        .height(46)
        .fontSize(16)
        .fontColor(this.getTextColor())
        .placeholderColor(this.getSecondaryText())
        .caretColor(AppColors.BRAND_COLOR)
        .backgroundColor(this.getInputBg())
        .borderRadius(12)
        .padding({ left: 14, right: 14 })
        .maxLength(20)
        .enterKeyType(EnterKeyType.Done)
        .border({ width: 1.5, color: this.getBorderColor() })
        .onChange((v: string) => { this.name = v })
        .onSubmit(() => { this.submit() })
        .onFocus(() => { this.focused = true })
        .onBlur(() => { this.focused = false })
        .onAppear(() => { setTimeout(() => this.focusInput(), 160) })

      Text(`${this.name.length}/20`)
        .fontSize(11)
        .fontColor(this.getSecondaryText())
        .alignSelf(ItemAlign.End)
        .margin({ top: 6 })

      Row({ space: 10 }) {
        Text('取消')
          .fontSize(15)
          .fontColor(this.getCancelText())
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.getCancelBg())
          .borderRadius(12)
          .onClick(() => { this.controller?.close() })

        Text('创建并加入')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppColors.BRAND_COLOR)
          .borderRadius(12)
          .opacity(this.name.trim().length > 0 ? 1 : 0.4)
          .enabled(this.name.trim().length > 0)
          .animation({ duration: 160, curve: Curve.EaseOut })
          .onClick(() => { this.submit() })
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .width('86%')
    .padding({ left: 22, right: 22, top: 24, bottom: 22 })
    .backgroundColor(this.getBg())
    .borderRadius(20)
    .shadow({ radius: 40, color: '#00000026', offsetX: 0, offsetY: 12 })
  }
}

@Component
export struct FolderPickerSheet {
  @Prop folders: FolderItem[] = []
  onAddToFolder?: (folderId: string) => void
  onCreateAndAdd?: (name: string) => void
  onClose?: () => void

  /** 主题响应式订阅 */
  @StorageProp('currentThemeMode')
  themeMode: string = '系统默认'
  @StorageProp('isSystemDarkMode')
  isSystemDark: boolean = false

  private createDialogController: CustomDialogController = new CustomDialogController({
    builder: CreateFolderDialog({
      onCreate: (name: string) => {
        if (this.onCreateAndAdd) this.onCreateAndAdd(name)
      }
    }),
    autoCancel: true,
    customStyle: true,
    // 键盘弹出时由弹窗自身避让，不让底部面板跟着页面上移
    keyboardAvoidMode: KeyboardAvoidMode.DEFAULT
  })

  /** 获取当前主题下的自适应背景色 */
  private getSheetBg(): string {
    return ThemeManager.getColor(AppColors.CARD_BG, AppColors.DARK_CARD_BG, this.themeMode)
  }
  private getTextColor(): string {
    return ThemeManager.getColor(AppColors.GRAY_800, AppColors.DARK_GRAY_900, this.themeMode)
  }
  private getSecondaryText(): string {
    return ThemeManager.getColor(AppColors.GRAY_400, AppColors.DARK_GRAY_500, this.themeMode)
  }
  private getDividerColor(): string {
    return ThemeManager.getColor(AppColors.GRAY_100, AppColors.DARK_GRAY_100, this.themeMode)
  }

  build() {
    Column({ space: 0 }) {
      // 标题栏
      Row() {
        Text('加入收藏夹')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getTextColor())
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('✕')
          .fontSize(18)
          .fontColor(this.getSecondaryText())
          .padding(8)
          .onClick(() => { if (this.onClose) this.onClose() })
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 20, bottom: 12 })

      Divider().color(this.getDividerColor()).strokeWidth(1)

      // 收藏夹列表
      Scroll() {
        Column({ space: 0 }) {
          if (this.folders.length === 0) {
            Column({ space: 8 }) {
              Text('📂').fontSize(40)
              Text('还没有收藏夹').fontSize(14).fontColor(this.getSecondaryText())
            }
            .width('100%')
            .padding({ top: 32, bottom: 32 })
            .justifyContent(FlexAlign.Center)
          }

          ForEach(this.folders, (folder: FolderItem) => {
            Row({ space: 12 }) {
              Text('📁').fontSize(28)
              Column({ space: 2 }) {
                Text(folder.name)
                  .fontSize(15)
                  .fontColor(this.getTextColor())
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${folder.recipeIds.length} 道菜`)
                  .fontSize(12)
                  .fontColor(this.getSecondaryText())
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)

              Text('›').fontSize(18).fontColor(this.getSecondaryText())
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .onClick(() => {
              if (this.onAddToFolder) this.onAddToFolder(folder.id)
            })

            Divider().color(this.getDividerColor()).strokeWidth(1).margin({ left: 72 })
          }, (f: FolderItem) => f.id)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部：新建收藏夹（打开独立弹窗输入）
      Column() {
        Divider().color(this.getDividerColor()).strokeWidth(1)
        Row({ space: 8 }) {
          Text('+').fontSize(18).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold)
          Text('新建收藏夹').fontSize(15).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 16, bottom: 16 })
        .onClick(() => { this.createDialogController.open() })
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getSheetBg())
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}
