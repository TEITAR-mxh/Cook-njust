/**
 * 每日推荐定时提醒服务
 * 封装 reminderAgentManager 的发布与取消逻辑，供 EntryAbility 和 SettingsPage 共用。
 */
import { common } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { CookPreferences } from '../store/CookPreferences'
import { RecipeRepository } from '../data/RecipeRepository'
import { DailyRecommendService } from './DailyRecommendService'
import type { RecommendResult } from './DailyRecommendService'
import { getDriForProfile } from './NutritionCalculator'

const BUNDLE_NAME: string        = 'com.example.cook_njust_project';
const ENTRY_ABILITY_NAME: string = 'EntryAbility';

/** reminderAgentManager 返回的提醒对象中携带的 id 字段（内部扩展，非公开类型） */
interface ReminderWithId {
  reminderId?: number
}

export class ReminderService {

  /** 串行执行调度：避免首页每日刷新与设置页同时 cancel/publish 交错，产生重复提醒 */
  private static queue: Promise<void> = Promise.resolve();

  /**
   * 清除本 App 所有提醒：cancelAllReminders 之后再用 getValidReminders 核对并逐条取消。
   * 逐条核对不仅是兜底，也是排查 1700002 的关键日志（能看到系统里实际残留多少条）。
   */
  private static async cancelAll(): Promise<void> {
    let cancelAllOk: boolean = false;

    try {
      await reminderAgentManager.cancelAllReminders();
      cancelAllOk = true;
    } catch (e) {
      const err = e as BusinessError;
      console.warn(`[ReminderService] cancelAllReminders failed: code=${err.code}, msg=${err.message}`);
    }

    let listOk: boolean = false;
    try {
      const list = await reminderAgentManager.getValidReminders();
      listOk = true;
      if (list.length > 0) {
        console.info(`[ReminderService] ${list.length} valid reminder(s) remained after cancelAll, cancelling by id`);
      }
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
      console.warn(`[ReminderService] getValidReminders failed: code=${err.code}, msg=${err.message}`);
    }

    if (!cancelAllOk && !listOk) {
      throw new Error('无法清除旧提醒，请重装应用后重试');
    }
  }

  /**
   * 按用户偏好预选一道「今日灵感」菜谱，并把 ID 与刷新日期写入 Preferences，
   * 供通知正文点名和点击通知后直接打开。菜谱库不可用时返回 null（退化为通用文案）。
   */
  private static async pickReminderRecipe(context: common.Context): Promise<RecommendResult | null> {
    try {
      const repo = RecipeRepository.getInstance();
      if (repo.getCount() === 0) {
        await repo.load(context);
      }
      const all = repo.getAll();
      if (all.length === 0) return null;

      const preference = await CookPreferences.getDailyRecommendPreference(context);
      const selectedStuff = await CookPreferences.getSelectedStuff(context);
      const historyIds = await CookPreferences.getRecommendHistory(context);
      const profile = await CookPreferences.getDietProfile(context);
      const stuffForPick: string[] = preference === 'fridge_first' ? selectedStuff : [];
      // 单道菜不超过每日目标的 40%，避免减脂用户收到一道就吃满额度的推荐
      const maxCalories: number = getDriForProfile(profile).calories * 0.4;

      const result = DailyRecommendService.pickRecipe(all, stuffForPick, historyIds, maxCalories);
      if (result !== null) {
        await CookPreferences.addToRecommendHistory(context, result.recipe.id);
      }
      return result;
    } catch (e) {
      const err = e as BusinessError;
      console.warn(`[ReminderService] pickReminderRecipe failed: ${err.message}`);
      return null;
    }
  }

  /**
   * 取消本 App 全部现存提醒，再按 Preferences 中的时间重新调度。
   * 通过队列串行执行，保证任意时刻只有一个 cancel+publish 流程。
   */
  static scheduleOrUpdate(context: common.Context): Promise<void> {
    const job: Promise<void> = ReminderService.queue
      .then(() => ReminderService.doScheduleOrUpdate(context));
    // 队列自身吞掉错误，继续接受下一次调度；调用方仍能从 job 拿到失败
    ReminderService.queue = job.then(() => {}).catch(() => {});
    return job;
  }

