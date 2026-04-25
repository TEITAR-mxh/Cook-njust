import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { CookPreferences } from '../store/CookPreferences'
import { AppColors } from '../constants/AppColors'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

@Entry
@Component
struct CreateFolderPage {
  @State folderName: string = ''
  @State topInset: number = 48
  @State saving: boolean = false

  aboutToAppear() {
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
          .fontColor(AppColors.GRAY_600)
          .padding({ left: 20, right: 16, top: 10, bottom: 10 })
          .onClick(() => this.getUIContext().getRouter().back())

        Text('新建收藏夹')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.GRAY_900)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('保存')
          .fontSize(16)
          .fontColor(this.folderName.trim().length > 0 ? AppColors.BRAND_COLOR : AppColors.GRAY_400)
          .fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 20, top: 10, bottom: 10 })
          .onClick(() => { void this.save() })
      }
      .width('100%')
      .padding({ top: this.topInset })

      Divider().color(AppColors.GRAY_100).strokeWidth(1).margin({ top: 8 })

      // 输入区域
      Column({ space: 8 }) {
        Text('收藏夹名称')
          .fontSize(13)
          .fontColor(AppColors.GRAY_500)
          .alignSelf(ItemAlign.Start)

        TextInput({ placeholder: '给收藏夹起个名字吧', text: this.folderName })
          .fontSize(16)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(12)
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .maxLength(20)
          .onChange((v: string) => { this.folderName = v })
          .width('100%')

        Text(`${this.folderName.length}/20`)
          .fontSize(12)
          .fontColor(AppColors.GRAY_400)
          .alignSelf(ItemAlign.End)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_COLOR)
  }
}
