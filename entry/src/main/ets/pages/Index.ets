import { common } from '@kit.AbilityKit';
import { RecipeRepository } from '../data/RecipeRepository';
import { CookPreferences } from '../store/CookPreferences';

@Entry
@Component
struct Index {
  @State mainTabIndex: number = 0
  @State status: string = '加载中…'
  @State recipeCount: number = 0
  @State errHint: string = ''
  @State keepLocalData: boolean = true

  aboutToAppear(): void {
    void this.bootstrapData();
  }

  private async bootstrapData(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      this.status = '加载失败';
      this.errHint = '无法获取 UIAbility 上下文';
      return;
    }
    try {
      await RecipeRepository.getInstance().load(host);
      this.recipeCount = RecipeRepository.getInstance().getCount();
      this.status = '菜谱已加载';
      this.errHint = '';
    } catch {
      this.status = '加载失败';
      this.recipeCount = 0;
      this.errHint = '菜谱数据加载失败';
      console.error('RecipeRepository.load failed');
      return;
    }
    try {
      const settings = await CookPreferences.getSettings(host);
      this.keepLocalData = settings.keepLocalData;
    } catch {
      this.keepLocalData = true;
      console.error('CookPreferences.getSettings failed');
    }
  }

  private async onKeepLocalChange(isOn: boolean): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      return;
    }
    try {
      await CookPreferences.setKeepLocalData(host, isOn);
      this.keepLocalData = isOn;
    } catch {
      console.error('CookPreferences.setKeepLocalData failed');
    }
  }

  private tabLabelColor(idx: number): string {
    return this.mainTabIndex === idx ? '#18A058' : '#666666';
  }

  private tabFontWeight(idx: number): FontWeight {
    return this.mainTabIndex === idx ? FontWeight.Medium : FontWeight.Normal;
  }

  @Builder
  buildCookTab() {
    Column({ space: 16 }) {
      Text('好的，今天我们来做菜！')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)

      Text(this.status)
        .fontSize($r('app.float.page_text_font_size'))

      Text(`菜谱条数：${this.recipeCount}`)
        .fontSize(16)

      if (this.errHint.length > 0) {
        Text(this.errHint)
          .fontSize(12)
          .fontColor(Color.Red)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Text('选食材与匹配结果（开发中）')
        .fontSize(14)
        .fontColor('#888888')
        .margin({ top: 24 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildLibraryTab() {
    Column() {
      Text('菜谱')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })
      Text('全库浏览与搜索（开发中）')
        .fontSize(14)
        .fontColor('#888888')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildDiscoverTab() {
    Column() {
      Text('发现')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 12 })
      Text('今天吃什么等入口（开发中）')
        .fontSize(14)
        .fontColor('#888888')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildMyTab() {
    Column({ space: 20 }) {
      Text('我的')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)

      Row({ space: 12 }) {
        Text('保留本地选料等数据')
          .fontSize(16)
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.keepLocalData })
          .onChange((isOn: boolean) => {
            void this.onKeepLocalChange(isOn);
          })
      }
      .width('100%')

      Text('历史、收藏、关于等（开发中）')
        .fontSize(14)
        .fontColor('#888888')
        .alignSelf(ItemAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Column() {
        if (this.mainTabIndex === 0) {
          this.buildCookTab();
        } else if (this.mainTabIndex === 1) {
          this.buildLibraryTab();
        } else if (this.mainTabIndex === 2) {
          this.buildDiscoverTab();
        } else {
          this.buildMyTab();
        }
      }
      .width('100%')
      .layoutWeight(1)

      Row() {
        Column({ space: 4 }) {
          Text('做菜')
            .fontSize(12)
            .fontColor(this.tabLabelColor(0))
            .fontWeight(this.tabFontWeight(0))
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.mainTabIndex = 0;
        })

        Column({ space: 4 }) {
          Text('菜谱')
            .fontSize(12)
            .fontColor(this.tabLabelColor(1))
            .fontWeight(this.tabFontWeight(1))
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.mainTabIndex = 1;
        })

        Column({ space: 4 }) {
          Text('发现')
            .fontSize(12)
            .fontColor(this.tabLabelColor(2))
            .fontWeight(this.tabFontWeight(2))
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.mainTabIndex = 2;
        })

        Column({ space: 4 }) {
          Text('我的')
            .fontSize(12)
            .fontColor(this.tabLabelColor(3))
            .fontWeight(this.tabFontWeight(3))
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.mainTabIndex = 3;
        })
      }
      .width('100%')
      .height(52)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}
