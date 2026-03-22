import { common } from '@kit.AbilityKit';
import { meatItems, stapleItems, toolItems, vegetableItems } from '../data/foodCatalog';
import { RecipeRepository } from '../data/RecipeRepository';
import type { RecipeWithId, SearchMode, StuffItem } from '../model/recipe';
import { RecipeSearchService } from '../service/RecipeSearchService';
import { CookPreferences } from '../store/CookPreferences';

@Entry
@Component
struct Index {
  @State mainTabIndex: number = 0
  @State status: string = '加载中…'
  @State recipeCount: number = 0
  @State errHint: string = ''
  @State keepLocalData: boolean = true
  @State selectedStuff: string[] = []
  @State curTool: string = ''
  @State searchMode: SearchMode = 'loose'
  @State keyword: string = ''
  @State searchHits: RecipeWithId[] = []

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
      if (this.keepLocalData) {
        this.selectedStuff = await CookPreferences.getSelectedStuff(host);
        this.curTool = await CookPreferences.getCurTool(host);
        this.searchMode = await CookPreferences.getSearchMode(host);
      }
    } catch {
      this.keepLocalData = true;
      console.error('CookPreferences.getSettings failed');
    }
    this.runSearch();
  }

  private runSearch(): void {
    const all = RecipeRepository.getInstance().getAll();
    this.searchHits = RecipeSearchService.search(all, this.selectedStuff, this.curTool, this.searchMode, this.keyword.trim());
  }

  private async persistCookIfNeeded(): Promise<void> {
    if (!this.keepLocalData) {
      return;
    }
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      return;
    }
    await CookPreferences.setSelectedStuff(host, this.selectedStuff);
    await CookPreferences.setCurTool(host, this.curTool);
    await CookPreferences.setSearchMode(host, this.searchMode);
  }

  private chipLabel(item: StuffItem): string {
    const em = item.emoji;
    if (em.length > 0) {
      return `${em} ${item.name}`;
    }
    return item.name;
  }

  private toggleStuff(name: string): void {
    const idx = this.selectedStuff.indexOf(name);
    if (idx >= 0) {
      const next: string[] = [];
      for (let i = 0; i < this.selectedStuff.length; i++) {
        if (i !== idx) {
          next.push(this.selectedStuff[i]);
        }
      }
      this.selectedStuff = next;
    } else {
      this.selectedStuff = this.selectedStuff.concat([name]);
    }
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private toggleTool(name: string): void {
    this.curTool = this.curTool === name ? '' : name;
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private applySearchMode(mode: SearchMode): void {
    this.searchMode = mode;
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private resetSelection(): void {
    this.selectedStuff = [];
    this.curTool = '';
    this.runSearch();
    void this.persistCookIfNeeded();
  }

  private async onKeepLocalChange(isOn: boolean): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!host) {
      return;
    }
    try {
      await CookPreferences.setKeepLocalData(host, isOn);
      this.keepLocalData = isOn;
      if (!isOn) {
        await CookPreferences.clearCookPersisted(host);
      } else {
        this.selectedStuff = await CookPreferences.getSelectedStuff(host);
        this.curTool = await CookPreferences.getCurTool(host);
        this.searchMode = await CookPreferences.getSearchMode(host);
      }
      this.runSearch();
    } catch {
      console.error('CookPreferences.setKeepLocalData failed');
    }
  }

  private modeButtonBg(mode: SearchMode): string {
    return this.searchMode === mode ? '#C8E6C9' : '#EEEEEE';
  }

  private tabLabelColor(idx: number): string {
    return this.mainTabIndex === idx ? '#18A058' : '#666666';
  }

  private tabFontWeight(idx: number): FontWeight {
    return this.mainTabIndex === idx ? FontWeight.Medium : FontWeight.Normal;
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .margin({ top: 8, bottom: 6 })
      .alignSelf(ItemAlign.Start)
  }

  @Builder
  chipWrap(items: StuffItem[], isTool: boolean) {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
      ForEach(items, (item: StuffItem) => {
        Text(this.chipLabel(item))
          .fontSize(13)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor(isTool ?
            (this.curTool === item.name ? '#C8E6C9' : '#EFEFEF') :
            (this.selectedStuff.includes(item.name) ? '#C8E6C9' : '#EFEFEF'))
          .borderRadius(16)
          .onClick(() => {
            if (isTool) {
              this.toggleTool(item.name);
            } else {
              this.toggleStuff(item.name);
            }
          })
      }, (item: StuffItem) => item.name)
    }
    .width('100%')
  }

  @Builder
  buildCookTab() {
    Column() {
      Scroll() {
        Column({ space: 8 }) {
          Row() {
            Text('好的，今天我们来做菜！')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            Text('清空')
              .fontSize(14)
              .fontColor('#18A058')
              .onClick(() => {
                this.resetSelection();
              })
          }
          .width('100%')

          Text(`${this.status} · 全库 ${this.recipeCount} 条`)
            .fontSize(12)
            .fontColor('#888888')

          if (this.errHint.length > 0) {
            Text(this.errHint)
              .fontSize(12)
              .fontColor(Color.Red)
          }

          Text('匹配模式')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 4 })

          Row({ space: 8 }) {
            Text('模糊')
              .fontSize(13)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(this.modeButtonBg('loose'))
              .borderRadius(8)
              .onClick(() => {
                this.applySearchMode('loose');
              })
            Text('严格')
              .fontSize(13)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(this.modeButtonBg('strict'))
              .borderRadius(8)
              .onClick(() => {
                this.applySearchMode('strict');
              })
            Text('生存')
              .fontSize(13)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(this.modeButtonBg('survival'))
              .borderRadius(8)
              .onClick(() => {
                this.applySearchMode('survival');
              })
          }

          TextInput({ placeholder: '搜索菜名', text: this.keyword })
            .width('100%')
            .height(40)
            .onChange((v: string) => {
              this.keyword = v;
              this.runSearch();
            })
            .margin({ top: 4 })

          this.sectionTitle('素菜');
          this.chipWrap(vegetableItems, false);

          this.sectionTitle('荤菜');
          this.chipWrap(meatItems, false);

          this.sectionTitle('主食');
          this.chipWrap(stapleItems, false);

          this.sectionTitle('厨具');
          this.chipWrap(toolItems, true);

          Text(`匹配结果 ${this.searchHits.length} 条`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 12, bottom: 8 })
            .alignSelf(ItemAlign.Start)

          ForEach(this.searchHits, (item: RecipeWithId) => {
            Row() {
              Text(item.name)
                .fontSize(15)
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text((item.difficulty !== undefined && item.difficulty.length > 0) ? item.difficulty : ' ')
                .fontSize(12)
                .fontColor('#888888')
                .width(40)
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#F9F9F9')
            .borderRadius(8)
            .margin({ bottom: 8 })
          }, (item: RecipeWithId) => item.id.toString())
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
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
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
