import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { RecipeRepository } from '../data/RecipeRepository';
import { CookPreferences } from '../store/CookPreferences';
import { AppColors, ThemeManager } from '../constants/AppColors';
import { getSystemSafeTopVp } from '../util/StatusBarInset';
import { HistoryHeatmap } from '../components/HistoryHeatmap';

@Entry
@Component
struct HistoryPage {
  @State historyIds: number[] = []
  @State favoriteIds: number[] = []
  @State keepLocalData: boolean = true
  @State navTopInsetVp: number = 48
  @State datedHistoryJson: string = '{}'

  // ── 深色模式响应式订阅 ──────────────────────────────────────────────────────
  @StorageProp('isSystemDarkMode')
  @Watch('onThemeChange')
  private isSystemDark: boolean = false

  @StorageProp('currentThemeMode')
  @Watch('onThemeChange')
  private storedThemeMode: string = '系统默认'

  @State private bgColor: string = AppColors.BG_COLOR
  @State private cardBg: string = AppColors.CARD_BG
  @State private textColor: string = AppColors.GRAY_900
  @State private secondColor: string = AppColors.GRAY_500
  @State private dividerColor: string = AppColors.GRAY_100

  private onThemeChange(): void {
    this.applyTheme()
  }

  private applyTheme(): void {
    this.bgColor = ThemeManager.getBackgroundColor(this.storedThemeMode)
    this.cardBg = ThemeManager.getCardBackgroundColor(this.storedThemeMode)
    this.textColor = ThemeManager.getTextColor(this.storedThemeMode)
    this.secondColor = ThemeManager.getSecondaryTextColor(this.storedThemeMode)
    this.dividerColor = ThemeManager.getBorderColor(this.storedThemeMode)
  }

  aboutToAppear(): void {
    this.applyTheme()
    void this.load();
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx !== undefined) {
      void getSystemSafeTopVp(ctx).then((vp: number) => {
        this.navTopInsetVp = vp;
      });
    }
  }

  onPageShow(): void {
    void this.load();
    const ctx2 = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx2 !== undefined) {
      void getSystemSafeTopVp(ctx2).then((vp: number) => {
        this.navTopInsetVp = vp;
      });
    }
  }

  private async load(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host === undefined) {
      return;
    }
    try {
      if (RecipeRepository.getInstance().getCount() === 0) {
        await RecipeRepository.getInstance().load(host);
      }
      const settings = await CookPreferences.getSettings(host);
      this.keepLocalData = settings.keepLocalData;
      if (!this.keepLocalData) {
        this.historyIds = [];
        this.favoriteIds = [];
        return;
      }
      const dated = await CookPreferences.getDatedHistory(host);
      this.datedHistoryJson = JSON.stringify(dated);
      const rawH = await CookPreferences.getHistoryIds(host);
      const n = RecipeRepository.getInstance().getCount();
      const h: number[] = [];
      for (let i = 0; i < rawH.length; i++) {
        const id = rawH[i];
        if (id >= 0 && id < n) {
          h.push(id);
        }
      }
      this.historyIds = h;
      const rawF = await CookPreferences.getFavoriteIds(host);
      const f: number[] = [];
      for (let j = 0; j < rawF.length; j++) {
        const fid = rawF[j];
        if (fid >= 0 && fid < n) {
          f.push(fid);
        }
      }
      this.favoriteIds = f;
    } catch {
      console.error('HistoryPage.load failed');
    }
  }

  private isFavorite(id: number): boolean {
    for (let i = 0; i < this.favoriteIds.length; i++) {
      if (this.favoriteIds[i] === id) {
        return true;
      }
    }
    return false;
  }

  private onToggleFavorite(recipeId: number): void {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host === undefined || !this.keepLocalData) {
      return;
    }
    void CookPreferences.toggleFavoriteId(host, recipeId).then(() => {
      void this.load();
    });
  }

  private rowTitle(recipeId: number): string {
    const r = RecipeRepository.getInstance().getById(recipeId);
    if (r !== null) {
      return r.name;
    }
    return '';
  }

  private async clearAll(): Promise<void> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (host === undefined) {
      return;
    }
    try {
      await CookPreferences.clearHistory(host);
      this.historyIds = [];
    } catch {
      console.error('HistoryPage.clearAll failed');
    }
  }

  private confirmClearAll(): void {
    this.getUIContext().showAlertDialog({
      title: '清空浏览历史',
      message: '确定要清空全部浏览历史吗？此操作无法撤销。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '清空',
        fontColor: AppColors.BRAND_COLOR,
        action: () => { void this.clearAll() }
      },
      autoCancel: true
    })
  }

  @Builder
  historyRow(recipeId: number) {
    Row() {
      Row() {
        Text(this.rowTitle(recipeId))
          .fontSize(15)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(this.textColor)
      }
      .layoutWeight(1)

      if (this.keepLocalData) {
        Text(this.isFavorite(recipeId) ? '★' : '☆')
          .fontSize(22)
          .fontColor(this.isFavorite(recipeId) ? AppColors.FAVORITE_ACTIVE : this.secondColor)
          .padding({ left: 8, right: 4 })
          .onClick(() => {
            this.onToggleFavorite(recipeId);
          })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.cardBg)
    .borderRadius(12)
    .margin({ bottom: 8 })
  }

  build() {
    Column() {
      Column() {
        Row() {
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([this.textColor])
          }
          .width(56)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            try {
              this.getUIContext().getRouter().back();
            } catch {
              console.error('router.back failed');
            }
          })

          Text('浏览历史')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)

          Row() {
            if (this.keepLocalData && this.historyIds.length > 0) {
              Text('清空')
                .fontSize(15)
                .fontColor(AppColors.BRAND_COLOR)
                .onClick(() => {
                  this.confirmClearAll();
                })
            }
          }
          .width(56)
          .height(48)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ top: this.navTopInsetVp })
      .backgroundColor(this.bgColor)
      .borderWidth({ bottom: 1 })
      .borderColor(this.dividerColor)

      Scroll() {
        Column({ space: 0 }) {
          // 热力图
          if (this.keepLocalData) {
            Column() {
              HistoryHeatmap({ datedHistory: this.datedHistoryJson })
            }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })
          }

          if (this.keepLocalData && this.historyIds.length > 0) {
            Text(`共 ${this.historyIds.length} 条（新→旧）`)
              .fontSize(12)
              .fontColor(this.secondColor)
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 12, bottom: 8 })
          }

          if (!this.keepLocalData) {
            Text('开启「保留本地数据」后才会记录浏览历史')
              .fontSize(14)
              .fontColor(this.secondColor)
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 12 })
          } else if (this.historyIds.length === 0) {
            Column({ space: 12 }) {
              Text('暂无浏览历史')
                .fontSize(14)
                .fontColor(this.secondColor)
                .width('100%')
                .textAlign(TextAlign.Start)
              Button('去逛逛菜谱')
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor(AppColors.BRAND_COLOR)
                .borderRadius(20)
                .height(40)
                .padding({ left: 24, right: 24 })
                .onClick(() => {
                  try {
                    this.getUIContext().getRouter().back();
                  } catch {
                    console.error('router.back failed');
                  }
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 12 })
          } else {
            ForEach(this.historyIds, (recipeId: number) => {
              this.historyRow(recipeId);
            }, (recipeId: number) => `h-${recipeId}`)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
        .padding({ left: 20, right: 20, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.bgColor)
  }
}
