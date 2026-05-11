/**
 * 隐私政策 & 用户协议阅读页
 * 符合华为 AppGallery Connect 合规规范
 * 《AUV 您吃了么》专属版本 · 生效日期 2026-04-19
 */
import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppColors'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

// ─── 数据结构 ─────────────────────────────────────────────────────────────────

export interface LegalSection {
  heading: string
  body: string
}

export interface LegalDocConfig {
  type: 'privacy' | 'agreement'
  icon: string
  title: string
  subtitle: string
  effectiveDate: string
  sections: LegalSection[]
  footer: string
}

// ─── 隐私政策 ─────────────────────────────────────────────────────────────────
// 内容已与线上 HTML 版本 (https://fanbo0419.github.io/-/) 同步

export const PRIVACY_DOC: LegalDocConfig = {
  type: 'privacy',
  icon: '🛡️',
  title: '隐私政策',
  subtitle: '《AUV 您吃了么》由南京理工大学学生团队开发。我们依据《个人信息保护法》《网络安全法》制定本政策，请在使用前仔细阅读。',
  effectiveDate: '版本 1.0.0　·　生效日期：2026 年 4 月 19 日',
  sections: [
    {
      heading: '📌 开发者信息',
      body: '“AUV 您吃了么”开发团队'
    },
    {
      heading: '一、我们收集的信息',
      body: '本应用仅在设备本地处理数据，不向任何服务器上传个人身份信息。\n\n【本地自动生成的数据】\n• 您选择的食材与厨具偏好\n• 浏览过的菜谱历史记录（最近 50 条）\n• 您收藏的菜谱 ID 列表（最多 500 条）\n• 昵称、头像等个人资料（存储于设备沙箱）\n\n【相册权限】仅在您主动选择头像图片时读取，读取后立即复制至沙箱，不保留原始路径。'
    },
    {
      heading: '二、信息的使用目的',
      body: '我们收集上述信息的唯一目的是提升您的菜谱使用体验：\n\n• 根据冰箱食材精准匹配可做菜谱\n• 记录浏览历史，方便您重温感兴趣的菜谱\n• 保存收藏列表，快速定位心仪食谱\n• 恢复上次的搜索模式（严格 / 模糊 / 生存）设置\n\n我们不使用任何信息进行广告投放、用户画像或跨应用追踪。'
    },
    {
      heading: '三、信息的存储与保护',
      body: '全部数据均存储于您的设备本地：\n\n• 用户偏好设置使用 HarmonyOS Preferences 存储\n• 菜谱源数据以只读方式内嵌于安装包 rawfile 目录\n• 头像图片复制至应用沙箱 filesDir，随应用卸载自动删除\n\n我们没有自有服务器，数据不经过任何网络传输。'
    },
    {
      heading: '四、权限使用说明',
      body: '本应用申请以下设备权限，每项均有明确用途且需您主动授权：\n\n【READ_IMAGEVIDEO / WRITE_IMAGEVIDEO】\n用于从相册选取头像图片，不读取其他媒体文件，不上传。\n\n【RUNNING_LOCK】\n防止在查看烹饪步骤时屏幕意外熄灭，仅在视频播放页生效。\n\n您可随时在系统设置 → 应用管理 → AUV您吃了么 → 权限 中撤回授权。'
    },
    {
      heading: '五、未成年人保护',
      body: '本应用面向 14 周岁及以上用户。如您为未成年人，请在监护人陪同下使用。我们不主动收集未成年人个人信息；若监护人发现未成年人在未告知的情况下提供了相关信息，请联系我们予以删除。'
    },
    {
      heading: '六、您的权利',
      body: '依据《个人信息保护法》，您对本地数据享有以下权利：\n\n【查阅】在"餐桌"页可查看收藏数量和浏览记录条数。\n【删除】在设置页关闭"保留本地数据"，应用将立即清除全部个人记录与收藏。\n【修改】可随时更改昵称与头像。\n【撤回】可在系统权限管理中撤回相册读写权限。\n\n如需行使其他权利，请通过下方联系方式与我们沟通。'
    },
    {
      heading: '七、第三方内容',
      body: '本应用中的视频链接跳转至哔哩哔哩（Bilibili）等外部平台。跳转后您将受该平台隐私政策约束，本应用不对第三方平台的数据处理行为负责。'
    },
    {
      heading: '八、政策变更',
      body: '如本政策发生实质性变更，我们将在应用内通过弹窗等显著方式重新获得您的明确同意。对于不影响用户重大权益的非实质性变更（如文本优化），我们会在应用更新时同步。您继续使用本应用视为接受更新后的政策。'
    },
    {
      heading: '九、联系我们',
      body: '开发与运营方：“AUV 您吃了么”开发团队 \n\n• GitHub Issues：https://github.com/TEITAR-mxh/Cook-njust.git\n• 开发团队：南京理工大学 AUV 项目组\n\n我们承诺在收到请求后 15 个工作日内回复。'
    }
  ],
  footer: '© 2026 AUV 项目组 · 南京理工大学　保留所有权利'
}

