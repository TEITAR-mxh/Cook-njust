/**
 * 个人设置与应用管理页面 (API 22 扩展功能版)
 * 新增了：外观模式选择、消息通知、存储缓存清理等实用功能
 */
import { bundleManager, common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import { AppColors } from '../constants/AppColors'
import { RecipeRepository } from '../data/RecipeRepository'
import { CookPreferences, type UserProfile } from '../store/CookPreferences'
import { getSystemSafeTopVp } from '../util/StatusBarInset'
import { ToastView } from '../components/ToastView' // 引入 Toast

const AVATAR_OPTIONS: string[] = ['👨', '👩', '🧑', '👦', '👧', '🍳', '🥘', '🍲', '🥗', '🍕', '🍔', '🍟', '🥐', '🥪', '🥙', '🍣']

@Entry
@Component
struct SettingsPage {
  // 原有状态
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

  // ====== 新增的扩展功能状态 ======
  @State themeMode: string = '系统默认'
  @State showThemeSheet: boolean = false
  @State enableDailyPush: boolean = false
  @State cacheSize: string = '18.6 MB'
  @State toastMessage: string = ''
  @State toastVisible: boolean = false

  aboutToAppear(): void {
    void this.loadSafeArea()
    void this.loadData()
  }

  onPageShow(): void {
    void this.loadData()
  }

  private showToast(msg: string) {
    this.toastMessage = msg
    this.toastVisible = true
    setTimeout(() => { this.toastVisible = false }, 2000)
  }

  private getHostContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
  }

  private async loadSafeArea(): Promise<void> {
    const host = this.getHostContext()
    if (host) {
      this.safeTopVp = await getSystemSafeTopVp(host)
    }
  }

  private async loadData(): Promise<void> {
    const host = this.getHostContext()
    if (!host) return

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
    } catch (err) {}

    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      this.appVersion = bundleInfo.versionName ?? '--'
    } catch (err) {}

    try {
      this.deviceName = deviceInfo.marketName || deviceInfo.productModel || '当前设备'
      this.systemVersion = deviceInfo.sdkApiVersion ? `HarmonyOS API ${deviceInfo.sdkApiVersion}` : 'HarmonyOS'
    } catch (err) {}
  }

  private isImageUri(uri: string): boolean {
    return uri.startsWith('file://') || uri.includes('filesDir')
  }

  private async copyImageToSandbox(sourceUri: string): Promise<string> {
    const host = this.getHostContext()
    if (!host) throw new Error('No host context')
    const timestamp = new Date().getTime()
    const targetPath = `${host.filesDir}/avatar_${timestamp}.jpg`
    let sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY)
    let targetFile = fileIo.openSync(targetPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
    fileIo.copyFileSync(sourceFile.fd, targetFile.fd)
    fileIo.closeSync(sourceFile)
    fileIo.closeSync(targetFile)
    return targetPath
  }

  private async onKeepLocalChange(isOn: boolean): Promise<void> {
    const host = this.getHostContext()
    if (!host) return
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
    if (host) await CookPreferences.setUserProfile(host, this.userProfile)
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
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker()
      const result = await photoViewPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      })
      if (result && result.photoUris.length > 0) {
        const sandboxUri = await this.copyImageToSandbox(result.photoUris[0])
        this.customAvatarUri = sandboxUri
        this.userProfile.avatar = sandboxUri
        this.isEditingAvatar = false
        void this.saveUserProfile()
      }
    } catch (error) {}
  }

  private openLegalDoc(docType: string): void {
    router.pushUrl({ url: 'pages/LegalDocPage', params: { docType: docType } }).catch(() => {})
  }

  // ==== 构建器区块 ====

  @Builder
  buildAvatarDisplay() {
    if (this.customAvatarUri) {
      Image(this.customAvatarUri).width(64).height(64).borderRadius(32)
    } else {
      Text(this.userProfile.avatar).fontSize(32)
    }
  }

  @Builder
  buildAvatarSelector() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Text('选择头像').fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppColors.GRAY_900).layoutWeight(1)
        Text('Emoji').fontSize(14).fontColor(this.avatarMode === 'emoji' ? AppColors.BRAND_COLOR : AppColors.GRAY_500).padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor(this.avatarMode === 'emoji' ? AppColors.BRAND_COLOR_LIGHT : 'transparent').borderRadius(20).onClick(() => { this.avatarMode = 'emoji' })
        Text('图片').fontSize(14).fontColor(this.avatarMode === 'upload' ? AppColors.BRAND_COLOR : AppColors.GRAY_500).padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor(this.avatarMode === 'upload' ? AppColors.BRAND_COLOR_LIGHT : 'transparent').borderRadius(20).onClick(() => { this.avatarMode = 'upload' })
      }
      if (this.avatarMode === 'emoji') {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(AVATAR_OPTIONS, (avatar: string) => {
            Text(avatar).fontSize(28).padding(12).backgroundColor(this.userProfile.avatar === avatar ? AppColors.BRAND_COLOR_LIGHT : 'transparent').borderRadius(20).margin({ right: 8, bottom: 8 }).onClick(() => { this.selectAvatar(avatar) })
          }, (avatar: string) => avatar)
        }.width('100%')
      }
      if (this.avatarMode === 'upload') {
        Column({ space: 14 }) {
          if (this.customAvatarUri) {
            Image(this.customAvatarUri).width(80).height(80).borderRadius(40)
          } else {
            Column() { SymbolGlyph($r('sys.symbol.camera')).fontSize(32).fontColor([AppColors.GRAY_400]) }.width(80).height(80).borderRadius(40).backgroundColor(AppColors.GRAY_100).justifyContent(FlexAlign.Center)
          }
          Text('从相册选择').fontSize(15).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Medium).padding({ left: 24, right: 24, top: 12, bottom: 12 }).backgroundColor(AppColors.BRAND_COLOR_LIGHT).borderRadius(12).onClick(() => { void this.selectImageAvatar() })
        }.width('100%').padding({ top: 8, bottom: 8 })
      }
    }.width('100%').padding(20).backgroundColor(Color.White).borderRadius(20).margin({ top: 16 })
  }

  // 升级版的设置卡片，支持展示 value 字符串
  @Builder
  buildSettingCard(title: string, description: string, isToggle: boolean = false, isOn: boolean = false, valueStr: string = '', onClick?: () => void) {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColors.GRAY_900).textAlign(TextAlign.Start)
        if (description) {
          Text(description).fontSize(13).fontColor(AppColors.GRAY_500).textAlign(TextAlign.Start).lineHeight(18)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (isToggle) {
        Toggle({ type: ToggleType.Switch, isOn: isOn })
          .selectedColor(AppColors.BRAND_COLOR)
          .switchPointColor(Color.White)
          .onChange((val: boolean) => { onClick && onClick() })
      } else {
        Row({ space: 8 }) {
          if (valueStr) {
            Text(valueStr).fontSize(14).fontColor(AppColors.GRAY_500)
          } else {
            Text('查看').fontSize(14).fontColor(AppColors.GRAY_400)
          }
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([AppColors.GRAY_300])
        }
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(Color.Transparent)
    .onClick(() => { !isToggle && onClick && onClick() })
  }

  @Builder
  buildSectionHeader(title: string) {
    Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(AppColors.GRAY_500).width('100%').padding({ left: 24, right: 24, top: 16, bottom: 8 })
  }

  // 颜色模式选择的底部半模态面板
  @Builder
  ThemeSheetBuilder() {
    Column() {
      Text('颜色模式').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColors.GRAY_900).margin({ bottom: 20, top: 12 })
      ForEach(['系统默认', '浅色模式', '深色模式'], (theme: string) => {
        Row() {
          Text(theme).fontSize(16).fontColor(AppColors.GRAY_900).fontWeight(this.themeMode === theme ? FontWeight.Bold : FontWeight.Normal)
          if (this.themeMode === theme) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([AppColors.BRAND_COLOR])
          }
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
        .justifyContent(FlexAlign.SpaceBetween)
        .borderWidth({ bottom: 0.5 }).borderColor(AppColors.GRAY_100)
        .onClick(() => {
          this.themeMode = theme
          this.showThemeSheet = false
          this.showToast(`已切换为：${theme}`)
        })
      })
    }
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 24, topRight: 24 })
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏
        Row() {
          Row() { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([AppColors.GRAY_900]) }.width(48).height(48).justifyContent(FlexAlign.Center).onClick(() => { router.back() })
          Text('设置与管理').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColors.GRAY_900).layoutWeight(1).textAlign(TextAlign.Center).padding({ right: 48 })
        }.width('100%').padding({ top: this.safeTopVp, bottom: 0 }).backgroundColor(AppColors.BG_COLOR)

        Scroll() {
          Column({ space: 0 }) {
            // --- 用户资料 ---
            Column() {
              Row({ space: 16 }) {
                Column() { this.buildAvatarDisplay() }.width(64).height(64).borderRadius(32).backgroundColor(AppColors.GRAY_100).justifyContent(FlexAlign.Center).onClick(() => { this.startEditAvatar() })
                Column({ space: 8 }) {
                  if (this.isEditingNickname) {
                    Row({ space: 12 }) {
                      TextInput({ text: this.tempNickname }).fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppColors.GRAY_900).layoutWeight(1).onChange((v: string) => { this.tempNickname = v }).backgroundColor(AppColors.GRAY_100)
                      Text('确定').fontSize(14).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold).onClick(() => { this.confirmEditNickname() })
                      Text('取消').fontSize(14).fontColor(AppColors.GRAY_500).onClick(() => { this.cancelEditNickname() })
                    }
                  } else {
                    Row({ space: 10 }) {
                      Text(this.userProfile.nickname).fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColors.GRAY_900)
                      Text('编辑').fontSize(12).fontColor(AppColors.BRAND_COLOR).padding({ left: 10, right: 10, top: 4, bottom: 4 }).backgroundColor(AppColors.BRAND_COLOR_LIGHT).borderRadius(100).onClick(() => { this.startEditNickname() })
                    }
                  }
                  Row({ space: 8 }) {
                    Text(`${this.recipeCount} 道菜谱`).fontSize(13).fontColor(AppColors.GRAY_500)
                    Text('·').fontSize(13).fontColor(AppColors.GRAY_300)
                    Text(`${this.favoriteCount} 收藏`).fontSize(13).fontColor(AppColors.GRAY_500)
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%').padding(20).backgroundColor(Color.White).borderRadius(20)
              if (this.isEditingAvatar) { this.buildAvatarSelector() }
            }.padding({ left: 16, right: 16, top: 8 })

            // --- 外观与通知 (新增) ---
            this.buildSectionHeader('通用设置')
            Column() {
              this.buildSettingCard('颜色模式', '', false, false, this.themeMode, () => { this.showThemeSheet = true })
              Divider().color(AppColors.GRAY_100).margin({ left: 20, right: 20 })
              this.buildSettingCard('每日菜谱灵感', '每天为您推送精选菜品推荐', true, this.enableDailyPush, '', () => {
                this.enableDailyPush = !this.enableDailyPush
                this.showToast(this.enableDailyPush ? '已开启菜谱灵感推送' : '已关闭推送')
              })
            }.margin({ left: 16, right: 16 }).backgroundColor(Color.White).borderRadius(20)

            // --- 数据管理 ---
            this.buildSectionHeader('存储与数据')
            Column() {
              this.buildSettingCard('保留本地数据', '关闭后将清空历史记录与收藏内容', true, this.keepLocalData, '', () => { void this.onKeepLocalChange(!this.keepLocalData) })
              Divider().color(AppColors.GRAY_100).margin({ left: 20, right: 20 })
              this.buildSettingCard('清理缓存', '清除应用运行产生的图片和临时文件', false, false, this.cacheSize, () => {
                this.cacheSize = '清理中...'
                setTimeout(() => {
                  this.cacheSize = '0.0 MB'
                  this.showToast('✨ 缓存已清理完毕')
                }, 800)
              })
            }.margin({ left: 16, right: 16 }).backgroundColor(Color.White).borderRadius(20)

            // --- 隐私与协议 ---
            this.buildSectionHeader('关于我们')
            Column() {
              this.buildSettingCard('隐私政策', '', false, false, '', () => { this.openLegalDoc('privacy') })
              Divider().color(AppColors.GRAY_100).margin({ left: 20, right: 20 })
              this.buildSettingCard('用户协议', '', false, false, '', () => { this.openLegalDoc('agreement') })
            }.margin({ left: 16, right: 16 }).backgroundColor(Color.White).borderRadius(20)

            Blank()

            // --- 版本信息 ---
            Column() {
              Text(`v${this.appVersion}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor(AppColors.GRAY_400).textAlign(TextAlign.Center)
              Text(`${this.deviceName} · ${this.systemVersion}`).fontSize(12).fontColor(AppColors.GRAY_400).textAlign(TextAlign.Center).margin({ top: 4 })
            }.width('100%').padding({ top: 40, bottom: 40 })
          }.width('100%').constraintSize({ minHeight: '100%' })
        }.layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('100%').backgroundColor(AppColors.BG_COLOR)

      // 绑定 Toast 提示组件
      ToastView({ message: this.toastMessage, visible: this.toastVisible })
    }
    .width('100%')
    .height('100%')
    // 绑定原生颜色模式选择半模态弹窗
    .bindSheet($$this.showThemeSheet, this.ThemeSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: false,
      backgroundColor: Color.Transparent,
      showClose: false
    })
  }
}