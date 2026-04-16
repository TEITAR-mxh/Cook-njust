/**
 * 隐私政策与用户协议页 (API 22 沉浸式阅读版)
 * 遵循鸿蒙最佳实践：扁平化、大留白、高行距的系统级阅读体验
 */
import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { AppColors } from '../constants/AppColors'
import { getSystemSafeTopVp } from '../util/StatusBarInset'

interface LegalDocSection {
  heading: string
  body: string
}

interface LegalDocConfig {
  title: string
  intro: string
  sections: LegalDocSection[]
}

const PRIVACY_DOC: LegalDocConfig = {
  title: '隐私政策',
  intro: '本页面为本地富文本占位内容，用于应用市场合规自查与首次启动告知。',
  sections: [
    {
      heading: '1. 信息收集范围',
      body: '《AUV 您吃了么》V1.0 当前主要使用本地 Preferences 和 RelationalStore 保存食材选择、收藏、历史与菜谱数据，不主动上传个人身份信息。'
    },
    {
      heading: '2. 信息使用目的',
      body: '本地数据仅用于完成菜谱搜索、收藏同步、历史记录展示及个性化设置恢复，不用于广告投放或跨应用画像。'
    },
    {
      heading: '3. 信息存储与保护',
      body: '轻量设置使用 Preferences 存储，菜谱内容使用 RelationalStore 存储。用户关闭“保留本地数据”后，应用将清空对应本地偏好与记录。'
    },
    {
      heading: '4. 用户权利',
      body: '用户可在设置页查看数据统计、关闭本地数据保留、清空历史与收藏，并在后续版本中继续补齐更细粒度的数据导出与删除能力。'
    },
    {
      heading: '5. 联系与更新',
      body: '我们在正式上架前会补充开发者联系方式、隐私负责人邮箱与政策生效日期。'
    }
  ]
}

const AGREEMENT_DOC: LegalDocConfig = {
  title: '用户协议',
  intro: '本页面为本地富文本占位内容，用于首次启动确认与设置页查看。',
  sections: [
    {
      heading: '1. 服务说明',
      body: '本应用为菜谱检索与烹饪辅助工具，展示内容主要来自本地菜谱数据，不构成医疗、营养或专业餐饮建议。'
    },
    {
      heading: '2. 使用规范',
      body: '用户应合理使用应用功能，不得利用本应用进行违法违规活动，不得恶意篡改、抓取或传播应用内受保护内容。'
    },
    {
      heading: '3. 免责声明',
      body: '因设备差异、食材质量、个人烹饪方式不同造成的口味、食品安全或营养结果差异，开发者不承担直接责任。'
    },
    {
      heading: '4. 数据与功能调整',
      body: '开发者可根据版本迭代对菜谱内容、推荐逻辑、界面样式及本地存储策略进行优化，并通过应用版本更新告知用户。'
    },
    {
      heading: '5. 其他条款',
      body: '我们在上架前会补充完整法律主体、争议解决条款与协议生效时间。'
    }
  ]
}

@Entry
@Component
struct LegalDocPage {
  @State docType: string = 'privacy'
  @State docConfig: LegalDocConfig = PRIVACY_DOC
  @State safeTopVp: number = 48

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined
    if (params && params.docType) {
      this.docType = params.docType
    }

    if (this.docType === 'agreement') {
      this.docConfig = AGREEMENT_DOC
    } else {
      this.docConfig = PRIVACY_DOC
    }

    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (ctx) {
      getSystemSafeTopVp(ctx).then((vp: number) => {
        this.safeTopVp = vp
      }).catch(()=>{})
    }
  }

  build() {
    Column() {
      // 沉浸式顶部导航栏 (极简设计)
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([AppColors.GRAY_900])
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { router.back() })

        Blank().layoutWeight(1) // 去除顶部居中标题，让页面更通透
      }
      .width('100%')
      .padding({ top: this.safeTopVp, bottom: 8 })
      .backgroundColor(Color.White) // 协议页使用纯白背景

      Scroll() {
        Column({ space: 0 }) {
          // 页面大标题与引言
          Column({ space: 16 }) {
            Text(this.docConfig.title)
              .fontSize(32)
              .fontWeight(FontWeight.Bolder)
              .fontColor(AppColors.GRAY_900)
              .width('100%')
              .textAlign(TextAlign.Start)
              .letterSpacing(-0.5)

            Text(this.docConfig.intro)
              .fontSize(15)
              .fontColor(AppColors.GRAY_500)
              .width('100%')
              .lineHeight(24)
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 16, bottom: 24 })

          // 协议正文内容区 (高行距、舒适排版)
          ForEach(this.docConfig.sections, (section: LegalDocSection) => {
            Column({ space: 12 }) {
              Text(section.heading)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.GRAY_900)
                .width('100%')
                .textAlign(TextAlign.Start)

              Text(section.body)
                .fontSize(15)
                .fontColor(AppColors.GRAY_800)
                .lineHeight(26) // 超大行距，缓解视觉疲劳
                .width('100%')
                .textAlign(TextAlign.Start)
                .opacity(0.85)
            }
            .width('100%')
            .padding({ left: 24, right: 24, top: 16, bottom: 16 })
          }, (section: LegalDocSection) => section.heading)
        }
        .width('100%')
        .padding({ bottom: 80 }) // 底部留足空间
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White) // 抛弃灰底色，通体纯白
  }
}