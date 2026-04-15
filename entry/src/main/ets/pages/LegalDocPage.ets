import { router } from '@kit.ArkUI'
import { AppColors } from '../constants/AppColors'

class LegalDocSection {
  heading: string
  body: string

  constructor(heading: string, body: string) {
    this.heading = heading
    this.body = body
  }
}

class LegalDocConfig {
  title: string
  intro: string
  sections: LegalDocSection[]

  constructor(title: string, intro: string, sections: LegalDocSection[]) {
    this.title = title
    this.intro = intro
    this.sections = sections
  }
}

class LegalDocRouteParams {
  docType: string = ''
}

const PRIVACY_DOC: LegalDocConfig = new LegalDocConfig(
  '隐私政策',
  '本页面为本地富文本占位内容，用于应用市场合规自查与首次启动告知。',
  [
    new LegalDocSection(
      '1. 信息收集范围',
      '《AUV 您吃了么》V1.0 当前主要使用本地 Preferences 和 RelationalStore 保存食材选择、收藏、历史与菜谱数据，不主动上传个人身份信息。'
    ),
    new LegalDocSection(
      '2. 信息使用目的',
      '本地数据仅用于完成菜谱搜索、收藏同步、历史记录展示及个性化设置恢复，不用于广告投放或跨应用画像。'
    ),
    new LegalDocSection(
      '3. 信息存储与保护',
      '轻量设置使用 Preferences 存储，菜谱内容使用 RelationalStore 存储。用户关闭“保留本地数据”后，应用将清空对应本地偏好与记录。'
    ),
    new LegalDocSection(
      '4. 用户权利',
      '用户可在设置页查看数据统计、关闭本地数据保留、清空历史与收藏，并在后续版本中继续补齐更细粒度的数据导出与删除能力。'
    ),
    new LegalDocSection(
      '5. 联系与更新',
      '// TODO: 在正式上架前补充开发者联系方式、隐私负责人邮箱与政策生效日期。'
    )
  ]
)

const AGREEMENT_DOC: LegalDocConfig = new LegalDocConfig(
  '用户协议',
  '本页面为本地富文本占位内容，用于首次启动确认与设置页查看。',
  [
    new LegalDocSection(
      '1. 服务说明',
      '本应用为菜谱检索与烹饪辅助工具，展示内容主要来自本地菜谱数据，不构成医疗、营养或专业餐饮建议。'
    ),
    new LegalDocSection(
      '2. 使用规范',
      '用户应合理使用应用功能，不得利用本应用进行违法违规活动，不得恶意篡改、抓取或传播应用内受保护内容。'
    ),
    new LegalDocSection(
      '3. 免责声明',
      '因设备差异、食材质量、个人烹饪方式不同造成的口味、食品安全或营养结果差异，开发者不承担直接责任。'
    ),
    new LegalDocSection(
      '4. 数据与功能调整',
      '开发者可根据版本迭代对菜谱内容、推荐逻辑、界面样式及本地存储策略进行优化，并通过应用版本更新告知用户。'
    ),
    new LegalDocSection(
      '5. 其他条款',
      '// TODO: 在上架前补充完整法律主体、争议解决条款与协议生效时间。'
    )
  ]
)

function getDocConfig(docType: string): LegalDocConfig {
  if (docType === 'agreement') {
    return AGREEMENT_DOC
  }
  return PRIVACY_DOC
}

@Entry
@Component
struct LegalDocPage {
  @State docType: string = 'privacy'

  aboutToAppear(): void {
    const params = router.getParams() as Object | undefined
    if (params !== undefined) {
      const record = params as LegalDocRouteParams
      const nextType = record.docType
      if (typeof nextType === 'string' && nextType.length > 0) {
        this.docType = nextType
      }
    }
  }

  private get config(): LegalDocConfig {
    return getDocConfig(this.docType)
  }

  build() {
    Column() {
      Row() {
        Text('返回')
          .fontSize(16)
          .fontColor(AppColors.GRAY_900)
          .padding({ left: 8, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            router.back()
          })

        Text(this.config.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.GRAY_900)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank()
          .width(64)
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .backgroundColor(Color.White)
      .borderWidth({ bottom: 0.5 })
      .borderColor(AppColors.GRAY_200)

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 10 }) {
            Text(this.config.title)
              .fontSize(24)
              .fontWeight(FontWeight.Bolder)
              .fontColor(AppColors.GRAY_900)
              .width('100%')
              .textAlign(TextAlign.Start)

            Text(this.config.intro)
              .fontSize(13)
              .fontColor(AppColors.GRAY_500)
              .width('100%')
              .lineHeight(22)
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFF7F4')
          .borderRadius(20)

          ForEach(this.config.sections, (section: LegalDocSection) => {
            Column({ space: 8 }) {
              Text(section.heading)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.GRAY_900)
                .width('100%')
                .textAlign(TextAlign.Start)

              Text(section.body)
                .fontSize(14)
                .fontColor(AppColors.GRAY_600)
                .lineHeight(24)
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .width('100%')
            .padding(18)
            .backgroundColor(Color.White)
            .borderRadius(18)
          }, (section: LegalDocSection) => section.heading)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 40 })
      }
      .layoutWeight(1)
      .backgroundColor(AppColors.BG_COLOR)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_COLOR)
  }
}
