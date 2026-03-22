import { common, Want } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { meatItems, stapleItems, toolItems, vegetableItems } from '../data/foodCatalog';
import { RecipeRepository } from '../data/RecipeRepository';
import type { RecipeWithId, SearchMode, StuffItem } from '../model/recipe';
import { RecipeSearchService } from '../service/RecipeSearchService';
import { CookPreferences } from '../store/CookPreferences';

/** UIAbilityContext 上的 openLink 在类型声明里可能未体现，单独声明以符合 ArkTS（禁止交叉类型） */
interface HostWithOpenLink {
  openLink?: (url: string) => Promise<void>
}

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
  @State libraryKeyword: string = ''
  @State libraryHits: RecipeWithId[] = []
  /** 发现 Tab：随机选中的菜谱；id 为 -1 表示未选 */
  @State discoverPick: RecipeWithId = { id: -1, name: '', stuff: [], tools: [] }
  @State discoverNoVideoHint: string = ''

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
    this.runLibrarySearch();
  }

  private runSearch(): void {
    const all = RecipeRepository.getInstance().getAll();
    this.searchHits = RecipeSearchService.search(all, this.selectedStuff, this.curTool, this.searchMode, this.keyword.trim());
  }

  private runLibrarySearch(): void {
    const all = RecipeRepository.getInstance().getAll();
    this.libraryHits = RecipeSearchService.filterLibraryByName(all, this.libraryKeyword);
  }

  private emptyDiscoverPick(): RecipeWithId {
    const r: RecipeWithId = { id: -1, name: '', stuff: [], tools: [] };
    return r;
  }

  /** 从全库中随机选一道「可打开视频」的菜谱 */
  private pickRandomDiscover(): void {
    const all = RecipeRepository.getInstance().getAll();
    const candidates: RecipeWithId[] = [];
    for (let i = 0; i < all.length; i++) {
      const it = all[i];
      if (this.recipeVideoUri(it) !== null) {
        candidates.push(it);
      }
    }
    if (candidates.length === 0) {
      this.discoverPick = this.emptyDiscoverPick();
      if (all.length > 0) {
        this.discoverNoVideoHint = '暂无可打开视频的菜谱';
      } else {
        this.discoverNoVideoHint = '';
      }
      return;
    }
    this.discoverNoVideoHint = '';
    const idx = Math.floor(Math.random() * candidates.length);
    this.discoverPick = candidates[idx];
  }

  /** 与 Web 一致：优先 link，否则 bilibili.com/video/{bv} */
  private recipeVideoUri(item: RecipeWithId): string | null {
    if (item.link !== undefined && item.link.trim().length > 0) {
      return item.link.trim();
    }
    if (item.bv !== undefined && item.bv.trim().length > 0) {
      const bv = item.bv.trim();
      if (bv.startsWith('http://') || bv.startsWith('https://')) {
        return bv;
      }
      return `https://www.bilibili.com/video/${bv}`;
    }
    return null;
  }

  /** 使用系统浏览器打开链接；模拟器上 startAbility 常无响应，会复制链接并 Toast */
  private openRecipeVideo(item: RecipeWithId): void {
    const uri = this.recipeVideoUri(item);
    if (uri === null) {
      return;
    }
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host === undefined) {
      return;
    }
    if (this.keepLocalData) {
      void CookPreferences.recordHistoryVisit(host, item.id);
    }
    void this.openExternalUri(host, uri);
  }

  private async openExternalUri(host: common.UIAbilityContext, uri: string): Promise<void> {
    const withOpen = host as HostWithOpenLink;
    if (withOpen.openLink !== undefined) {
      try {
        await withOpen.openLink(uri);
        return;
      } catch {
        console.error('openExternalUri: openLink failed');
      }
    }

    const wants: Want[] = [
      {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: uri,
      },
      {
        action: 'ohos.want.action.view',
        entities: ['entity.system.browsable'],
        uri: uri,
      },
    ];

    let opened = false;
    for (const want of wants) {
      try {
        const ret = host.startAbility(want);
        if (ret instanceof Promise) {
          try {
            await ret;
            opened = true;
            break;
          } catch {
            console.error('openExternalUri: startAbility rejected');
          }
        }
      } catch {
        console.error('openExternalUri: startAbility threw');
      }
    }

    if (!opened) {
      await this.copyUriAndToast(uri);
    }
  }

  private async copyUriAndToast(uri: string): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, uri);
      await pasteboard.getSystemPasteboard().setData(data);
      await promptAction.showToast({
        message: '链接已复制，可在浏览器粘贴打开',
        duration: 2500,
      });
    } catch {
      try {
        await promptAction.showToast({
          message: '无法打开外链，请使用真机或在浏览器手动打开',
          duration: 2500,
        });
      } catch {
        // ignore
      }
    }
  }

  private recipeRowClickable(item: RecipeWithId): boolean {
    return this.recipeVideoUri(item) !== null;
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
  recipeHitRow(item: RecipeWithId) {
    Row() {
      Text(item.name)
        .fontSize(15)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(this.recipeRowClickable(item) ? '#18A058' : Color.Black)
      Text((item.difficulty !== undefined && item.difficulty.length > 0) ? item.difficulty : ' ')
        .fontSize(12)
        .fontColor('#888888')
        .width(40)
      if (this.recipeRowClickable(item)) {
        Text('›')
          .fontSize(18)
          .fontColor('#CCCCCC')
          .padding({ left: 4 })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F9F9F9')
    .borderRadius(8)
    .margin({ bottom: 8 })
    .onClick(() => {
      this.openRecipeVideo(item);
    })
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
            this.recipeHitRow(item);
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
      Scroll() {
        Column({ space: 8 }) {
          Text('菜谱')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          Text(`${this.status} · 全库 ${this.recipeCount} 条`)
            .fontSize(12)
            .fontColor('#888888')
            .alignSelf(ItemAlign.Start)

          if (this.errHint.length > 0) {
            Text(this.errHint)
              .fontSize(12)
              .fontColor(Color.Red)
              .alignSelf(ItemAlign.Start)
          }

          TextInput({ placeholder: '搜索菜名', text: this.libraryKeyword })
            .width('100%')
            .height(40)
            .onChange((v: string) => {
              this.libraryKeyword = v;
              this.runLibrarySearch();
            })
            .margin({ top: 4 })

          Text(`列表 ${this.libraryHits.length} 条`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 12, bottom: 8 })
            .alignSelf(ItemAlign.Start)

          if (this.libraryHits.length === 0) {
            Text(this.recipeCount === 0 ? '暂无菜谱数据' : '暂无匹配的菜名')
              .fontSize(14)
              .fontColor('#888888')
              .alignSelf(ItemAlign.Start)
          } else {
            ForEach(this.libraryHits, (item: RecipeWithId) => {
              this.recipeHitRow(item);
            }, (item: RecipeWithId) => item.id.toString())
          }
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
  buildDiscoverTab() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Text('发现')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          Text('不知道吃什么？随机从全库挑一道能看视频的。')
            .fontSize(14)
            .fontColor('#888888')
            .alignSelf(ItemAlign.Start)

          if (this.errHint.length > 0) {
            Text(this.errHint)
              .fontSize(12)
              .fontColor(Color.Red)
              .alignSelf(ItemAlign.Start)
          }

          Row({ space: 12 }) {
            Text('随机一道')
              .fontSize(15)
              .fontColor(Color.White)
              .padding({ left: 20, right: 20, top: 10, bottom: 10 })
              .backgroundColor('#18A058')
              .borderRadius(8)
              .onClick(() => {
                this.pickRandomDiscover();
              })

            if (this.discoverPick.id >= 0) {
              Text('换一道')
                .fontSize(15)
                .fontColor('#18A058')
                .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                .backgroundColor('#E8F5E9')
                .borderRadius(8)
                .onClick(() => {
                  this.pickRandomDiscover();
                })
            }
          }
          .margin({ top: 8 })
          .alignSelf(ItemAlign.Start)

          if (this.discoverNoVideoHint.length > 0) {
            Text(this.discoverNoVideoHint)
              .fontSize(14)
              .fontColor('#888888')
              .alignSelf(ItemAlign.Start)
              .margin({ top: 12 })
          }

          if (this.recipeCount === 0) {
            Text('暂无菜谱数据')
              .fontSize(14)
              .fontColor('#888888')
              .alignSelf(ItemAlign.Start)
              .margin({ top: 16 })
          } else if (this.discoverPick.id < 0) {
            if (this.discoverNoVideoHint.length === 0) {
              Text('点击「随机一道」开始')
                .fontSize(14)
                .fontColor('#888888')
                .alignSelf(ItemAlign.Start)
                .margin({ top: 16 })
            }
          } else {
            Column({ space: 8 }) {
              Text('今日推荐')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ top: 8 })

              this.recipeHitRow(this.discoverPick);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
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
