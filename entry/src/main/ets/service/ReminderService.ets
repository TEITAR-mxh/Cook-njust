/**
 * 每日推荐定时提醒服务
 * 封装 reminderAgentManager 的发布与取消逻辑，供 EntryAbility 和 SettingsPage 共用。
 */
import { common } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { CookPreferences } from '../store/CookPreferences'

const BUNDLE_NAME: string        = 'com.example.cook_njust_project';
const ENTRY_ABILITY_NAME: string = 'EntryAbility';

/** reminderAgentManager 返回的提醒对象中携带的 id 字段（内部扩展，非公开类型） */
interface ReminderWithId {
  reminderId?: number
}

export class ReminderService {

  /**
   * 清除本 App 所有提醒：先尝试 cancelAllReminders，
   * 若失败则回退到逐条取消（通过 getValidReminders 获取 ID）。
   * 清除失败时抛出异常，调用方不应继续调用 publishReminder。
   */
  private static async cancelAll(): Promise<void> {
    // 主路径：cancelAllReminders
    try {
      await reminderAgentManager.cancelAllReminders();
      return;
    } catch (e) {
      const err = e as BusinessError;
      console.warn(`[ReminderService] cancelAllReminders failed (code=${err.code}), trying per-id fallback`);
    }

    // 回退路径：逐条取消
    try {
      const list = await reminderAgentManager.getValidReminders();
      for (const r of list) {
        const id = (r as ReminderWithId).reminderId;
        if (id !== undefined && id > 0) {
          try {
            await reminderAgentManager.cancelReminder(id);
          } catch { /* 单条取消失败时跳过 */ }
        }
      }
    } catch (e) {
      const err = e as BusinessError;
      // 两条路径均失败 → 抛出，让调用方不进入 publishReminder（否则必报 1700002）
      throw new Error(`[${err.code}] 无法清除旧提醒，请重装应用后重试`);
    }
  }

  /**
   * 取消本 App 全部现存提醒，再按 Preferences 中的时间重新调度。
   * cancelAll 失败时直接抛出，不继续 publishReminder（否则必报 1700002）。
   */
  static async scheduleOrUpdate(context: common.Context): Promise<void> {
    // 清空旧提醒；失败时抛出，不进入 publishReminder
    await ReminderService.cancelAll();

    const hour:   number = await CookPreferences.getDailyRecommendHour(context);
    const minute: number = await CookPreferences.getDailyRecommendMinute(context);

    const reminder: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour:         hour,
      minute:       minute,
      daysOfWeek:   [1, 2, 3, 4, 5, 6, 7],
      title:        '您吃了么',
      content:      '今天想吃什么？已为您精选好菜，点击查看！',
      tapDismissed: true,
      wantAgent: {
        pkgName:     BUNDLE_NAME,
        abilityName: ENTRY_ABILITY_NAME,
        parameters:  { openFromDailyReminder: '1' as Object }
      }
    };

    try {
      const newId: number = await reminderAgentManager.publishReminder(reminder);
      await CookPreferences.setDailyReminderAgentId(context, newId);
      console.info(
        `[ReminderService] Scheduled at ${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}, id=${newId}`
      );
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[ReminderService] publishReminder failed: code=${err.code}, msg=${err.message}`);
      // 常见错误码友好提示
      if (err.code === 1700002) {
        throw new Error('提醒数量已达系统上限，请先清理其他应用的提醒后重试')
      }
      throw new Error(`[${err.code}] ${err.message}`);
    }
  }

  /** 取消现有提醒并清除存储的 ID */
  static async cancel(context: common.Context): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
      await CookPreferences.setDailyReminderAgentId(context, 0);
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[ReminderService] cancel failed: code=${err.code}`);
    }
  }
}
