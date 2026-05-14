/**
 * 隐私政策 & 用户服务协议阅读页
 * 符合华为 AppGallery Connect 合规审核要求
 * 依据《个人信息保护法》《网络安全法》及华为隐私规范制定
 * 《您吃了么》v1.1.0 · 生效日期 2026-05-14
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
// 符合《个人信息保护法》《网络安全法》及华为 AppGallery Connect 合规审核要求
// 版本 1.1.0 · 生效日期 2026-05-14

export const PRIVACY_DOC: LegalDocConfig = {
  type: 'privacy',
  icon: '🛡️',
  title: '隐私政策',
  subtitle: '《您吃了么》由南京理工大学 AUV 项目组开发。我们高度重视您的隐私权，依据《中华人民共和国个人信息保护法》《网络安全法》及华为 AppGallery Connect 隐私规范制定本政策，请在使用前仔细阅读。',
  effectiveDate: '版本 1.1.0　·　生效日期：2026 年 5 月 14 日',
  sections: [
    {
      heading: '一、开发者信息',
      body: '应用名称：您吃了么\n开发者：南京理工大学 AUV 项目组\n联系邮箱：762540357@qq.com\n代码仓库：https://github.com/TEITAR-mxh/Cook-njust\n\n本应用为非营利性学生开源项目，无商业主体注册信息。'
    },
    {
      heading: '二、我们收集的个人信息',
      body: '本应用遵循”最小必要”原则，仅收集提供核心功能所必需的数据，且全部存储于您的设备本地，不上传至任何服务器。\n\n【您主动提供的信息】\n• 昵称：用于个人资料页展示，仅存储于本地。\n• 头像图片：您从相册选取后，应用将图片复制至沙箱目录，不保留原始路径，不上传。\n\n【应用自动生成的数据】\n• 食材与厨具偏好选择列表\n• 菜谱浏览历史记录（最近 50 条 ID）\n• 菜谱收藏列表（最多 500 条 ID）\n• 每日推荐通知的推送时间偏好\n• 搜索关键词历史（最近 20 条，仅存本地）\n\n我们不收集您的姓名、手机号、身份证、地理位置、设备标识符（IMEI/OAID）、通讯录或任何敏感个人信息。'
    },
    {
      heading: '三、权限使用说明',
      body: '本应用向系统申请以下权限，每项权限均有唯一且明确的使用场景，拒绝授权不影响其他功能的正常使用：\n\n【相机权限 CAMERA】\n使用场景：热量识别功能，拍摄食物照片后在本地进行识别分析。\n不使用场景：不在后台拍摄，不上传任何图片至服务器。\n\n【读取媒体文件 READ_MEDIA】\n使用场景：从相册中选取头像图片。\n不使用场景：不扫描、不读取其他媒体文件内容。\n\n【写入媒体文件 WRITE_MEDIA】\n使用场景：将选取的头像图片写入应用沙箱，供个人资料页显示。\n\n【媒体地理位置 MEDIA_LOCATION】\n使用场景：读取相册图片时系统要求伴随申请，实际不读取或使用任何地理位置数据。\n\n【后台任务锁 RUNNING_LOCK】\n使用场景：在查看烹饪步骤或视频教程时防止屏幕自动息屏，提升烹饪体验。\n\n【发布代理提醒 PUBLISH_AGENT_REMINDER】\n使用场景：每日菜谱推荐通知，在您设定的时间由系统代理发出提醒，无需应用保持前台运行。\n\n【网络访问 INTERNET】\n使用场景：点击菜谱视频教程时跳转至哔哩哔哩等外部平台，应用本身不传输任何用户数据。\n\n【系统通知权限】\n通过系统弹窗向您申请，用于推送每日菜谱推荐通知。您可随时在 系统设置 → 应用管理 → 您吃了么 → 通知 中关闭。\n\n您可随时在 系统设置 → 应用管理 → 您吃了么 → 权限 中查看和撤回上述任意权限。'
    },
    {
      heading: '四、个人信息的使用目的',
      body: '我们仅将收集的信息用于以下目的，不作任何超出范围的处理：\n\n• 根据您选择的食材和厨具，智能匹配可做菜谱\n• 记录浏览历史，方便您重温感兴趣的食谱\n• 管理收藏夹，快速定位心仪食谱\n• 个性化每日推荐，避免重复推送已看过的菜谱\n• 展示您的昵称与头像\n\n我们承诺不将任何信息用于广告投放、用户画像分析或跨应用数据追踪。'
    },
    {
      heading: '五、信息的存储与安全保护',
      body: '【存储位置】所有数据均存储于您设备的应用沙箱内：\n• 偏好设置：HarmonyOS Preferences（键值对加密存储）\n• 头像图片：应用沙箱 filesDir 目录\n• 菜谱源数据：只读内嵌于安装包 rawfile，不可被外部访问\n\n【传输安全】本应用无后台服务器，所有功能均在本地完成，用户数据不经过任何网络传输。\n\n【数据生命周期】应用卸载后，操作系统将自动清除沙箱内的全部数据，无需您手动操作。'
    },
    {
      heading: '六、第三方服务说明',
      body: '本应用不集成任何第三方 SDK（含统计、广告、推送等）。\n\n【外部视频链接】部分菜谱包含跳转至哔哩哔哩（bilibili.com）的视频教程链接。点击后您将离开本应用，进入 Bilibili 客户端或浏览器，您的浏览行为将受 Bilibili 隐私政策（https://www.bilibili.com/blackboard/privacy-pc.html）约束，本应用对此不承担责任，也不获取任何相关数据。\n\n【华为系统服务】本应用调用以下 HarmonyOS 系统能力，数据处理由华为系统服务负责：\n• reminderAgentManager：管理每日定时提醒的调度与通知下发\n• notificationManager：申请并管理通知权限\n\n上述系统服务受华为《隐私政策》（https://consumer.huawei.com/cn/privacy/）约束。'
    },
    {
      heading: '七、未成年人保护',
      body: '本应用面向 14 周岁及以上用户，内容为通用烹饪类，不含对未成年人有害的内容。\n\n如您为未满 14 周岁的未成年人，请在监护人的陪同与指导下使用本应用，并由监护人代为同意本隐私政策。\n\n若监护人发现未成年人在未获授权的情况下提供了个人信息，请通过本政策末尾的联系方式告知我们，我们将在 5 个工作日内删除相关信息。'
    },
    {
      heading: '八、您的权利',
      body: '依据《个人信息保护法》，您对本地数据享有以下权利，并可通过以下路径自行行使，无需联系我们：\n\n【查阅权】进入”发现”页 → 足迹热力图，可查看浏览记录分布；进入”收藏”页可查看全部收藏内容。\n\n【更正权】进入”设置”页，随时修改昵称与头像。\n\n【删除权】进入”设置” → “存储与数据” → 关闭”保留本地数据”，应用将立即清除全部历史记录与收藏数据。\n\n【撤回同意权】在系统设置中随时撤回任意权限授权；关闭”每日推荐通知”开关即撤回通知同意。\n\n【投诉权】若您认为本应用侵害了您的个人信息权益，可向网信部门或消费者协会投诉，也可通过下方联系方式向我们反映，我们将在 15 个工作日内回复。'
    },
    {
      heading: '九、隐私政策的变更',
      body: '若本政策发生以下实质性变更，我们将在应用内通过弹窗等显著方式提前告知，并重新获取您的明确同意：\n\n• 新增个人信息收集类型或用途\n• 新增对外共享、转让或公开披露\n• 存储地点发生跨境变化\n• 用户权利保障措辞发生重大降格\n\n对于不影响用户重大权益的非实质性变更（如文字优化、联系方式更新），将在新版本发布时同步生效，版本号和生效日期同步更新。'
    },
    {
      heading: '十、联系我们',
      body: '如您对本隐私政策有任何疑问、意见或权利请求，请通过以下方式联系我们：\n\n• 联系邮箱：762540357@qq.com\n• GitHub Issues：https://github.com/TEITAR-mxh/Cook-njust\n• 开发团队：南京理工大学 AUV 项目组\n\n我们承诺在收到请求后 15 个工作日内予以回复。'
    }
  ],
  footer: '© 2026 AUV 项目组 · 南京理工大学　保留所有权利'
}

// ─── 用户协议 ─────────────────────────────────────────────────────────────────
// 符合华为 AppGallery Connect 合规审核要求
// 版本 1.1.0 · 生效日期 2026-05-14

export const AGREEMENT_DOC: LegalDocConfig = {
  type: 'agreement',
  icon: '📋',
  title: '用户服务协议',
  subtitle: '本协议（以下简称"本协议"）是您（"用户"）与南京理工大学 AUV 项目组（"我们"）之间，就使用《您吃了么》软件及相关服务所订立的具有法律约束力的协议，请在使用前仔细阅读全部内容。',
  effectiveDate: '版本 1.1.0　·　生效日期：2026 年 5 月 14 日',
  sections: [
    {
      heading: '一、协议的接受与效力',
      body: '当您首次启动本应用并点击"同意并开始使用"时，即表示您已完整阅读、理解并同意受本协议全部条款约束。\n\n若您不同意本协议的任何内容，请立即停止使用本应用并将其卸载。\n\n未满 14 周岁的未成年人须在法定监护人的监督下使用本应用，并由监护人代为阅读和同意本协议。未满 18 周岁的未成年用户应在监护人指导下使用本应用。'
    },
    {
      heading: '二、服务内容与范围',
      body: '《您吃了么》为您提供以下完全本地化的免费服务：\n\n【食材匹配检索】根据您选择的冰箱食材和厨具，智能匹配可做菜谱，支持严格、模糊、生存三种检索模式。\n\n【菜谱库浏览与发现】全量菜谱按分类展示，支持标签筛选、全文关键词搜索及随机发现，部分菜谱附有视频教程链接。\n\n【今日餐桌与营养参考】记录今日已选菜谱，提供基础营养摄入参考数据（源自《中国居民膳食指南 2022》，仅供参考）。\n\n【每日菜谱推荐通知】在您设定的时间推送一条菜谱灵感通知，需您主动开启并授权通知权限。\n\n【热量识别（实验性功能）】通过拍摄食物照片进行本地识别，结果仅供参考，不构成营养学诊断。\n\n【个人中心】收藏夹管理、浏览足迹热力图、个人昵称与头像自定义。\n\n以上服务以"现状"提供，我们保留在版本迭代中调整、优化或下线特定功能的权利，并将通过应用内通知或更新日志告知重要变更。'
    },
    {
      heading: '三、账号与数据',
      body: '本应用无需注册账号，无需绑定手机号或邮箱。\n\n您的全部个人数据（食材偏好、菜谱收藏、浏览历史、昵称、头像）均存储于您设备的本地应用沙箱内，不同步至任何云端服务器，不在设备间共享。\n\n因以下情形导致的本地数据丢失，由您自行承担：\n• 设备丢失、损坏或被盗\n• 恢复出厂设置或重新刷机\n• 更换新设备而未进行设备迁移\n• 系统层面强制清除应用数据'
    },
    {
      heading: '四、用户行为规范',
      body: '在使用本应用期间，您承诺遵守以下规范：\n\n【合法使用】不得利用本应用从事任何违反中华人民共和国法律法规或侵害他人合法权益的活动。\n\n【技术安全】不得对本应用进行逆向工程、反编译、反汇编或以任何方式尝试获取源代码或核心算法（开源许可范围内除外）。\n\n【数据合规】不得采用爬虫、自动化工具或其他技术手段批量提取、复制或商业化利用本地菜谱数据库内容。\n\n【系统安全】不得实施可能损害本应用或相关系统正常运行的行为，包括但不限于模拟操作、注入攻击等。\n\n如您违反上述规范，我们保留立即终止向您提供服务并依法追究相应法律责任的权利。'
    },
    {
      heading: '五、知识产权',
      body: '【应用本体】本应用的界面设计、视觉风格、交互逻辑、品牌标识、源代码及文档等，其著作权归 AUV 项目组所有，受《中华人民共和国著作权法》保护。未经书面授权，任何单位或个人不得复制、修改、发行或以任何商业方式使用。\n\n【菜谱内容】应用内菜谱文字内容整理自公开烹饪知识资料，版权归各原始著作权人所有，本应用依合理使用原则整理呈现，不主张所有权。\n\n【视频内容】视频教程链接指向哔哩哔哩等平台的创作者原创作品，版权归原创作者所有，本应用仅作链接导航，不托管视频内容，不主张任何所有权。\n\n【您的使用范围】您可将菜谱内容用于个人家庭非商业烹饪参考，但不得将任何内容用于商业目的、公开发行或二次创作传播。'
    },
    {
      heading: '六、免责声明',
      body: '在法律允许的最大范围内，对于以下情形，我们不承担任何赔偿或法律责任：\n\n【健康风险】因个人体质差异、食物过敏、特殊饮食禁忌（如疾病、药物相互作用）引起的健康问题。本应用提供的菜谱及营养数据仅供一般性参考，不构成医学、临床营养学或专业餐饮建议；有特殊饮食需求者，请务必咨询专业医师或注册营养师。\n\n【食品安全】因食材质量、储存不当、烹饪操作失误或卫生条件引起的食品安全问题。\n\n【热量识别准确性】热量识别功能为实验性功能，识别结果受拍摄角度、光线、食材遮挡等因素影响，存在误差，不得作为医疗、减重或营养摄入的唯一依据。\n\n【第三方服务】因哔哩哔哩等外部平台内容变更、下架、访问故障或平台政策变化造成的体验影响；您在第三方平台的数据处理行为受其隐私政策约束，与本应用无关。\n\n【不可抗力】因自然灾害、网络故障、系统升级或其他不可抗力导致的服务中断或数据丢失。\n\n【设备因素】因设备硬件故障、操作系统问题或用户误操作导致的本地数据损坏或丢失。'
    },
    {
      heading: '七、服务的变更与终止',
      body: '【我们的权利】作为持续迭代的开源项目，我们保留随时优化功能、调整界面、更新菜谱数据或修改存储策略的权利。影响用户核心体验的重大变更，将提前通过应用内通知或版本更新日志告知。\n\n【您终止服务的方式】您可随时卸载本应用以终止使用服务。卸载后，操作系统将自动清除本地沙箱内的全部数据，无需额外操作。\n\n【我们终止服务的情形】若您严重违反本协议，或出于法律合规要求，我们可在不另行通知的情况下暂停或终止向您提供服务。'
    },
    {
      heading: '八、协议的修改',
      body: '我们可能根据法律法规变化、功能迭代或运营需要修订本协议。修订规则如下：\n\n【重大修改】涉及用户权利重大变化的修订（如新增数据收集类型、改变争议解决方式等），将在应用内以显著弹窗提前至少 7 日告知，并需您重新确认同意方可继续使用。\n\n【一般修改】文字优化、联系方式更新等非实质性修订，将随版本更新同步生效，版本号和生效日期一并更新。\n\n您在本协议修订后继续使用本应用，视为接受修订后的协议内容。若您不同意修订内容，可在生效前停止使用并卸载本应用。'
    },
    {
      heading: '九、法律适用与争议解决',
      body: '本协议的订立、效力、解释、履行及争议解决，均适用中华人民共和国大陆地区现行法律法规。\n\n因使用本应用或本协议引发的任何争议，双方应首先通过友好协商方式解决；协商不成，任一方均可向本应用开发团队所在地（中国·江苏省南京市）有管辖权的人民法院提起诉讼。\n\n本协议某一条款被认定为无效或不可执行，不影响其他条款的效力，其余条款继续完整有效。'
    },
    {
      heading: '十、联系我们',
      body: '如您对本用户协议有任何疑问、意见或投诉，请通过以下方式联系我们：\n\n• 联系邮箱：762540357@qq.com\n• GitHub Issues：https://github.com/TEITAR-mxh/Cook-njust\n• 开发团队：南京理工大学 AUV 项目组\n\n我们承诺在收到请求后 15 个工作日内予以回复。'
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