// ─── 用户协议 ─────────────────────────────────────────────────────────────────

export const AGREEMENT_DOC: LegalDocConfig = {
  type: 'agreement',
  icon: '📋',
  title: '用户协议',
  subtitle: '本协议（以下简称"协议"）是您（"用户"）与 AUV 项目组（"我们"）之间就使用《AUV 您吃了么》软件及相关服务所订立的法律文件，具有合同效力。',
  effectiveDate: '版本 1.0.0　·　生效日期：2026 年 4 月 19 日',
  sections: [
    {
      heading: '一、协议的接受与生效',
      body: '当您勾选"我已阅读并同意"复选框并点击"同意并开始使用"时，即表示您已完整阅读、理解并接受本协议的全部条款和条件。\n\n若您不同意本协议任何内容，请立即停止使用本应用。未成年人须在法定监护人监督下阅读并由其代为同意本协议。'
    },
    {
      heading: '二、服务内容与范围',
      body: '《AUV 您吃了么》为您提供以下本地化服务：\n\n【菜谱检索】按食材和厨具多维度智能匹配可做菜谱，支持严格、模糊、生存三种搜索模式。\n【菜谱库浏览】全量菜谱分类展示、标签筛选与全文关键词搜索。\n【随机发现】基于本地菜谱数据库随机推荐含视频教程的菜品。\n【个人中心】收藏夹管理、浏览历史追踪、个人资料自定义。\n\n上述功能以"现状"提供，我们保留在不另行通知的情况下调整服务内容的权利。'
    },
    {
      heading: '三、账号与设备',
      body: '本应用无需注册账号，所有个人数据（收藏列表、浏览历史、昵称、头像）均存储于您的设备本地沙箱，不与任何服务器同步。\n\n您有责任妥善保管设备安全。因设备丢失、损坏、恢复出厂设置或更换设备导致的本地数据丢失，由您自行承担。'
    },
    {
      heading: '四、用户行为规范',
      body: '在使用本应用期间，您承诺遵守以下规范，并明确禁止：\n\n【法律合规】不得利用本应用从事任何违反中华人民共和国法律法规的活动。\n【技术安全】不得对应用进行逆向工程、反编译、反汇编或以任何方式尝试获取源代码。\n【数据保护】不得恶意爬取、批量复制或商业化使用本地菜谱数据库内容。\n【服务完整性】不得采取任何可能损害应用正常运行的行为，包括但不限于模拟点击、自动化脚本等。\n\n违反上述规范，我们保留终止向您提供服务并追究相应责任的权利。'
    },
    {
      heading: '五、知识产权声明',
      body: '应用界面设计、交互逻辑、品牌标识及代码实现的全部知识产权归 AUV 项目组所有，受中华人民共和国著作权法保护。\n\n菜谱文字内容整理自公开烹饪知识；视频链接指向第三方平台创作者的原创作品，版权归原作者所有，本应用不主张所有权。\n\n您可将菜谱内容用于个人家庭烹饪参考，但不得将任何内容用于商业目的、公开传播或二次创作发行。'
    },
    {
      heading: '六、免责声明',
      body: '在法律允许的最大范围内，对于以下情形我们不承担任何责任：\n\n• 因个人体质差异、食物过敏、饮食禁忌引起的健康问题\n• 因食材质量、储存不当或烹饪操作失误引起的食品安全问题\n• 因第三方视频平台内容下架、变更或无法访问造成的体验影响\n• 因不可抗力（如自然灾害、网络故障、系统升级）导致的服务中断\n• 因设备故障或操作系统问题导致的数据丢失\n\n本应用提供的菜谱仅供参考，不构成医学、营养学或专业餐饮建议。有特殊饮食需求者请咨询专业医师或营养师。'
    },
    {
      heading: '七、服务变更与终止',
      body: '【我们的权利】作为持续迭代的学生开源项目，我们保留随时优化功能、调整界面、更新菜谱数据库及修改本地存储策略的权利。重大变更将提前通过应用内通知或版本更新日志告知。\n\n【您的权利】您可随时通过卸载本应用终止使用服务。卸载后，设备沙箱内的全部本地数据将由操作系统自动清除，无需额外操作。\n\n【我们的终止权】若您严重违反本协议，我们可在不另行通知的情况下暂停或终止向您提供服务。'
    },
    {
      heading: '八、协议的修改',
      body: '我们可能根据法律法规变化、功能迭代或运营需要对本协议进行修订。修订后的协议将在应用内显著位置公示，公示期不少于 7 日。\n\n公示期结束后，您继续使用本应用视为接受修订后的协议。若您不同意修订内容，应在公示期内停止使用并卸载本应用。'
    },
    {
      heading: '九、法律适用与争议解决',
      body: '本协议的订立、效力、解释、履行及争议解决均适用中华人民共和国法律。\n\n因本协议引发的任何争议，双方应首先通过友好协商解决；协商不成，任一方均可向开发者住所地（中国·南京）有管辖权的人民法院提起诉讼。'
    },
    {
      heading: '十、联系我们',
      body: '如您对本用户协议有任何疑问或需要行使相关权利：\n\n• GitHub Issues：https://github.com/TEITAR-mxh/Cook-njust.git\n• 开发团队：南京理工大学 AUV 项目组\n\n我们将在 15 个工作日内予以回复。'
    }
  ],
  footer: '© 2026 AUV 项目组 · 南京理工大学　保留所有权利'
}

