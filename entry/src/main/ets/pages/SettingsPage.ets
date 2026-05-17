/**
 * 个人设置与应用管理页面 (API 22 扩展功能版)
 * 新增了：外观模式选择、消息通知、存储缓存清理等实用功能
 */
import { bundleManager, common, ConfigurationConstant } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import { notificationManager } from '@kit.NotificationKit'
import { AppColors, ThemeManager } from '../constants/AppColors'
import { RecipeRepository } from '../data/RecipeRepository'
import { CookPreferences, type UserProfile, type ThemeSettings } from '../store/CookPreferences'
import { getSystemSafeTopVp } from '../util/StatusBarInset'
import { ToastView } from '../components/ToastView'
import { PRIVACY_DOC, AGREEMENT_DOC, type LegalDocConfig, type LegalSection } from '../pages/LegalDocPage'
import { ReminderService } from '../service/ReminderService'

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
  /** 页内协议覆盖层 */
  @State private showLegalOverlay: boolean = false
  @State private legalOverlayDoc: LegalDocConfig = PRIVACY_DOC

  // ====== 主题响应式订阅（由 EntryAbility 写入 AppStorage，零延迟广播） ======
  /**
   * 系统深色状态：EntryAbility.onConfigurationUpdate 写入 → 此处自动触发 @Watch。
   * 仅在 themeMode === '系统默认' 时影响渲染颜色。
   */
  @StorageProp('isSystemDarkMode')
  @Watch('onSystemThemeChange')
  isSystemDark: boolean = false;

  /**
   * 用户选择的主题模式：SettingsPage.changeThemeMode 写入 → 跨页面同步（IndexV2 订阅）。
   * 初始值由 loadData 从 Preferences 覆盖。
   */
  @StorageProp('currentThemeMode')
  @Watch('onStoredThemeModeChange')
  storedThemeMode: string = '系统默认';

  // ====== 新增的扩展功能状态 ======
  @State themeMode: string = '系统默认'
  @State showThemeSheet: boolean = false
  @State enableDailyPush: boolean = false
  @State dailyPushHour: number = 8
  @State dailyPushMinute: number = 0
  @State dailyPushPreference: string = 'fridge_first'
  @State showTimePicker: boolean = false
  @State cacheSize: string = '计算中...'
  @State toastMessage: string = ''
  @State toastVisible: boolean = false
  @State currentBgColor: string = AppColors.BG_COLOR
  @State currentCardBgColor: string = AppColors.CARD_BG
  @State currentTextColor: string = AppColors.GRAY_900
  @State currentSecondaryTextColor: string = AppColors.GRAY_500
  @State currentBorderColor: string = AppColors.GRAY_100

  aboutToAppear(): void {
    void this.loadSafeArea()
    void this.loadData()
    void this.loadCacheSize()
    // 确保主题颜色正确初始化
    this.updateThemeColors()
  }

  onPageShow(): void {
    // 同步读取 AppStorage 避免 loadData 异步期间显示初始值 '系统默认'
    const liveMode = AppStorage.get<string>('currentThemeMode')
    if (liveMode !== undefined && liveMode.length > 0) {
      this.themeMode = liveMode
      this.updateThemeColors()
    }
    void this.loadData()
  }

  /**
   * 拦截系统返回键：
   * 有页内覆盖层时先关闭覆盖层，返回 true 消费事件，不触发路由 back。
   * 无覆盖层时返回 false，交由路由正常 pop SettingsPage。
   */
  onBackPress(): boolean {
    if (this.showLegalOverlay) {
      this.showLegalOverlay = false
      return true
    }
    if (this.showTimePicker) {
      this.showTimePicker = false
      return true
    }
    if (this.showThemeSheet) {
      this.showThemeSheet = false
      return true
    }
    return false
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

  /** 递归统计目录大小（字节） */
  private async calcDirSize(dir: string): Promise<number> {
    let total: number = 0
    try {
      const names = await fileIo.listFile(dir)
      for (const name of names) {
        const fullPath = `${dir}/${name}`
        try {
          const st = await fileIo.stat(fullPath)
          if (st.isDirectory()) {
            total += await this.calcDirSize(fullPath)
          } else {
            total += st.size
          }
        } catch { /* 单个文件不可读时跳过 */ }
      }
    } catch { /* 目录不可读时跳过 */ }
    return total
  }

  /** 读取并展示真实缓存大小 */
  private async loadCacheSize(): Promise<void> {
    const host = this.getHostContext()
    if (!host) { this.cacheSize = '0.0 MB'; return }
    try {
      const bytes = await this.calcDirSize(host.cacheDir)
      const mb = bytes / (1024 * 1024)
      this.cacheSize = mb < 0.05 ? '0.0 MB' : `${mb.toFixed(1)} MB`
    } catch {
      this.cacheSize = '0.0 MB'
    }
  }

  /** 递归删除目录内所有文件与子目录 */
  private async clearCacheDir(dir: string): Promise<void> {
    try {
      const names = await fileIo.listFile(dir)
      for (const name of names) {
        const fullPath = `${dir}/${name}`
        try {
          const st = await fileIo.stat(fullPath)
          if (st.isDirectory()) {
            await this.clearCacheDir(fullPath)
            await fileIo.rmdir(fullPath)
          } else {
            await fileIo.unlink(fullPath)
          }
        } catch { /* 单个条目删除失败时跳过，不影响其余文件 */ }
      }
    } catch { /* 目录不可访问时跳过 */ }
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
      const themeSettings = await CookPreferences.getThemeSettings(host)

      this.keepLocalData = settings.keepLocalData
      this.favoriteCount = favoriteIds.length
      this.historyCount = historyIds.length
      this.userProfile = profile

      // 每日推荐通知设置
      this.enableDailyPush = await CookPreferences.getDailyRecommendSwitch(host)
      this.dailyPushHour = await CookPreferences.getDailyRecommendHour(host)
      this.dailyPushMinute = await CookPreferences.getDailyRecommendMinute(host)
      this.dailyPushPreference = await CookPreferences.getDailyRecommendPreference(host)

      // 兜底：若开关已开但从未成功调度（id=0，如重装后），自动补一次调度。
      // 正常流程中调度只在用户操作时发生（开关/改时间），不在冷启动时重排，
      // 避免每次启动累积提醒触发 exceed limit 错误。
      if (this.enableDailyPush) {
        const agentId = await CookPreferences.getDailyReminderAgentId(host)
        if (agentId <= 0) {
          void ReminderService.scheduleOrUpdate(host).catch((e: Error) => {
            console.error('[SettingsPage] auto-schedule on load failed:', e.message)
          })
        }
      }

      // 主题来源优先级：
      //   1. AppStorage（当次会话中 changeThemeMode 会实时写入，最新）
      //   2. Preferences（冷启动恢复，AppStorage 尚无值时使用）
      // 避免竞态：用户刚选了深色但 Preferences 写入尚未完成时，
      // loadData 读到旧 Preferences 值覆盖新 UI 的问题。
      const liveMode = AppStorage.get<string>('currentThemeMode')
      const effectiveTheme: string = (liveMode !== undefined && liveMode.length > 0)
        ? liveMode
        : themeSettings.themeMode
      AppStorage.setOrCreate<string>('currentThemeMode', effectiveTheme)
      this.themeMode = effectiveTheme
      this.updateThemeColors()
      
      if (profile.avatar && this.isImageUri(profile.avatar)) {
        this.customAvatarUri = profile.avatar
      }
    } catch (err) {
      console.error('加载设置数据失败:', err)
    }

    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      this.appVersion = bundleInfo.versionName ?? '--'
    } catch (err) {
      console.error('获取应用版本信息失败:', err)
    }

    try {
      this.deviceName = deviceInfo.marketName || deviceInfo.productModel || '当前设备'
      this.systemVersion = deviceInfo.sdkApiVersion ? `HarmonyOS API ${deviceInfo.sdkApiVersion}` : 'HarmonyOS'
    } catch (err) {
      console.error('获取设备信息失败:', err)
    }
  }

  private isImageUri(uri: string): boolean {
    return uri.startsWith('file://') || uri.startsWith('/')
  }

  /** @Watch 回调：系统深色状态变化（仅在系统默认模式下重算颜色） */
  private onSystemThemeChange(): void {
    if (this.themeMode === '系统默认') {
      this.updateThemeColors();
    }
  }

  /** @Watch 回调：跨页面主题模式变化（IndexV2 等页面修改后推送过来） */
  private onStoredThemeModeChange(): void {
    this.themeMode = this.storedThemeMode;
    this.updateThemeColors();
  }

  private updateThemeColors(): void {
    this.currentBgColor = ThemeManager.getBackgroundColor(this.themeMode)
    this.currentCardBgColor = ThemeManager.getCardBackgroundColor(this.themeMode)
    this.currentTextColor = ThemeManager.getTextColor(this.themeMode)
    this.currentSecondaryTextColor = ThemeManager.getSecondaryTextColor(this.themeMode)
    this.currentBorderColor = ThemeManager.getBorderColor(this.themeMode)
  }

  private async changeThemeMode(newThemeMode: string): Promise<void> {
    const host = this.getHostContext()
    if (!host) return

    // 1. 立即更新本页 @State（同帧生效，无闪烁）
    this.themeMode = newThemeMode
    this.updateThemeColors()

    // 2. 写入 AppStorage → 所有订阅页面（IndexV2 等）@StorageProp 同步更新，无需定时器
    AppStorage.setOrCreate<string>('currentThemeMode', newThemeMode)

    // 3. 持久化到 Preferences（下次冷启动恢复）
    try {
      await CookPreferences.setThemeMode(host, newThemeMode)
    } catch (err) {
      console.error('保存主题设置失败:', err)
    }
  }

  private async copyImageToSandbox(sourceUri: string): Promise<string> {
    const host = this.getHostContext()
    if (!host) throw new Error('No host context')
    const targetPath = `${host.filesDir}/avatar_${Date.now()}.jpg`

    // HarmonyOS NEXT API 12+: fileIo.open 支持直接打开 datashare:// URI
    const srcFile = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY)
    try {
      await fileIo.copyFile(srcFile.fd, targetPath)
    } finally {
      await fileIo.close(srcFile.fd)
    }
    // Image() 加载本地沙箱文件必须使用 file:// 前缀，裸绝对路径不支持
    return `file://${targetPath}`
  }

  private async onKeepLocalChange(isOn: boolean): Promise<void> {
    const host = this.getHostContext()
    if (!host) return

    const previousValue: boolean = this.keepLocalData
    this.keepLocalData = isOn

    try {
      await CookPreferences.setKeepLocalData(host, isOn)
      if (!isOn) {
        await CookPreferences.clearFavorites(host)
        await CookPreferences.clearHistory(host)
        this.favoriteCount = 0
        this.historyCount = 0
      }
    } catch (e) {
      // 保存失败时回滚 UI 状态，避免开关显示与实际存储不一致
      this.keepLocalData = previousValue
      console.error('[SettingsPage] onKeepLocalChange failed:', JSON.stringify(e))
      this.showToast('设置保存失败，请重试')
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
      this.userProfile = { nickname: this.tempNickname.trim(), avatar: this.userProfile.avatar }
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
    this.userProfile = { nickname: this.userProfile.nickname, avatar: avatar }
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
        this.userProfile = { nickname: this.userProfile.nickname, avatar: sandboxUri }
        this.isEditingAvatar = false
        void this.saveUserProfile()
      }
    } catch (error) {
      console.error('选择图片失败:', error)
      this.showToast('图片选择失败，请重试')
    }
  }

  private openLegalDoc(docType: string): void {
    this.legalOverlayDoc = docType === 'agreement' ? AGREEMENT_DOC : PRIVACY_DOC
    this.showLegalOverlay = true
  }

  // ==== 构建器区块 ====

  @Builder
  buildAvatarDisplay() {
    if (this.customAvatarUri) {
      Image(this.customAvatarUri)
        .width(64).height(64).borderRadius(32)
        .onError(() => { console.error(`头像加载失败: ${this.customAvatarUri}`) })
    } else {
      Text(this.userProfile.avatar).fontSize(32)
    }
  }

  @Builder
  buildAvatarSelector() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Text('选择头像').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor).layoutWeight(1)
        Text('Emoji').fontSize(14).fontColor(this.avatarMode === 'emoji' ? AppColors.BRAND_COLOR : this.currentSecondaryTextColor).padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor(this.avatarMode === 'emoji' ? AppColors.BRAND_COLOR_LIGHT : 'transparent').borderRadius(20).onClick(() => { this.avatarMode = 'emoji' })
        Text('图片').fontSize(14).fontColor(this.avatarMode === 'upload' ? AppColors.BRAND_COLOR : this.currentSecondaryTextColor).padding({ left: 16, right: 16, top: 8, bottom: 8 }).backgroundColor(this.avatarMode === 'upload' ? AppColors.BRAND_COLOR_LIGHT : 'transparent').borderRadius(20).onClick(() => { this.avatarMode = 'upload' })
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
            Column() { SymbolGlyph($r('sys.symbol.camera')).fontSize(32).fontColor([this.currentSecondaryTextColor]) }.width(80).height(80).borderRadius(40).backgroundColor(this.currentBorderColor).justifyContent(FlexAlign.Center)
          }
          Text('从相册选择').fontSize(15).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Medium).padding({ left: 24, right: 24, top: 12, bottom: 12 }).backgroundColor(AppColors.BRAND_COLOR_LIGHT).borderRadius(12).onClick(() => { void this.selectImageAvatar() })
        }.width('100%').padding({ top: 8, bottom: 8 })
      }
    }.width('100%').padding(20).backgroundColor(this.currentCardBgColor).borderRadius(20).margin({ top: 16 })
  }

  // 升级版的设置卡片，支持展示 value 字符串
  @Builder
  buildSettingCard(title: string, description: string, isToggle: boolean = false, isOn: boolean = false, valueStr: string = '', onClick?: () => void) {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.currentTextColor).textAlign(TextAlign.Start)
        if (description) {
          Text(description).fontSize(13).fontColor(this.currentSecondaryTextColor).textAlign(TextAlign.Start).lineHeight(18)
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
            Text(valueStr).fontSize(14).fontColor(this.currentSecondaryTextColor)
          } else {
            Text('查看').fontSize(14).fontColor(this.currentSecondaryTextColor)
          }
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([this.currentSecondaryTextColor])
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
    Text(title).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.currentSecondaryTextColor).width('100%').padding({ left: 24, right: 24, top: 16, bottom: 8 })
  }

  // 颜色模式选择面板内容（页面内渲染，不使用 bindSheet 避免 window overlay 污染）
  @Builder
  ThemeSheetContent() {
    Column() {
      // 拖拽指示条
      Column()
        .width(36).height(4)
        .backgroundColor(this.currentBorderColor)
        .borderRadius(2)
        .margin({ top: 10, bottom: 16 })

      Text('颜色模式').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor).margin({ bottom: 4 })

      ForEach(['系统默认', '浅色模式', '深色模式'], (theme: string) => {
        Row() {
          Text(theme)
            .fontSize(16)
            .fontColor(this.currentTextColor)
            .fontWeight(this.themeMode === theme ? FontWeight.Bold : FontWeight.Normal)
          if (this.themeMode === theme) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([AppColors.BRAND_COLOR])
          }
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
        .justifyContent(FlexAlign.SpaceBetween)
        .borderWidth({ bottom: 0.5 }).borderColor(this.currentBorderColor)
        .onClick(() => {
          void this.changeThemeMode(theme)
          this.showThemeSheet = false
          this.showToast(`已切换为：${theme}`)
        })
      })
    }
    .width('100%')
    .padding({ left: 24, right: 24, bottom: 32 })
    .backgroundColor(this.currentCardBgColor)
    .borderRadius({ topLeft: 24, topRight: 24 })
  }

  // ── 页内全屏协议覆盖层 ────────────────────────────────────────────────────
  @Builder
  LegalOverlay() {
    Column() {
      // 导航栏
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22).fontColor([this.currentTextColor])
        }
        .width(48).height(48).justifyContent(FlexAlign.Center)
        .onClick(() => { this.showLegalOverlay = false })

        Text(this.legalOverlayDoc.title)
          .fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.currentTextColor)
          .layoutWeight(1).textAlign(TextAlign.Center)

        Blank().width(48)
      }
      .width('100%')
      .height(this.safeTopVp + 44)
      .padding({ top: this.safeTopVp, left: 4, right: 4 })
      .backgroundColor(this.currentCardBgColor)
      .border({ width: { bottom: 0.5 }, color: this.currentBorderColor })

      Scroll() {
        Column({ space: 0 }) {
          // Banner：图标 + 标题 + 日期 + 摘要
          Column({ space: 14 }) {
            Row({ space: 14 }) {
              Column() {
                Text(this.legalOverlayDoc.icon).fontSize(28)
              }
              .width(54).height(54).borderRadius(14)
              .backgroundColor(
                this.legalOverlayDoc.type === 'agreement'
                  ? (this.currentBgColor === AppColors.DARK_BG_COLOR ? '#1A2A4A' : '#EFF6FF')
                  : (this.currentBgColor === AppColors.DARK_BG_COLOR ? '#2A1215' : '#FFF0F1')
              )
              .justifyContent(FlexAlign.Center).flexShrink(0)

              Column({ space: 5 }) {
                Text(this.legalOverlayDoc.title)
                  .fontSize(26).fontWeight(FontWeight.Bold)
                  .fontColor(this.currentTextColor)
                Text(this.legalOverlayDoc.effectiveDate)
                  .fontSize(12).fontColor(this.currentSecondaryTextColor)
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)
            }
            .width('100%').alignItems(VerticalAlign.Center)

            Text(this.legalOverlayDoc.subtitle)
              .fontSize(13).fontColor(this.currentSecondaryTextColor)
              .lineHeight(21).maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .width('100%').alignItems(HorizontalAlign.Start)
          .padding({ left: 24, right: 24, top: 24, bottom: 22 })
          .backgroundColor(this.currentCardBgColor)

          Divider().color(this.currentBorderColor)

          // 条款列表
          Column({ space: 0 }) {
            ForEach(
              this.legalOverlayDoc.sections,
              (section: LegalSection, index: number) => {
                Column({ space: 0 }) {
                  Column({ space: 12 }) {
                    Row({ space: 10 }) {
                      Column()
                        .width(3).height(17)
                        .backgroundColor(
                          this.legalOverlayDoc.type === 'agreement' ? '#2563EB' : AppColors.BRAND_COLOR
                        )
                        .borderRadius(2).flexShrink(0)
                      Text(section.heading)
                        .fontSize(15).fontWeight(FontWeight.Medium)
                        .fontColor(this.currentTextColor).layoutWeight(1)
                    }
                    .width('100%').alignItems(VerticalAlign.Center)

                    Text(section.body)
                      .fontSize(14).fontColor(this.currentSecondaryTextColor)
                      .lineHeight(26).width('100%')
                  }
                  .width('100%')
                  .padding({ left: 24, right: 24, top: 20, bottom: 22 })
                  .backgroundColor(this.currentCardBgColor)

                  if (index < this.legalOverlayDoc.sections.length - 1) {
                    Divider().color(this.currentBorderColor).padding({ left: 24 })
                  }
                }
              },
              (section: LegalSection) => section.heading
            )
          }
          .width('100%').margin({ top: 8, bottom: 8 })

          // 页脚
          Column({ space: 8 }) {
            Divider().color(this.currentBorderColor)
            Text(this.legalOverlayDoc.footer)
              .fontSize(12).fontColor(this.currentSecondaryTextColor)
              .textAlign(TextAlign.Center).width('100%').padding({ top: 4 })
          }
          .width('100%')
          .padding({ top: 16, bottom: 48, left: 24, right: 24 })
        }
        .width('100%')
      }
      .layoutWeight(1).scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
    .backgroundColor(this.currentBgColor)
    .transition(
      TransitionEffect.translate({ x: '100%' })
        .animation({ duration: 300, curve: Curve.EaseOut })
    )
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏
        Row() {
          Row() { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([this.currentTextColor]) }.width(48).height(48).justifyContent(FlexAlign.Center).onClick(() => { 
          try {
            const routerInstance = this.getUIContext().getRouter()
            routerInstance.back()
          } catch (error) {
            console.error('返回页面失败:', error)
          }
        })
          Text('设置与管理').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor).layoutWeight(1).textAlign(TextAlign.Center).padding({ right: 48 })
        }.width('100%').padding({ top: this.safeTopVp, bottom: 0 }).backgroundColor(this.currentBgColor)

        Scroll() {
          Column({ space: 0 }) {
            // --- 用户资料 ---
            Column() {
              Row({ space: 16 }) {
                Column() { this.buildAvatarDisplay() }.width(64).height(64).borderRadius(32).backgroundColor(this.currentBorderColor).justifyContent(FlexAlign.Center).onClick(() => { this.startEditAvatar() })
                Column({ space: 8 }) {
                  if (this.isEditingNickname) {
                    Row({ space: 12 }) {
                      TextInput({ text: this.tempNickname }).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor).layoutWeight(1).onChange((v: string) => { this.tempNickname = v }).backgroundColor(this.currentBorderColor)
                      Text('确定').fontSize(14).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold).onClick(() => { this.confirmEditNickname() })
                      Text('取消').fontSize(14).fontColor(this.currentSecondaryTextColor).onClick(() => { this.cancelEditNickname() })
                    }
                  } else {
                    Row({ space: 10 }) {
                      Text(this.userProfile.nickname).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.currentTextColor)
                      Text('编辑').fontSize(12).fontColor(AppColors.BRAND_COLOR).padding({ left: 10, right: 10, top: 4, bottom: 4 }).backgroundColor(AppColors.BRAND_COLOR_LIGHT).borderRadius(100).onClick(() => { this.startEditNickname() })
                    }
                  }
                  Row({ space: 8 }) {
                    Text(`${this.recipeCount} 道菜谱`).fontSize(13).fontColor(this.currentSecondaryTextColor)
                    Text('·').fontSize(13).fontColor(this.currentSecondaryTextColor)
                    Text(`${this.favoriteCount} 收藏`).fontSize(13).fontColor(this.currentSecondaryTextColor)
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%').padding(20).backgroundColor(this.currentCardBgColor).borderRadius(20)
              if (this.isEditingAvatar) { this.buildAvatarSelector() }
            }.padding({ left: 16, right: 16, top: 8 })

            // --- 外观与通知 (新增) ---
            this.buildSectionHeader('通用设置')
            Column() {
              this.buildSettingCard('颜色模式', '', false, false, this.themeMode, () => { this.showThemeSheet = true })
            }.margin({ left: 16, right: 16 }).backgroundColor(this.currentCardBgColor).borderRadius(20)

            // --- 每日推荐通知 ---
            this.buildSectionHeader('🔔 每日推荐通知')
            Column() {
              // 开关行
              Row({ space: 16 }) {
                Column({ space: 4 }) {
                  Text('每日菜谱灵感').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.currentTextColor)
                  Text('在您设定的时间推送今日精选菜谱').fontSize(13).fontColor(this.currentSecondaryTextColor)
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.enableDailyPush })
                  .selectedColor(AppColors.BRAND_COLOR)
                  .switchPointColor(Color.White)
                  .onChange((val: boolean) => {
                    this.enableDailyPush = val
                    const host = this.getHostContext()
                    if (!host) return

                    if (!val) {
                      // 关闭：直接取消提醒，无需检查权限
                      void CookPreferences.setDailyRecommendSwitch(host, false)
                        .then(() => ReminderService.cancel(host))
                        .then(() => { this.showToast('🔕 每日推荐已关闭') })
                        .catch(() => { this.showToast('设置失败，请重试') })
                      return
                    }

                    // 开启：先申请系统通知权限，再持久化开关，最后 fire-and-forget 调度提醒。
                    // 关键设计：scheduleOrUpdate 与权限链隔离，
                    // 其失败（publishReminder 限额、bundle 名不符等）不会触发外层 catch，
                    // 避免开关被错误回滚。
                    void notificationManager.isNotificationEnabled()
                      .then((enabled: boolean) => {
                        if (!enabled) {
                          // 弹出系统授权弹窗；用户拒绝时此 Promise reject → 进入外层 catch
                          return notificationManager.requestEnableNotification(host)
                        }
                        return Promise.resolve()
                      })
                      .then(() => CookPreferences.setDailyRecommendSwitch(host, true))
                      .then(() => {
                        this.showToast('✅ 每日推荐已开启')
                        // 独立 fire-and-forget：调度失败不影响开关状态，但将错误提示给用户
                        void ReminderService.scheduleOrUpdate(host).catch((e: Error) => {
                          console.error('[SettingsPage] reminder schedule failed:', e.message)
                          this.showToast(`提醒设置失败 ${e.message}`)
                        })
                      })
                      .catch(() => {
                        // 只有通知权限被拒时才回滚开关
                        this.enableDailyPush = false
                        void CookPreferences.setDailyRecommendSwitch(host, false)
                        this.showToast('请在系统设置中开启通知权限')
                      })
                  })
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 16, bottom: 16 })

              if (this.enableDailyPush) {
                Divider().color(this.currentBorderColor).margin({ left: 20, right: 20 })

                // 推送时间
                Row({ space: 16 }) {
                  Text('推送时间').fontSize(16).fontColor(this.currentTextColor).layoutWeight(1)
                  Row({ space: 6 }) {
                    Text(`${this.dailyPushHour.toString().padStart(2, '0')}:${this.dailyPushMinute.toString().padStart(2, '0')}`)
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor(AppColors.BRAND_COLOR)
                    SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([this.currentSecondaryTextColor])
                  }
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 14, bottom: 14 })
                .onClick(() => { this.showTimePicker = true })

                Divider().color(this.currentBorderColor).margin({ left: 20, right: 20 })

                // 推荐偏好
                Row({ space: 16 }) {
                  Column({ space: 4 }) {
                    Text('推荐偏好').fontSize(16).fontColor(this.currentTextColor)
                    Text(this.dailyPushPreference === 'fridge_first' ? '优先使用冰箱食材' : '精选质量菜谱随机')
                      .fontSize(13).fontColor(this.currentSecondaryTextColor)
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)

                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([this.currentSecondaryTextColor])
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 14, bottom: 14 })
                .onClick(() => {
                  const newPref = this.dailyPushPreference === 'fridge_first' ? 'random_quality' : 'fridge_first'
                  this.dailyPushPreference = newPref
                  const host = this.getHostContext()
                  if (!host) return
                  void CookPreferences.setDailyRecommendPreference(host, newPref).then(() => {
                    const label = newPref === 'fridge_first' ? '冰箱优先' : '随机精选'
                    this.showToast(`推荐偏好已切换为：${label}`)
                  })
                })

              }
            }.margin({ left: 16, right: 16 }).backgroundColor(this.currentCardBgColor).borderRadius(20)

            // --- 数据管理 ---
            this.buildSectionHeader('存储与数据')
            Column() {
              this.buildSettingCard('保留本地数据', '关闭后将清空历史记录与收藏内容', true, this.keepLocalData, '', () => { void this.onKeepLocalChange(!this.keepLocalData) })
              Divider().color(this.currentBorderColor).margin({ left: 20, right: 20 })
              this.buildSettingCard('清理缓存', '清除应用运行产生的图片和临时文件', false, false, this.cacheSize, () => {
                this.getUIContext().showAlertDialog({
                  title: '清理缓存',
                  message: `当前缓存 ${this.cacheSize}，清理后临时文件将被删除，不影响收藏和历史记录。`,
                  primaryButton: { value: '取消', action: () => {} },
                  secondaryButton: {
                    value: '立即清理',
                    fontColor: AppColors.BRAND_COLOR,
                    action: () => {
                      const host = this.getHostContext()
                      if (!host) return
                      this.cacheSize = '清理中...'
                      void this.clearCacheDir(host.cacheDir)
                        .then(async () => {
                          await this.loadCacheSize()
                          this.showToast('✨ 缓存已清理完毕')
                        })
                        .catch(async () => {
                          await this.loadCacheSize()
                          this.showToast('清理失败，请重试')
                        })
                    }
                  },
                  autoCancel: true
                })
              })
            }.margin({ left: 16, right: 16 }).backgroundColor(this.currentCardBgColor).borderRadius(20)

            // --- 隐私与协议 ---
            this.buildSectionHeader('关于我们')
            Column() {
              this.buildSettingCard('隐私政策', '', false, false, '', () => { this.openLegalDoc('privacy') })
              Divider().color(this.currentBorderColor).margin({ left: 20, right: 20 })
              this.buildSettingCard('用户协议', '', false, false, '', () => { this.openLegalDoc('agreement') })
            }.margin({ left: 16, right: 16 }).backgroundColor(this.currentCardBgColor).borderRadius(20)

            Blank()

            // --- 版本信息 ---
            Column() {
              Text(`v${this.appVersion}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.currentSecondaryTextColor).textAlign(TextAlign.Center)
              Text(`${this.deviceName} · ${this.systemVersion}`).fontSize(12).fontColor(this.currentSecondaryTextColor).textAlign(TextAlign.Center).margin({ top: 4 })
            }.width('100%').padding({ top: 40, bottom: 40 })
          }.width('100%').constraintSize({ minHeight: '100%' })
        }.layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('100%').backgroundColor(this.currentBgColor)

      // 时间选择面板（页面内覆盖层）
      if (this.showTimePicker) {
        Column()
          .width('100%').height('100%')
          .backgroundColor('rgba(0,0,0,0.45)')
          .onClick(() => { this.showTimePicker = false })

        Column({ space: 0 }) {
          Column()
            .width(36).height(4)
            .backgroundColor(this.currentBorderColor)
            .borderRadius(2)
            .margin({ top: 10, bottom: 8 })

          Text('推送时间')
            .fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(this.currentTextColor)
            .margin({ bottom: 4 })

          TimePicker({ selected: new Date(2000, 0, 1, this.dailyPushHour, this.dailyPushMinute) })
            .useMilitaryTime(true)
            .onChange((val: TimePickerResult) => {
              this.dailyPushHour = val.hour
              this.dailyPushMinute = val.minute
            })
            .width('100%')

          Button('确定')
            .width('100%').height(48)
            .fontSize(16).fontWeight(FontWeight.Medium)
            .backgroundColor(AppColors.BRAND_COLOR).fontColor(Color.White)
            .borderRadius(12)
            .margin({ top: 8, left: 20, right: 20, bottom: 32 })
            .onClick(() => {
              this.showTimePicker = false
              const host = this.getHostContext()
              if (!host) return
              // 保存时间偏好（核心操作）与重新调度提醒（fire-and-forget）分离：
              // scheduleOrUpdate 失败不影响时间保存的成功提示。
              void CookPreferences.setDailyRecommendHour(host, this.dailyPushHour)
                .then(() => CookPreferences.setDailyRecommendMinute(host, this.dailyPushMinute))
                .then(() => {
                  const h = this.dailyPushHour.toString().padStart(2, '0')
                  const m = this.dailyPushMinute.toString().padStart(2, '0')
                  this.showToast(`推送时间已设为 ${h}:${m}`)
                  void ReminderService.scheduleOrUpdate(host).catch((e: Error) => {
                    console.error('[SettingsPage] reschedule after time change failed:', e.message)
                    this.showToast(`提醒更新失败 ${e.message}`)
                  })
                })
                .catch(() => {
                  this.showToast('保存失败，请重试')
                })
            })
        }
        .width('100%')
        .backgroundColor(this.currentCardBgColor)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .alignSelf(ItemAlign.End)
      }

      // 颜色模式选择面板（页面内覆盖层，不使用 bindSheet）
      if (this.showThemeSheet) {
        // 半透明蒙层，点击关闭
        Column()
          .width('100%').height('100%')
          .backgroundColor('rgba(0,0,0,0.45)')
          .onClick(() => { this.showThemeSheet = false })

        // 面板内容，固定在底部
        Column() {
          this.ThemeSheetContent()
        }
        .width('100%')
        .alignSelf(ItemAlign.End)
      }

      // 协议全屏覆盖层（在 Stack 内渲染，不产生新路由层）
      if (this.showLegalOverlay) {
        this.LegalOverlay()
      }

      // Toast 始终在最上层
      ToastView({ message: this.toastMessage, visible: this.toastVisible })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
  }

  // SettingsPage 不定义 pageTransition，保持静止作为背景层
  // LegalDocPage 负责独立滑入滑出，避免两层同时动造成"双页"视觉
}