  private static async doScheduleOrUpdate(context: common.Context): Promise<void> {
    // 清空旧提醒；失败时抛出，不进入 publishReminder
    await ReminderService.cancelAll();

    const hour:   number = await CookPreferences.getDailyRecommendHour(context);
    const minute: number = await CookPreferences.getDailyRecommendMinute(context);

    // 预选一道菜，让通知标题点名具体菜谱
    const pick: RecommendResult | null = await ReminderService.pickReminderRecipe(context);
    const recipeId: number = pick !== null ? pick.recipe.id : 0;
    const title: string = pick !== null ? `今日灵感 · ${pick.recipe.name}` : '您吃了么';
    const content: string = pick !== null
      ? `${pick.reason}，点击查看做法`
      : '今天想吃什么？已为您精选好菜，点击查看！';

    const reminder: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour:         hour,
      minute:       minute,
      daysOfWeek:   [1, 2, 3, 4, 5, 6, 7],
      title:        title,
      content:      content,
      tapDismissed: true,
      wantAgent: {
        pkgName:     BUNDLE_NAME,
        abilityName: ENTRY_ABILITY_NAME,
        // 把这条提醒点名的菜谱 ID 一并带上：即使之后 App 内又刷新了通知内容，
        // 用户点这条通知仍然打开文案里那道菜
        parameters:  {
          openFromDailyReminder: '1' as Object,
          dailyReminderRecipeId: String(recipeId) as Object
        }
      }
    };

    let newId: number = -1;
    try {
      newId = await reminderAgentManager.publishReminder(reminder);
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[ReminderService] publishReminder failed: code=${err.code}, msg=${err.message}`);

      // 1700002 有两种常见原因：旧提醒尚未释放，或应用缺少「代理提醒」权限。
      // 先彻底清理并稍等片刻重试一次；仍失败再抛出可操作的提示。
      if (err.code === 1700002) {
        try {
          await ReminderService.cancelAll();
        } catch (cleanupErr) {
          console.warn(`[ReminderService] cleanup before retry failed: ${(cleanupErr as Error).message}`);
        }
        await ReminderService.sleep(600);
        try {
          newId = await reminderAgentManager.publishReminder(reminder);
        } catch (e2) {
          const err2 = e2 as BusinessError;
          console.error(`[ReminderService] publishReminder retry failed: code=${err2.code}, msg=${err2.message}`);
          throw new Error('系统拒绝发布提醒（1700002）：请确认通知权限已开启；若仍失败，应用可能缺少「代理提醒」权限，需在 AGC 开通后重新签名安装');
        }
      } else {
        throw new Error(`[${err.code}] ${err.message}`);
      }
    }

    await CookPreferences.setDailyReminderAgentId(context, newId);
    await CookPreferences.setDailyReminderRecipeId(context, recipeId);
    await CookPreferences.setDailyReminderDate(context, ReminderService.todayKey());
    console.info(
      `[ReminderService] Scheduled at ${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}` +
      `, recipeId=${recipeId}, id=${newId}`
    );
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => { resolve(); }, ms);
    });
  }

  /** 取消现有提醒并清除存储的 ID / 点名菜谱 / 刷新日期 */
  static async cancel(context: common.Context): Promise<void> {
    try {
      await ReminderService.cancelAll();
    } catch (e) {
      console.error(`[ReminderService] cancel failed: ${(e as Error).message}`);
    }
    // 无论系统侧是否取消失败，本地状态都回到「未调度」，避免误判为已开启
    await CookPreferences.setDailyReminderAgentId(context, 0);
    await CookPreferences.setDailyReminderRecipeId(context, 0);
    await CookPreferences.setDailyReminderDate(context, '');
  }

  /** 本地日期键 YYYY-M-D，与通知刷新判断保持一致 */
  static todayKey(): string {
    const d = new Date();
    return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
  }
}
