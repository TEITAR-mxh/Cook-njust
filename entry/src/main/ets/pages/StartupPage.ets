import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { AppColors } from '../constants/AppColors'
import { CookPreferences } from '../store/CookPreferences'

@CustomDialog
struct PrivacyConsentDialog {
  controller?: CustomDialogController
  onAgree: () => void = () => {}
  onReject: () => void = () => {}
  onOpenPrivacy: () => void = () => {}
  onOpenAgreement: () => void = () => {}

  build() {
    Column({ space: 16 }) {
      Text('欢迎使用 AUV 您吃了么')
        .fontSize(22)
        .fontWeight(FontWeight.Bolder)
        .fontColor(AppColors.GRAY_900)

      Text('为保障你的知情权，请先阅读《隐私政策》和《用户协议》。同意后方可继续使用应用。')
        .fontSize(14)
        .fontColor(AppColors.GRAY_600)
        .lineHeight(22)

      Row({ space: 8 }) {
        Text('《隐私政策》')
          .fontSize(14)
          .fontColor(AppColors.BRAND_COLOR)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.onOpenPrivacy()
          })

        Text('《用户协议》')
          .fontSize(14)
          .fontColor(AppColors.BRAND_COLOR)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.onOpenAgreement()
          })
      }

      Row({ space: 12 }) {
        Button('拒绝并退出')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(AppColors.GRAY_600)
          .backgroundColor('#F3F4F6')
          .borderRadius(14)
          .onClick(() => {
            this.onReject()
          })

        Button('同意并进入')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(AppColors.BRAND_COLOR)
          .borderRadius(14)
          .onClick(() => {
            this.onAgree()
          })
      }
      .width('100%')
    }
    .padding(24)
    .width('86%')
    .backgroundColor(Color.White)
    .borderRadius(24)
  }
}

@Entry
@Component
struct StartupPage {
  @State statusText: string = '正在准备数据...'
  @State hasRouted: boolean = false

  // Entry animation states
  @State logoScale: number = 0.68
  @State logoOpacity: number = 0
  @State subtitleOpacity: number = 0
  @State subtitleOffsetY: number = 22
  @State statusOpacity: number = 0
  @State decoOpacity: number = 0

  // Exit animation states
  @State exitOpacity: number = 1
  @State exitScale: number = 1

  /** 开机画面最短停留时长（ms），保证动画完整播放 */
  private static readonly MIN_DISPLAY_MS: number = 1800
  private startTime: number = 0

  private privacyDialogController: CustomDialogController = new CustomDialogController({
    builder: PrivacyConsentDialog({
      onAgree: () => {
        void this.acceptPrivacy()
      },
      onReject: () => {
        this.rejectPrivacy()
      },
      onOpenPrivacy: () => {
        router.pushUrl({ url: 'pages/LegalDocPage', params: { docType: 'privacy' } })
      },
      onOpenAgreement: () => {
        router.pushUrl({ url: 'pages/LegalDocPage', params: { docType: 'agreement' } })
      }
    }),
    autoCancel: false,
    customStyle: true
  })

  aboutToAppear(): void {
    this.startTime = Date.now()
    this.runEntryAnimation()
    void this.bootstrap()
  }

