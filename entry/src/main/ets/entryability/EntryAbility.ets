import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { CookPreferences } from '../store/CookPreferences';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  /** 保存主窗口引用，用于主题切换时动态更新状态栏颜色 */
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 让应用跟随系统深色/浅色模式（不强制覆盖）
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    // 将当前系统深色状态写入 AppStorage，作为全局单一数据源
    // 所有页面通过 @StorageProp('isSystemDarkMode') 零延迟订阅
    const currentConfig: Configuration = this.context.config;
    const isDark: boolean =
      currentConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate<boolean>('isSystemDarkMode', isDark);
    // 注意：不在此处初始化 'currentThemeMode'，让 loadData 阶段从 Preferences 读取并写入。
    // 这样 AppStorage 在写入前为 undefined，loadData 可以正确判断"是 Preferences 值还是用户刚改的值"。

    hilog.info(DOMAIN, 'testTag', 'Ability onCreate, isDark=%{public}s', String(isDark));

    // 处理通知点击携带的推荐菜谱 ID
    this.handleRecommendIntent(want);

    // Preferences 预热（主题等数据依赖），不再在启动时重排提醒。
    // 每日推荐提醒是"daysOfWeek 每天重复"的闹钟，调度一次后无需重排；
    // 只有用户在设置页开关/改时间时才需要重新调度，否则每次冷启动都调用
    // scheduleOrUpdate 会导致旧提醒未被取消就累积，触发系统 exceed limit 错误。
    void CookPreferences.warmUp(this.context).catch(() => {
      hilog.error(DOMAIN, 'testTag', 'EntryAbility warmUp failed');
    });
  }

  /**
   * 通知点击后若 App 已在前台则通过 onNewWant 接收新的 Want。
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleRecommendIntent(want);
  }

  /** 从 want 中提取推荐标记并写入 AppStorage，供 IndexV2 读取 */
  private handleRecommendIntent(want: Want): void {
    const params = want.parameters;
    if (params === undefined || params === null) {
      return;
    }
    // 每日提醒通知点击：由系统闹钟携带的标记
    const fromReminder: Object = params['openFromDailyReminder'];
    if (fromReminder !== undefined && fromReminder !== null) {
      AppStorage.setOrCreate<boolean>('pendingDailyReminder', true);
    }
  }

  /**
   * 系统配置变更回调（含深色/浅色切换、语言切换等）。
   * AppStorage.setOrCreate 会同步通知所有 @StorageProp('isSystemDarkMode') 订阅者，
   * 无需轮询，延迟约为 ArkUI 单次重绘时间（< 16ms）。
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark: boolean =
      newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate<boolean>('isSystemDarkMode', isDark);
    hilog.info(DOMAIN, 'testTag', 'onConfigurationUpdate: isDark=%{public}s', String(isDark));

    // 同步更新状态栏与导航栏前景色
    this.syncStatusBarToTheme(isDark);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/StartupPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading content.');

      // 获取主窗口并应用沉浸式底栏 + 主题匹配状态栏
      windowStage.getMainWindow().then((win: window.Window) => {
        this.mainWindow = win;
        try {
          win.setWindowLayoutFullScreen(true);
        } catch {
          hilog.error(DOMAIN, 'testTag', 'setWindowLayoutFullScreen failed');
        }
        const isDark = AppStorage.get<boolean>('isSystemDarkMode') ?? false;
        this.syncStatusBarToTheme(isDark);
      }).catch(() => {
        hilog.error(DOMAIN, 'testTag', 'getMainWindow failed');
      });
    });
  }

  /**
   * 根据当前深色模式状态更新状态栏与导航栏的前景色（图标/文字颜色）。
   * 背景色设为透明，由页面背景透出，实现真正的沉浸式效果。
   */
  private syncStatusBarToTheme(isDark: boolean): void {
    if (this.mainWindow === null) {
      return;
    }
    try {
      this.mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: isDark ? '#FFFFFFFF' : '#E5000000',
        navigationBarContentColor: isDark ? '#FFFFFFFF' : '#E5000000',
      });
    } catch {
      hilog.error(DOMAIN, 'testTag', 'syncStatusBarToTheme failed');
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
