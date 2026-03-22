import { common, Want } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import type { RecipeWithId } from '../model/recipe';
import { CookPreferences } from '../store/CookPreferences';

interface HostWithOpenLink {
  openLink?: (url: string) => Promise<void>
}

/**
 * 从做菜 / 菜谱 / 历史 / 收藏等页打开菜谱视频链接的共用逻辑。
 */
export class RecipeVideoLauncher {
  static recipeVideoUri(item: RecipeWithId): string | null {
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

  static async openExternalUri(host: common.UIAbilityContext, uri: string): Promise<void> {
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
      await RecipeVideoLauncher.copyUriAndToast(uri);
    }
  }

  private static async copyUriAndToast(uri: string): Promise<void> {
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

  static open(
    host: common.UIAbilityContext,
    item: RecipeWithId,
    keepLocalData: boolean,
    onHistoryRecorded?: () => void,
  ): void {
    const uri = RecipeVideoLauncher.recipeVideoUri(item);
    if (uri === null) {
      return;
    }
    if (keepLocalData) {
      void CookPreferences.recordHistoryVisit(host, item.id).then(() => {
        if (onHistoryRecorded !== undefined) {
          onHistoryRecorded();
        }
      });
    }
    void RecipeVideoLauncher.openExternalUri(host, uri);
  }
}
