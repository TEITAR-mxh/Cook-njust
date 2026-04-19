/**
 * 启动页 & 隐私同意对话框
 * 品牌化同意框 + 沉浸式启动动画
 */
import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppColors'
import { CookPreferences } from '../store/CookPreferences'

// ─── 隐私同意对话框 ─────────────────────────────────────────────────────────────

@CustomDialog
struct PrivacyConsentDialog {
  controller?: CustomDialogController
  onAgree: () => void = () => {}
  onReject: () => void = () => {}
  onOpenPrivacy: () => void = () => {}
  onOpenAgreement: () => void = () => {}

  @State private isAgreed: boolean = false

  build() {
    Column({ space: 0 }) {

      // ── 品牌区：emoji + 应用名 ────────────────────────────────────────────
      Column({ space: 6 }) {
        Text('🍜')
          .fontSize(56)
        Text('AUV 您吃了么')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.GRAY_900)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 32, bottom: 24 })

      // ── 说明文字 ──────────────────────────────────────────────────────────
      Text('为保障您的合法权益，使用前请阅读并同意以下协议。我们承诺全部数据在本地处理，不上传任何服务器。')
        .fontSize(14)
        .fontColor(AppColors.GRAY_500)
        .lineHeight(22)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 8, right: 8, bottom: 24 })

      // ── 协议链接双按钮 ────────────────────────────────────────────────────
      Row({ space: 12 }) {
        Text('《隐私政策》')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.BRAND_COLOR)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(42)
          .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
          .borderRadius(12)
          .onClick(() => { this.onOpenPrivacy() })

        Text('《用户协议》')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.BRAND_COLOR)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(42)
          .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
          .borderRadius(12)
          .onClick(() => { this.onOpenAgreement() })
      }
      .width('100%')
      .padding({ bottom: 24 })

      // ── 分隔线 ────────────────────────────────────────────────────────────
      Divider()
        .color(AppColors.GRAY_100)
        .width('100%')
        .margin({ bottom: 18 })

      // ── 复选框行 ─────────────────────────────────────────────────────────
      Row({ space: 10 }) {
        Checkbox({ name: 'privacyAgree', group: 'startup' })
          .select(this.isAgreed)
          .selectedColor(AppColors.BRAND_COLOR)
          .width(20)
          .height(20)
          .flexShrink(0)
          .onChange((value: boolean) => { this.isAgreed = value })

        Text('我已阅读并同意以上全部协议')
          .fontSize(14)
          .fontColor(AppColors.GRAY_600)
          .layoutWeight(1)
          .onClick(() => { this.isAgreed = !this.isAgreed })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ bottom: 20 })

      // ── 主操作按钮 ────────────────────────────────────────────────────────
      Button('同意并开始使用')
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(this.isAgreed ? AppColors.BRAND_COLOR : AppColors.GRAY_300)
        .borderRadius(14)
        .enabled(this.isAgreed)
        .animation({ duration: 200, curve: Curve.EaseOut })
        .onClick(() => { this.onAgree() })

      // ── 次操作：退出文字链 ────────────────────────────────────────────────
      Text('不同意，退出应用')
        .fontSize(13)
        .fontColor(AppColors.GRAY_400)
        .padding({ top: 16, bottom: 28 })
        .onClick(() => { this.onReject() })

    }
    .padding({ left: 24, right: 24 })
    .width('88%')
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({ radius: 40, color: '#0000001A', offsetX: 0, offsetY: 12 })
  }
}

// ─── 启动页 ────────────────────────────────────────────────────────────────────

@Entry
@Component
struct StartupPage {
  @State private statusText: string = '正在准备数据...'
  @State private hasRouted: boolean = false

  // 入场动画状态
  @State private logoScale: number = 0.68
  @State private logoOpacity: number = 0
  @State private subtitleOpacity: number = 0
  @State private subtitleOffsetY: number = 22
  @State private statusOpacity: number = 0
  @State private decoOpacity: number = 0

