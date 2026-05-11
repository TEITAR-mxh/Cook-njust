/**
 * 每日推荐定时提醒服务
 * 封装 reminderAgentManager 的发布与取消逻辑，供 EntryAbility 和 SettingsPage 共用。
 * 提醒到达时由系统展示通知，用户点击后打开应用，IndexV2 负责动态选菜。
 */
import { common } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { CookPreferences } from '../store/CookPreferences'

const BUNDLE_NAME: string = 'com.example.cook';
const ENTRY_ABILITY_NAME: string = 'EntryAbility';

export class ReminderService {
  /**
   * 取消旧提醒并按当前 Preferences 中的时间重新调度。
   * SettingsPage 保存设置后调用；EntryAbility.onCreate 冷启动时调用。
   */
  static async scheduleOrUpdate(context: common.Context): Promise<void> {
    try {
      // 先取消旧提醒
      const oldId: number = await CookPreferences.getDailyReminderAgentId(context);
      if (oldId > 0) {
        try {
          await reminderAgentManager.cancelReminder(oldId);
        } catch {
          // 已过期或未找到，忽略
        }
      }

      const hour: number = await CookPreferences.getDailyRecommendHour(context);
      const minute: number = await CookPreferences.getDailyRecommendMinute(context);

      // 构造每日闹钟提醒：到点由系统展示通知，用户点击后应用动态选菜
      const reminder: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: hour,
        minute: minute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: '今日菜谱推荐',
        content: '今天想吃什么？点击查看为您精选的菜谱！',
        wantAgent: {
          pkgName: BUNDLE_NAME,
          abilityName: ENTRY_ABILITY_NAME,
          parameters: { openFromDailyReminder: true as Object }
        },
        tapDismissed: true
      };

      const newId: number = await reminderAgentManager.publishReminder(reminder);
      await CookPreferences.setDailyReminderAgentId(context, newId);
      console.info(`[ReminderService] Scheduled daily reminder at ${hour}:${String(minute).padStart(2, '0')}, id=${newId}`);
    } catch {
      console.error('[ReminderService] scheduleOrUpdate failed');
    }
  }

  /** 取消现有提醒，并清除存储的 ID */
  static async cancel(context: common.Context): Promise<void> {
    try {
      const oldId: number = await CookPreferences.getDailyReminderAgentId(context);
      if (oldId > 0) {
        try {
          await reminderAgentManager.cancelReminder(oldId);
        } catch {
          // 已过期，忽略
        }
        await CookPreferences.setDailyReminderAgentId(context, 0);
      }
    } catch {
      console.error('[ReminderService] cancel failed');
    }
  }
}
