import { common } from '@kit.AbilityKit';
import { RecipeRepository } from '../data/RecipeRepository';

@Entry
@Component
struct Index {
  @State status: string = '加载中…'
  @State recipeCount: number = 0
  @State errHint: string = ''

  aboutToAppear(): void {
    void this.loadRecipes();
  }

  private async loadRecipes(): Promise<void> {
    try {
      const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (!host) {
        this.status = '加载失败';
        this.errHint = '无法获取 UIAbility 上下文';
        return;
      }
      await RecipeRepository.getInstance().load(host);
      this.recipeCount = RecipeRepository.getInstance().getCount();
      this.status = '菜谱已加载';
      this.errHint = '';
    } catch (e) {
      this.status = '加载失败';
      this.recipeCount = 0;
      this.errHint = e instanceof Error ? e.message : String(e);
      console.error(`Recipe load error: ${this.errHint}`);
    }
  }

  build() {
    Column({ space: 12 }) {
      Text(this.status)
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Medium)

      Text(`菜谱条数：${this.recipeCount}`)
        .fontSize(16)

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
