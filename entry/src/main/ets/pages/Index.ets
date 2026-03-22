import { common } from '@kit.AbilityKit';
import { RecipeRepository } from '../data/RecipeRepository';
import { CookPreferences } from '../store/CookPreferences';

@Entry
@Component
struct Index {
  @State status: string = '加载中…'
  @State recipeCount: number = 0
  @State errHint: string = ''
  @State keepLocalData: boolean = true

  aboutToAppear(): void {
    void this.loadRecipes();
  }

  private async loadRecipes(): Promise<void> {
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

  build() {
    Column({ space: 16 }) {
      Text(this.status)
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Medium)

      Text(`菜谱条数：${this.recipeCount}`)
        .fontSize(16)

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
      .padding({ left: 24, right: 24 })

      if (this.errHint.length > 0) {
        Text(this.errHint)
          .fontSize(12)
          .fontColor(Color.Red)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 24, right: 24 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .width('100%')
  }
}