  // 离场动画状态
  @State private exitOpacity: number = 1
  @State private exitScale: number = 1

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
        // 先关闭对话框，等关闭动画（约 120ms）完成后再导航，避免动画叠加产生遮挡
        this.privacyDialogController.close()
        setTimeout(() => {
          // 与 LegalDocPage.getParams() 使用同一路由栈，确保参数能正常传递
          this.getUIContext().getRouter()
            .pushUrl({ url: 'pages/LegalDocPage', params: { docType: 'privacy' } })
            .catch((e: Error) => { console.error('nav to privacy failed', e) })
        }, 150)
      },
      onOpenAgreement: () => {
        this.privacyDialogController.close()
        setTimeout(() => {
          this.getUIContext().getRouter()
            .pushUrl({ url: 'pages/LegalDocPage', params: { docType: 'agreement' } })
            .catch((e: Error) => { console.error('nav to agreement failed', e) })
        }, 150)
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

  /**
   * 用户从《隐私政策》/《用户协议》页面返回时触发。
   * 若仍未同意，重新弹出对话框，避免用户卡在加载状态文字。
   */
  onPageShow(): void {
    if (!this.hasRouted) {
      void this.recheckAndShowDialog()
    }
  }

  private async recheckAndShowDialog(): Promise<void> {
    const host = this.getHostContext()
    if (!host) return
    try {
      const accepted = await CookPreferences.hasAcceptedPrivacy(host)
      if (!accepted) {
        // 短暂延迟等页面完成转场动画
        setTimeout(() => { this.privacyDialogController.open() }, 200)
      }
    } catch {
      // 读取失败时也重新显示对话框
      setTimeout(() => { this.privacyDialogController.open() }, 200)
    }
  }

  /** 入场动画：装饰圆缓入 → logo 弹入 → 副标题上滑 → 状态行淡入 */
  private runEntryAnimation(): void {
    animateTo({ duration: 1200, curve: Curve.EaseOut }, () => {
      this.decoOpacity = 1
    })
    setTimeout(() => {
      animateTo({ duration: 880, curve: Curve.ExtremeDeceleration }, () => {
        this.logoScale = 1
        this.logoOpacity = 1
      })
    }, 80)
    setTimeout(() => {
      animateTo({ duration: 660, curve: Curve.EaseOut }, () => {
        this.subtitleOpacity = 1
        this.subtitleOffsetY = 0
      })
    }, 420)
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
    if (host === undefined || this.hasRouted) return
    const accepted = await CookPreferences.hasAcceptedPrivacy(host)
    if (accepted) {
      this.statusText = '正在进入首页...'
      void this.goHomeWithAnimation()
      return
    }
    this.statusText = '请先完成隐私协议确认'
    setTimeout(() => { this.privacyDialogController.open() }, 50)
  }

  private async acceptPrivacy(): Promise<void> {
    const host = this.getHostContext()
    if (host === undefined) return
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
    this.getUIContext().getRouter().back()
  }

  /** 离场动画：内容缩小淡出后跳转 */
  private async goHomeWithAnimation(): Promise<void> {
    if (this.hasRouted) return
    const elapsed = Date.now() - this.startTime
    const remaining = StartupPage.MIN_DISPLAY_MS - elapsed
    if (remaining > 0) {
      await new Promise<void>((resolve) => { setTimeout(resolve, remaining) })
    }
    animateTo({ duration: 340, curve: Curve.EaseIn }, () => {
      this.exitOpacity = 0
      this.exitScale = 0.93
    })
    await new Promise<void>((resolve) => { setTimeout(resolve, 300) })
    this.goHome()
  }

  private goHome(): void {
    if (this.hasRouted) return
    this.hasRouted = true
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/IndexV2' }).catch((err: Error) => {
      console.error('router.replaceUrl failed', err)
      this.hasRouted = false
    })
  }

  build() {
    Stack() {
      // 右上品牌色光晕
      Column()
        .width(320).height(320).borderRadius(160)
        .backgroundColor(AppColors.BRAND_COLOR_LIGHT)
        .opacity(this.decoOpacity * 0.52)
        .blur(64)
        .position({ x: '36%', y: '-12%' })

      // 左下暖橙光晕
      Column()
        .width(256).height(256).borderRadius(128)
        .backgroundColor('#FFE4C4')
        .opacity(this.decoOpacity * 0.42)
        .blur(56)
        .position({ x: '-16%', y: '60%' })

      // 主体内容（整体参与离场动画）
      Column({ space: 0 }) {
        // Logo 区域（入场弹入）
        Column({ space: 6 }) {
          Text('🍜').fontSize(68)
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
          .width(44).strokeWidth(1).color(AppColors.GRAY_200)
          .margin({ top: 36, bottom: 28 })
          .opacity(this.statusOpacity)

        // 加载状态行
        Row({ space: 10 }) {
          LoadingProgress()
            .width(20).height(20)
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
