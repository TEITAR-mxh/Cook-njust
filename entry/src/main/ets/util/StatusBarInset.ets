import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';

/** 系统状态栏 / 挖孔等顶部避让高度（vp），用于全屏窗口下的顶栏 padding */
export async function getSystemSafeTopVp(context: common.Context): Promise<number> {
  const defaultVp = 48;
  try {
    const win = await window.getLastWindow(context);
    let px = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height;
    try {
      const cutPx = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT).topRect.height;
      if (cutPx > px) {
        px = cutPx;
      }
    } catch {
      // 部分设备无挖孔避让类型
    }
    if (px <= 0) {
      return defaultVp;
    }
    const dis = display.getDefaultDisplaySync();
    const dpi: number = dis.densityDPI;
    if (dpi <= 0) {
      return defaultVp;
    }
    return (px * 160) / dpi;
  } catch {
    return defaultVp;
  }
}