  /** 入场动画：背景装饰 → logo 弹入 → 副标题上滑 → 状态行淡入 */
  private runEntryAnimation(): void {
    // 背景装饰圆缓入
    animateTo({ duration: 1200, curve: Curve.EaseOut }, () => {
      this.decoOpacity = 1
    })

    // Logo 弹入（ExtremeDeceleration 曲线带轻微回弹感）
    setTimeout(() => {
      animateTo({ duration: 880, curve: Curve.ExtremeDeceleration }, () => {
        this.logoScale = 1
        this.logoOpacity = 1
      })
    }, 80)

    // 副标题上滑淡入
    setTimeout(() => {
      animateTo({ duration: 660, curve: Curve.EaseOut }, () => {
        this.subtitleOpacity = 1
        this.subtitleOffsetY = 0
      })
    }, 420)

    // 状态行 + 加载指示器淡入
    setTimeout(() => {
      animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.statusOpacity = 1
      })
    }, 720)
  }

  private getHostContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
  }

  private async bootstrap(): Promise<void> {
    const host = this.getHostContext()
    if (host === undefined || this.hasRouted) {
      return
    }
    const accepted = await CookPreferences.hasAcceptedPrivacy(host)
    if (accepted) {
      this.statusText = '正在进入首页...'
      void this.goHomeWithAnimation()
      return
    }
    this.statusText = '请先完成隐私协议确认'
    setTimeout(() => {
      this.privacyDialogController.open()
    }, 50)
  }

  private async acceptPrivacy(): Promise<void> {
    const host = this.getHostContext()
    if (host === undefined) {
      return
    }
    await CookPreferences.setPrivacyAccepted(host, true)
    this.privacyDialogController.close()
    this.statusText = '已同意协议，正在进入首页...'
    void this.goHomeWithAnimation()
  }

  private rejectPrivacy(): void {
    this.privacyDialogController.close()
    const host = this.getHostContext()
    if (host !== undefined) {
      try {
        void host.terminateSelf()
        return
      } catch {
        console.error('terminateSelf failed')
      }
    }
    router.back()
  }

  /** 离场动画：内容缩小淡出后跳转，避免路由切换的生硬感 */
  private async goHomeWithAnimation(): Promise<void> {
    if (this.hasRouted) {
      return
    }
    // 保证最短停留时长，让入场动画完整播放
    const elapsed = Date.now() - this.startTime
    const remaining = StartupPage.MIN_DISPLAY_MS - elapsed
    if (remaining > 0) {
      await new Promise<void>((resolve) => {
        setTimeout(resolve, remaining)
      })
    }
    animateTo({ duration: 340, curve: Curve.EaseIn }, () => {
      this.exitOpacity = 0
      this.exitScale = 0.93
    })
    await new Promise<void>((resolve) => {
      setTimeout(resolve, 300)
    })
    this.goHome()
  }

  private goHome(): void {
    if (this.hasRouted) {
      return
    }
    this.hasRouted = true
    router.replaceUrl({ url: 'pages/IndexV2' }).catch((err: Error) => {
      console.error('router.replaceUrl failed', err)
      this.hasRouted = false
    })
  }

  build() {
    Stack() {
      // 背景装饰圆 — 右上品牌色光晕
      Column()
        .width(320)
        .height(320)
        .borderRadius(160)
        .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
        .opacity(this.decoOpacity * 0.52)
        .blur(64)
        .position({ x: '36%', y: '-12%' })

      // 背景装饰圆 — 左下暖橙光晕
      Column()
        .width(256)
        .height(256)
        .borderRadius(128)
        .backgroundColor('#FFE4C4')
        .opacity(this.decoOpacity * 0.42)
        .blur(56)
        .position({ x: '-16%', y: '60%' })

      // 主体内容（整体参与离场动画）
      Column({ space: 0 }) {
        // Logo 区域（入场弹入）
        Column({ space: 6 }) {
          Text('🍜')
            .fontSize(68)

          Text('AUV')
            .fontSize(44)
            .fontWeight(FontWeight.Bolder)
            .fontColor(AppColors.BRAND_COLOR)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Center)
        .scale({ x: this.logoScale, y: this.logoScale })
        .opacity(this.logoOpacity)

        // 副标题（入场上滑）
        Text('您吃了么')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.GRAY_800)
          .margin({ top: 14 })
          .opacity(this.subtitleOpacity)
          .translate({ y: this.subtitleOffsetY })

        // 分隔线
        Divider()
          .width(44)
          .strokeWidth(1)
          .color(AppColors.GRAY_200)
          .margin({ top: 36, bottom: 28 })
          .opacity(this.statusOpacity)

        // 加载状态行
        Row({ space: 10 }) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(AppColors.BRAND_COLOR)

          Text(this.statusText)
            .fontSize(13)
            .fontColor(AppColors.GRAY_500)
        }
        .opacity(this.statusOpacity)
      }
      .alignItems(HorizontalAlign.Center)
      .scale({ x: this.exitScale, y: this.exitScale })
      .opacity(this.exitOpacity)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F5')
  }
}