// ─── 页面组件 ──────────────────────────────────────────────────────────────────

@Entry
@Component
struct LegalDocPage {
  @State private docConfig: LegalDocConfig = PRIVACY_DOC
  @State private safeTopVp: number = 48

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @State private isDark: boolean = false

  // ── 生命周期 ──────────────────────────────────────────────────────────────

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter()
      .getParams() as Record<string, string> | undefined
    this.docConfig = params?.docType === 'agreement' ? AGREEMENT_DOC : PRIVACY_DOC

    this.isDark = this.calcIsDark()

    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (ctx !== undefined) {
      getSystemSafeTopVp(ctx).then((vp: number) => { this.safeTopVp = vp }).catch(() => {})
    }
  }

  private onThemeChange(): void {
    this.isDark = this.calcIsDark()
  }

  private calcIsDark(): boolean {
    if (this.storedThemeMode === '深色模式') return true
    if (this.storedThemeMode === '浅色模式') return false
    return this.isSystemDark
  }

  // ── 色彩 ──────────────────────────────────────────────────────────────────

  private get bg(): string {
    return this.isDark ? AppColors.DARK_BG_COLOR : '#F5F5F7'
  }

  private get surface(): string {
    return this.isDark ? AppColors.DARK_CARD_BG : '#FFFFFF'
  }

  private get navBg(): string {
    return this.isDark ? AppColors.DARK_CARD_BG : '#FFFFFF'
  }

  private get dividerColor(): string {
    return this.isDark ? AppColors.DARK_GRAY_200 : '#E8E8EA'
  }

  private get textPrimary(): string {
    return this.isDark ? AppColors.DARK_GRAY_900 : '#1A1A1F'
  }

  private get textBody(): string {
    return this.isDark ? AppColors.DARK_GRAY_600 : '#3C3C43'
  }

  private get textCaption(): string {
    return this.isDark ? AppColors.DARK_GRAY_400 : '#8E8E93'
  }

  /** 每种文档类型的主题色：隐私=品牌红，协议=蓝绿 */
  private get docAccent(): string {
    if (this.docConfig.type === 'agreement') {
      return '#2563EB'
    }
    return AppColors.BRAND_COLOR
  }

  private get docAccentLight(): string {
    if (this.docConfig.type === 'agreement') {
      return this.isDark ? '#1A2A4A' : '#EFF6FF'
    }
    return this.isDark ? '#2A1215' : '#FFF0F1'
  }

  // ── 导航栏 ────────────────────────────────────────────────────────────────

  @Builder
  private NavBar() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([this.textPrimary])
      }
      .width(44).height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.getUIContext().getRouter().back() })

      Text(this.docConfig.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank().width(44)
    }
    .width('100%')
    .height(this.safeTopVp + 44)
    .padding({ top: this.safeTopVp, left: 4, right: 4 })
    .backgroundColor(this.navBg)
    .border({ width: { bottom: 0.5 }, color: this.dividerColor })
  }

  // ── 文档 Banner ───────────────────────────────────────────────────────────

  @Builder
  private DocBanner() {
    Column({ space: 0 }) {
      Column({ space: 14 }) {
        // 图标 + 标题 + 日期，同行不换行
        Row({ space: 14 }) {
          // 图标：圆角方块 + accent 浅底
          Column() {
            Text(this.docConfig.icon)
              .fontSize(28)
          }
          .width(54).height(54)
          .borderRadius(14)
          .backgroundColor(this.docAccentLight)
          .justifyContent(FlexAlign.Center)
          .flexShrink(0)

          // 标题 + 日期
          Column({ space: 5 }) {
            Text(this.docConfig.title)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textPrimary)
              .maxLines(1)

            Text(this.docConfig.effectiveDate)
              .fontSize(12)
              .fontColor(this.textCaption)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 简介，最多 3 行
        Text(this.docConfig.subtitle)
          .fontSize(13)
          .fontColor(this.textCaption)
          .lineHeight(21)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 24, top: 24, bottom: 22 })
      .backgroundColor(this.surface)

      Divider().color(this.dividerColor)
    }
    .width('100%')
  }

  // ── 条款条目 ──────────────────────────────────────────────────────────────

  @Builder
  private SectionItem(section: LegalSection, isLast: boolean) {
    Column({ space: 0 }) {
      Column({ space: 12 }) {
        // 标题行：accent 色竖线 + 文字
        Row({ space: 10 }) {
          Column()
            .width(3).height(17)
            .backgroundColor(this.docAccent)
            .borderRadius(2)
            .flexShrink(0)

          Text(section.heading)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.textPrimary)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 正文
        Text(section.body)
          .fontSize(14)
          .fontColor(this.textBody)
          .lineHeight(26)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 22 })
      .backgroundColor(this.surface)

      if (!isLast) {
        Divider()
          .color(this.dividerColor)
          .padding({ left: 24 })
      }
    }
    .width('100%')
  }

  // ── 页脚 ──────────────────────────────────────────────────────────────────

  @Builder
  private DocFooter() {
    Column({ space: 8 }) {
      Divider().color(this.dividerColor)
      Text(this.docConfig.footer)
        .fontSize(12)
        .fontColor(this.textCaption)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 4 })
    }
    .width('100%')
    .backgroundColor(this.bg)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 16, bottom: 48, left: 24, right: 24 })
  }

  // ── 构建入口 ──────────────────────────────────────────────────────────────

  build() {
    Column() {
      this.NavBar()

      Scroll() {
        Column({ space: 0 }) {
          this.DocBanner()

          // 条款列表（整体白卡）
          Column({ space: 0 }) {
            ForEach(
              this.docConfig.sections,
              (section: LegalSection, index: number) => {
                this.SectionItem(section, index === this.docConfig.sections.length - 1)
              },
              (section: LegalSection) => section.heading
            )
          }
          .width('100%')
          .margin({ top: 8, bottom: 8 })

          this.DocFooter()
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg)
  }

  // ── 页面转场动画 ──────────────────────────────────────────────────────────
  // RouteType.Push：前进（pushUrl）时触发
  // RouteType.Pop ：后退（back）时触发
  // 两者方向相反，避免"进退都从右飞"的视觉重叠
  // LegalDocPage 独立负责动画：从右侧滑入覆盖 Settings，返回时滑出
  // Settings 不定义转场保持静止，视觉上只有一层在移动
  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseOut, type: RouteType.Push })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 250, curve: Curve.EaseIn, type: RouteType.Pop })
      .slide(SlideEffect.Right)
  }
}
