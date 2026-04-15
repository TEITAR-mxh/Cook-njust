import { bundleManager, common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import { AppColors } from '../constants/AppColors'
import { RecipeRepository } from '../data/RecipeRepository'
import { CookPreferences, type UserProfile } from '../store/CookPreferences'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

const AVATAR_OPTIONS: string[] = ['👨', '👩', '🧑', '👦', '👧', '🍳', '🥘', '🍲', '🥗', '🍕', '🍔', '🍟', '🥐', '🥪', '🥙', '🍣']

interface SettingLinkItem {
  icon: string
  title: string
  value?: string
  onClick: () => void
}

@Entry
@Component
struct SettingsPage {
  @State keepLocalData: boolean = true
  @State recipeCount: number = 0
  @State favoriteCount: number = 0
  @State historyCount: number = 0
  @State appVersion: string = '--'
  @State bundleName: string = '--'
  @State deviceName: string = '当前设备'
  @State systemVersion: string = 'HarmonyOS'
  @State safeTopVp: number = 48

  @State userProfile: UserProfile = { nickname: '美食家', avatar: '👨' }
  @State isEditingNickname: boolean = false
  @State tempNickname: string = ''
  @State isEditingAvatar: boolean = false
  @State avatarMode: 'emoji' | 'upload' = 'emoji'
  @State customAvatarUri: string = ''

  aboutToAppear(): void {
    void this.loadSafeArea()
    void this.loadData()
  }

  onPageShow(): void {
    void this.loadData()
  }

  private getHostContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
  }

  private async loadSafeArea(): Promise<void> {
    const host = this.getHostContext()
    if (!host) {
      return
    }
    this.safeTopVp = await getSystemSafeTopVp(host)
  }

  private async loadData(): Promise<void> {
    const host = this.getHostContext()
    if (!host) {
      return
    }

    try {
      this.recipeCount = RecipeRepository.getInstance().getCount()
      const settings = await CookPreferences.getSettings(host)
      const favoriteIds = await CookPreferences.getFavoriteIds(host)
      const historyIds = await CookPreferences.getHistoryIds(host)
      const profile = await CookPreferences.getUserProfile(host)

      this.keepLocalData = settings.keepLocalData
      this.favoriteCount = favoriteIds.length
      this.historyCount = historyIds.length
      this.userProfile = profile
      if (profile.avatar && this.isImageUri(profile.avatar)) {
        this.customAvatarUri = profile.avatar
      }
    } catch (err) {
      console.error('SettingsPage.loadData preference part failed', err)
    }

    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      )
      this.appVersion = bundleInfo.versionName ?? '--'
      this.bundleName = bundleInfo.name ?? '--'
    } catch (err) {
      console.error('SettingsPage.loadData bundle info failed', err)
    }

    try {
      const marketName = deviceInfo.marketName ?? ''
      const productModel = deviceInfo.productModel ?? ''
      const sdkVersion = String(deviceInfo.sdkApiVersion ?? '')
      this.deviceName = marketName.length > 0 ? marketName : (productModel.length > 0 ? productModel : '当前设备')
      this.systemVersion = sdkVersion.length > 0 ? `HarmonyOS API ${sdkVersion}` : 'HarmonyOS'
    } catch (err) {
      console.error('SettingsPage.loadData device info failed', err)
    }
  }

  private isImageUri(uri: string): boolean {
    return uri.startsWith('file://') || uri.includes('filesDir')
  }

  private async copyImageToSandbox(sourceUri: string): Promise<string> {
    const host = this.getHostContext()
    if (!host) {
      throw new Error('No host context')
    }
    const timestamp = new Date().getTime()
    const targetPath = `${host.filesDir}/avatar_${timestamp}.jpg`
    let sourceFile: fileIo.File | undefined
    let targetFile: fileIo.File | undefined
    try {
      sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY)
      targetFile = fileIo.openSync(targetPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      fileIo.copyFileSync(sourceFile.fd, targetFile.fd)
      return targetPath
    } finally {
      if (sourceFile) {
        fileIo.closeSync(sourceFile)
      }
      if (targetFile) {
        fileIo.closeSync(targetFile)
      }
    }
  }

  private async onKeepLocalChange(isOn: boolean): Promise<void> {
    const host = this.getHostContext()
    if (!host) {
      return
    }
    this.keepLocalData = isOn
    await CookPreferences.setKeepLocalData(host, isOn)
    if (!isOn) {
      await CookPreferences.clearFavorites(host)
      await CookPreferences.clearHistory(host)
      this.favoriteCount = 0
      this.historyCount = 0
    }
  }

  private async saveUserProfile(): Promise<void> {
    const host = this.getHostContext()
    if (!host) {
      return
    }
    await CookPreferences.setUserProfile(host, this.userProfile)
  }

  private startEditNickname(): void {
    this.tempNickname = this.userProfile.nickname
    this.isEditingNickname = true
  }

  private cancelEditNickname(): void {
    this.isEditingNickname = false
    this.tempNickname = ''
  }

  private confirmEditNickname(): void {
    if (this.tempNickname.trim().length > 0) {
      this.userProfile.nickname = this.tempNickname.trim()
      void this.saveUserProfile()
    }
    this.isEditingNickname = false
    this.tempNickname = ''
  }

  private startEditAvatar(): void {
    this.isEditingAvatar = true
    this.avatarMode = 'emoji'
  }

  private selectAvatar(avatar: string): void {
    this.userProfile.avatar = avatar
    this.customAvatarUri = ''
    this.isEditingAvatar = false
    void this.saveUserProfile()
  }

  private async selectImageAvatar(): Promise<void> {
    try {
      const photoSelectOptions: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
        isPhotoTakingSupported: true,
        isSearchSupported: true
      }
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker()
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions)
      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        const selectedUri = photoSelectResult.photoUris[0]
        const sandboxUri = await this.copyImageToSandbox(selectedUri)
        this.customAvatarUri = sandboxUri
        this.userProfile.avatar = sandboxUri
        this.isEditingAvatar = false
        void this.saveUserProfile()
      }
    } catch (error) {
      console.error('Photo picker error:', error)
    }
  }

  private openLegalDoc(docType: string): void {
    interface DocParams {
      docType: string
    }
    interface RouteParams {
      url: string
      params: DocParams
    }
    const routeParams: RouteParams = { url: 'pages/LegalDocPage', params: { docType: docType } }
    router.pushUrl(routeParams as router.RouterOptions).catch(() => {
      console.error('openLegalDoc failed')
    })
  }

  @Builder
  buildAvatarDisplay() {
    if (this.customAvatarUri) {
      Image(this.customAvatarUri)
        .width(56)
        .height(56)
        .borderRadius(28)
    } else {
      Text(this.userProfile.avatar)
        .fontSize(30)
    }
  }

  @Builder
  buildAvatarSelector() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Text('选择头像')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.GRAY_900)
          .layoutWeight(1)

        Text('Emoji')
          .fontSize(13)
          .fontColor(this.avatarMode === 'emoji' ? AppColors.BRAND_COLOR : AppColors.GRAY_500)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.avatarMode === 'emoji' ? AppColors.BRAND_COLOR_LIGHT : 'transparent')
          .borderRadius(16)
          .onClick(() => { this.avatarMode = 'emoji' })

        Text('图片')
          .fontSize(13)
          .fontColor(this.avatarMode === 'upload' ? AppColors.BRAND_COLOR : AppColors.GRAY_500)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.avatarMode === 'upload' ? AppColors.BRAND_COLOR_LIGHT : 'transparent')
          .borderRadius(16)
          .onClick(() => { this.avatarMode = 'upload' })
      }

      if (this.avatarMode === 'emoji') {
        Flex({
          direction: FlexDirection.Row,
          wrap: FlexWrap.Wrap,
          justifyContent: FlexAlign.Start
        }) {
          ForEach(AVATAR_OPTIONS, (avatar: string) => {
            Text(avatar)
              .fontSize(26)
              .padding(10)
              .backgroundColor(this.userProfile.avatar === avatar ? AppColors.BRAND_COLOR_LIGHT : 'transparent')
              .borderRadius(16)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.selectAvatar(avatar) })
          }, (avatar: string) => avatar)
        }
        .width('100%')
      }

      if (this.avatarMode === 'upload') {
        Column({ space: 14 }) {
          if (this.customAvatarUri) {
            Image(this.customAvatarUri)
              .width(72)
              .height(72)
              .borderRadius(36)
          } else {
            Column() {
              Text('🖼️').fontSize(28)
            }
            .width(72)
            .height(72)
            .borderRadius(36)
            .backgroundColor(AppColors.GRAY_100)
            .justifyContent(FlexAlign.Center)
          }

          Text('从相册选择')
            .fontSize(14)
            .fontColor(AppColors.BRAND_COLOR)
            .padding({ left: 20, right: 20, top: 10, bottom: 10 })
            .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
            .borderRadius(10)
            .onClick(() => { void this.selectImageAvatar() })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 20 })
    .backgroundColor(Color.White)
  }

  @Builder
  buildDivider() {
    Divider()
      .color(AppColors.GRAY_100)
      .margin({ left: 20 })
  }

  build() {
    Column() {
      // 顶部返回栏 — 动态状态栏避让
      Row() {
        Text('← 返回')
          .fontSize(16)
          .fontColor(AppColors.BRAND_COLOR)
          .padding({ top: 14, bottom: 14, right: 20 })
          .onClick(() => { router.back() })

        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.GRAY_900)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 右侧占位保持标题居中
        Text('')
          .width(60)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: this.safeTopVp, bottom: 0 })
      .backgroundColor(Color.White)
      .borderWidth({ bottom: 0.5 })
      .borderColor(AppColors.GRAY_100)

      Scroll() {
        Column({ space: 0 }) {

          // 用户信息
          Row({ space: 16 }) {
            Column() {
              this.buildAvatarDisplay()
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .backgroundColor('#FFF5EB')
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.startEditAvatar() })

            Column({ space: 6 }) {
              if (this.isEditingNickname) {
                Row({ space: 10 }) {
                  TextInput({ text: this.tempNickname })
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.GRAY_900)
                    .layoutWeight(1)
                    .onChange((v: string) => { this.tempNickname = v })

                  Text('确定')
                    .fontSize(14)
                    .fontColor(AppColors.BRAND_COLOR)
                    .onClick(() => { this.confirmEditNickname() })

                  Text('取消')
                    .fontSize(14)
                    .fontColor(AppColors.GRAY_500)
                    .onClick(() => { this.cancelEditNickname() })
                }
              } else {
                Row({ space: 8 }) {
                  Text(this.userProfile.nickname)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.GRAY_900)

                  Text('编辑')
                    .fontSize(13)
                    .fontColor(AppColors.GRAY_400)
                    .onClick(() => { this.startEditNickname() })
                }
              }

              Row({ space: 4 }) {
                Text(`${this.recipeCount} 道菜谱`)
                  .fontSize(13)
                  .fontColor(AppColors.GRAY_500)

                Text('·')
                  .fontSize(13)
                  .fontColor(AppColors.GRAY_300)

                Text(`${this.favoriteCount} 收藏`)
                  .fontSize(13)
                  .fontColor(AppColors.GRAY_500)

                Text('·')
                  .fontSize(13)
                  .fontColor(AppColors.GRAY_300)

                Text(`${this.historyCount} 浏览`)
                  .fontSize(13)
                  .fontColor(AppColors.GRAY_500)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 20 })
          .backgroundColor(Color.White)

          // 头像选择器（展开时显示）
          if (this.isEditingAvatar) {
            this.buildAvatarSelector()
          }

          Column().height(12).backgroundColor(AppColors.BG_COLOR)

          // 数据设置
          Row({ space: 12 }) {
            Column({ space: 3 }) {
              Text('保留本地数据')
                .fontSize(15)
                .fontColor(AppColors.GRAY_900)

              Text('关闭后将清空历史与收藏')
                .fontSize(12)
                .fontColor(AppColors.GRAY_500)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.keepLocalData })
              .selectedColor(AppColors.BRAND_COLOR)
              .onChange((isOn: boolean) => { void this.onKeepLocalChange(isOn) })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 16 })
          .backgroundColor(Color.White)

          Column().height(12).backgroundColor(AppColors.BG_COLOR)

          // 法律文档
          Column() {
            Row() {
              Text('隐私政策')
                .fontSize(15)
                .fontColor(AppColors.GRAY_900)
                .layoutWeight(1)

              Text('查看')
                .fontSize(13)
                .fontColor(AppColors.GRAY_400)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 16, bottom: 16 })
            .backgroundColor(Color.White)
            .onClick(() => { this.openLegalDoc('privacy') })

            this.buildDivider()

            Row() {
              Text('用户协议')
                .fontSize(15)
                .fontColor(AppColors.GRAY_900)
                .layoutWeight(1)

              Text('查看')
                .fontSize(13)
                .fontColor(AppColors.GRAY_400)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 16, bottom: 16 })
            .backgroundColor(Color.White)
            .onClick(() => { this.openLegalDoc('agreement') })
          }
          .backgroundColor(Color.White)

          // 底部版本信息
          Text(`v${this.appVersion}  ·  ${this.deviceName}  ·  ${this.systemVersion}`)
            .fontSize(12)
            .fontColor(AppColors.GRAY_400)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: 32, bottom: 48 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .backgroundColor(AppColors.BG_COLOR)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_COLOR)
  }
}
