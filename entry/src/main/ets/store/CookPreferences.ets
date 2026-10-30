import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { SearchMode } from '../model/recipe';
import type { MealPlan, MeatRatio } from '../model/mealPlan';
import { DEFAULT_DIET_PROFILE } from '../model/dietProfile';
import type { ActivityLevel, DietProfile, Gender, GoalType } from '../model/dietProfile';

const PREF_STORE_NAME = 'cook_storage';

/** 与 Web `useAppStore` / `defaultSettings` 一致 */
export interface UserSettings {
  keepLocalData: boolean
}

/** 用户个人信息 */
export interface UserProfile {
  nickname: string
  avatar: string // 头像emoji或图片URL
}

/** 主题设置 */
export interface ThemeSettings {
  themeMode: string // '系统默认' | '浅色模式' | '深色模式'
}

/** 收藏夹 */
export interface FolderItem {
  id: string
  name: string
  recipeIds: number[]
  createdAt: number
}

/** 下厨记录汇总（供「餐桌」页下厨记录区块与菜谱详情展示） */
export interface CookedSummary {
  /** 有下厨记录的天数 */
  totalTimes: number
  /** 近 7 天内下厨的天数 */
  weekTimes: number
  /** 最近做过的菜谱 id（按日期倒序，已去重） */
  recentRecipeIds: number[]
  /** recipeId → 最近一次下厨日期（YYYY-MM-DD） */
  lastDates: Record<string, string>
  /** recipeId → 累计下厨天数 */
  counts: Record<string, number>
}

const DEFAULT_SETTINGS: UserSettings = { keepLocalData: true };
const DEFAULT_PROFILE: UserProfile = { nickname: '美食家', avatar: '👨' };
const DEFAULT_THEME: ThemeSettings = { themeMode: '系统默认' };

export function sliceRecipeIds(ids: number[], offset: number, limit: number): number[] {
  if (limit <= 0 || offset < 0 || offset >= ids.length) {
    return [];
  }
  const out: number[] = [];
  const end = Math.min(ids.length, offset + limit);
  for (let i = offset; i < end; i++) {
    out.push(ids[i]);
  }
  return out;
}

/**
 * Preferences 内的字段名（单文件多 key）。
 * Web 端 localStorage 为 `cook:settings` 等；此处用短 key，语义对齐即可。
 */
export class CookPreferenceKeys {
  static readonly SETTINGS: string = 'settings'
  static readonly PROFILE: string = 'profile'
  static readonly THEME: string = 'theme'
  /** 后续：食材多选，建议存 JSON 字符串 string[] */
  static readonly STUFF: string = 'stuff'
  static readonly TOOL: string = 'tool'
  static readonly MODE: string = 'mode'
  static readonly FAVORITES: string = 'favorites'
  static readonly HISTORY: string = 'history'
  static readonly PRIVACY_ACCEPTED: string = 'privacy_accepted'
  /** 是否已看过新手引导（首次启动展示一次） */
  static readonly ONBOARDING_DONE: string = 'onboarding_done'
  static readonly THEME_CHANGE_TIMESTAMP: string = 'theme_change_timestamp'
  static readonly FOLDERS: string = 'folders'
  /** 搜索关键词历史（string[]，最新在前，最多 20 条） */
  static readonly SEARCH_HISTORY: string = 'search_history'
  /** 带日期的浏览历史（Record<YYYY-MM-DD, number[]>） */
  static readonly HISTORY_DATED: string = 'history_dated'
  /** 下厨记录（Record<YYYY-MM-DD, number[]>，加入今日餐桌时自动写入） */
  static readonly COOKED_LOG: string = 'cooked_log'
  /** 今日餐桌菜谱 ID 列表（number[]） */
  static readonly TODAY_MENU: string = 'today_menu'
  /** 一餐套餐（MealPlan JSON） */
  static readonly MEAL_PLAN: string = 'meal_plan'
  /** 个人健康目标档案（DietProfile JSON） */
  static readonly DIET_PROFILE: string = 'diet_profile'
  /** 每日推荐通知开关 */
  static readonly DAILY_RECOMMEND_SWITCH: string = 'daily_recommend_switch'
  /** 每日推荐通知时间 - 小时（0-23） */
  static readonly DAILY_RECOMMEND_HOUR: string = 'daily_recommend_hour'
  /** 每日推荐通知时间 - 分钟（0-59） */
  static readonly DAILY_RECOMMEND_MINUTE: string = 'daily_recommend_minute'
  /** 每日推荐偏好（'fridge_first' | 'random_quality'） */
  static readonly DAILY_RECOMMEND_PREFERENCE: string = 'daily_recommend_preference'
  /** 最近推荐过的菜谱 ID 列表（number[]，最多 7 条） */
  static readonly RECOMMEND_HISTORY: string = 'recommend_history'
  /** reminderAgentManager 保存的提醒 ID（用于取消旧提醒） */
  static readonly DAILY_REMINDER_AGENT_ID: string = 'daily_reminder_agent_id'
  /** 通知里点名推荐的菜谱 ID（点击通知时直接打开这道菜） */
  static readonly DAILY_REMINDER_RECIPE_ID: string = 'daily_reminder_recipe_id'
  /** 最近一次刷新通知内容日期（YYYY-M-D，用于每天只刷新一次） */
  static readonly DAILY_REMINDER_DATE: string = 'daily_reminder_date'
}

/**
 * 应用偏好设置（Preferences），在首次调用任意读写方法时用 context 懒加载。
 * getPreferences 与 warmUp / 首页并发时合并为单次打开，避免竞态。
 */
export class CookPreferences {
  private static store: preferences.Preferences | null = null;
  private static opening: Promise<preferences.Preferences> | null = null;
  private static readonly HISTORY_MAX: number = 50;
  private static readonly FAVORITE_MAX: number = 500;
  private static readonly SEARCH_HISTORY_MAX: number = 20;

  private static async getStore(context: common.Context): Promise<preferences.Preferences> {
    if (CookPreferences.store !== null) {
      return CookPreferences.store;
    }
    if (CookPreferences.opening !== null) {
      return await CookPreferences.opening;
    }
    CookPreferences.opening = preferences.getPreferences(context, PREF_STORE_NAME)
      .then((p: preferences.Preferences) => {
        CookPreferences.store = p;
        CookPreferences.opening = null;
        return p;
      })
      .catch(() => {
        CookPreferences.opening = null;
        throw new Error('getPreferences failed');
      });
    return await CookPreferences.opening;
  }

  /** 可选：在 Ability.onCreate 中调用以提前打开 Preferences，减少首页首帧等待 */
  static async warmUp(context: common.Context): Promise<void> {
    await CookPreferences.getStore(context);
  }

  private static getSettingsString(raw: preferences.ValueType): string {
    if (typeof raw === 'string') {
      return raw;
    }
    return '';
  }

  static async getSettings(context: common.Context): Promise<UserSettings> {
    const p = await CookPreferences.getStore(context);
    const rawVal = await p.get(CookPreferenceKeys.SETTINGS, '');
    const raw = CookPreferences.getSettingsString(rawVal);
    if (raw.length === 0) {
      return { keepLocalData: DEFAULT_SETTINGS.keepLocalData };
    }
    try {
      const parsed: UserSettings = JSON.parse(raw) as UserSettings;
      if (typeof parsed.keepLocalData === 'boolean') {
        return { keepLocalData: parsed.keepLocalData };
      }
      return { keepLocalData: DEFAULT_SETTINGS.keepLocalData };
    } catch {
      return { keepLocalData: DEFAULT_SETTINGS.keepLocalData };
    }
  }

  static async setSettings(context: common.Context, value: UserSettings): Promise<void> {
    const p = await CookPreferences.getStore(context);
    const toSave: UserSettings = { keepLocalData: value.keepLocalData };
    await p.put(CookPreferenceKeys.SETTINGS, JSON.stringify(toSave));
    await p.flush();
  }

  static async setKeepLocalData(context: common.Context, keep: boolean): Promise<void> {
    await CookPreferences.setSettings(context, { keepLocalData: keep });
  }

  /** 获取用户个人信息 */
  static async getUserProfile(context: common.Context): Promise<UserProfile> {
    const p = await CookPreferences.getStore(context);
    const rawVal = await p.get(CookPreferenceKeys.PROFILE, '');
    const raw = CookPreferences.getSettingsString(rawVal);
    if (raw.length === 0) {
      return { nickname: DEFAULT_PROFILE.nickname, avatar: DEFAULT_PROFILE.avatar };
    }
    try {
      const parsed: UserProfile = JSON.parse(raw) as UserProfile;
      return {
        nickname: parsed.nickname || DEFAULT_PROFILE.nickname,
        avatar: parsed.avatar || DEFAULT_PROFILE.avatar
      };
    } catch {
      return { nickname: DEFAULT_PROFILE.nickname, avatar: DEFAULT_PROFILE.avatar };
    }
  }

  /** 设置用户个人信息 */
  static async setUserProfile(context: common.Context, profile: UserProfile): Promise<void> {
    const p = await CookPreferences.getStore(context);
    const toSave: UserProfile = {
      nickname: profile.nickname || DEFAULT_PROFILE.nickname,
      avatar: profile.avatar || DEFAULT_PROFILE.avatar
    };
    await p.put(CookPreferenceKeys.PROFILE, JSON.stringify(toSave));
    await p.flush();
  }

  /** 获取主题设置 */
  static async getThemeSettings(context: common.Context): Promise<ThemeSettings> {
    const p = await CookPreferences.getStore(context);
    const rawVal = await p.get(CookPreferenceKeys.THEME, '');
    const raw = CookPreferences.getSettingsString(rawVal);
    if (raw.length === 0) {
      return { themeMode: DEFAULT_THEME.themeMode };
    }
    try {
      const parsed: ThemeSettings = JSON.parse(raw) as ThemeSettings;
      if (parsed.themeMode && ['系统默认', '浅色模式', '深色模式'].includes(parsed.themeMode)) {
        return { themeMode: parsed.themeMode };
      }
      return { themeMode: DEFAULT_THEME.themeMode };
    } catch {
      return { themeMode: DEFAULT_THEME.themeMode };
    }
  }

  /** 设置主题设置 */
  static async setThemeSettings(context: common.Context, theme: ThemeSettings): Promise<void> {
    const p = await CookPreferences.getStore(context);
    const toSave: ThemeSettings = {
      themeMode: theme.themeMode || DEFAULT_THEME.themeMode
    };
    await p.put(CookPreferenceKeys.THEME, JSON.stringify(toSave));
    await p.flush();
  }

  /** 设置主题模式 */
  static async setThemeMode(context: common.Context, themeMode: string): Promise<void> {
    await CookPreferences.setThemeSettings(context, { themeMode });
  }

  /** 关闭「保留本地数据」时可清空已持久化的选料（与 Web 行伪接近） */
  static async clearCookPersisted(context: common.Context): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.STUFF, '[]');
    await p.put(CookPreferenceKeys.TOOL, '');
    await p.put(CookPreferenceKeys.MODE, 'loose');
    await p.put(CookPreferenceKeys.HISTORY, '[]');
    await p.put(CookPreferenceKeys.FAVORITES, '[]');
    await p.put(CookPreferenceKeys.COOKED_LOG, '{}');
    await p.flush();
  }

  /** 历史 / 收藏：JSON number[]，非负整数 id */
  private static parseRecipeIdArray(raw: string): number[] {
    if (raw.length === 0) {
      return [];
    }
    try {
      const v = JSON.parse(raw) as number[];
      if (!Array.isArray(v)) {
        return [];
      }
      const out: number[] = [];
      for (let i = 0; i < v.length; i++) {
        const n: number = v[i];
        if (typeof n === 'number' && n >= 0 && Math.floor(n) === n) {
          out.push(n);
        }
      }
      return out;
    } catch {
      return [];
    }
  }

  static async getHistoryIds(context: common.Context): Promise<number[]> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.HISTORY, ''));
    return CookPreferences.parseRecipeIdArray(raw);
  }

  static async getFavoriteIds(context: common.Context): Promise<number[]> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.FAVORITES, ''));
    return CookPreferences.parseRecipeIdArray(raw);
  }

  static async getFavoriteIdsPage(context: common.Context, offset: number, limit: number): Promise<number[]> {
    const ids = await CookPreferences.getFavoriteIds(context);
    return sliceRecipeIds(ids, offset, limit);
  }

  static async setFavoriteIds(context: common.Context, ids: number[]): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.FAVORITES, JSON.stringify(ids));
    await p.flush();
  }

  /** 已收藏则取消，否则插到队首；最多 FAVORITE_MAX 条 */
  static async toggleFavoriteId(context: common.Context, recipeId: number): Promise<void> {
    if (recipeId < 0 || Math.floor(recipeId) !== recipeId) {
      return;
    }
    const prev = await CookPreferences.getFavoriteIds(context);
    const rest: number[] = [];
    let had = false;
    for (let i = 0; i < prev.length; i++) {
      if (prev[i] === recipeId) {
        had = true;
      } else {
        rest.push(prev[i]);
      }
    }
    let next: number[];
    if (had) {
      next = rest;
      // 取消收藏时，同步从所有收藏夹移除
      const folders = await CookPreferences.getFolders(context);
      let changed = false;
      for (let i = 0; i < folders.length; i++) {
        const kept: number[] = [];
        for (let j = 0; j < folders[i].recipeIds.length; j++) {
          if (folders[i].recipeIds[j] !== recipeId) {
            kept.push(folders[i].recipeIds[j]);
          } else {
            changed = true;
          }
        }
        folders[i].recipeIds = kept;
      }
      if (changed) {
        await CookPreferences.setFolders(context, folders);
      }
    } else {
      const withNew: number[] = [recipeId];
      for (let j = 0; j < rest.length; j++) {
        withNew.push(rest[j]);
      }
      next = withNew;
    }
    const capped: number[] = [];
    const max = CookPreferences.FAVORITE_MAX;
    for (let k = 0; k < next.length && k < max; k++) {
      capped.push(next[k]);
    }
    await CookPreferences.setFavoriteIds(context, capped);
  }

  static async clearFavorites(context: common.Context): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.FAVORITES, '[]');
    // 同步清空所有收藏夹内的菜谱
    const folders = await CookPreferences.getFolders(context);
    let changed = false;
    for (let i = 0; i < folders.length; i++) {
      if (folders[i].recipeIds.length > 0) {
        folders[i].recipeIds = [];
        changed = true;
      }
    }
    if (changed) {
      await p.put(CookPreferenceKeys.FOLDERS, JSON.stringify(folders));
    }
    await p.flush();
  }

  static async clearHistory(context: common.Context): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.HISTORY, '[]');
    await p.flush();
  }

  static async hasAcceptedPrivacy(context: common.Context): Promise<boolean> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.PRIVACY_ACCEPTED, false);
    return raw === true;
  }

  static async setPrivacyAccepted(context: common.Context, accepted: boolean): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.PRIVACY_ACCEPTED, accepted);
    await p.flush();
  }

  static async hasSeenOnboarding(context: common.Context): Promise<boolean> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.ONBOARDING_DONE, false);
    return raw === true;
  }

  /** 新手引导属于 UI 状态而非用户数据，不受「保留本地数据」开关影响 */
  static async setOnboardingSeen(context: common.Context, seen: boolean): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.ONBOARDING_DONE, seen);
    await p.flush();
  }

  /** 记录一次浏览菜谱：去重后插到队首，最多保留 HISTORY_MAX 条；同时写入带日期的历史 */
  static async recordHistoryVisit(context: common.Context, recipeId: number): Promise<void> {
    if (recipeId < 0 || Math.floor(recipeId) !== recipeId) {
      return;
    }
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.HISTORY, ''));
    const prev = CookPreferences.parseRecipeIdArray(raw);
    const next: number[] = [];
    next.push(recipeId);
    for (let i = 0; i < prev.length; i++) {
      if (prev[i] !== recipeId) {
        next.push(prev[i]);
      }
    }
    const capped: number[] = [];
    const max = CookPreferences.HISTORY_MAX;
    for (let i = 0; i < next.length && i < max; i++) {
      capped.push(next[i]);
    }
    await p.put(CookPreferenceKeys.HISTORY, JSON.stringify(capped));
    await p.flush();
    // 同时写入带日期的历史（用于热力图，不阻塞主流程）
    void CookPreferences.recordDatedHistoryVisit(context, recipeId);
  }

  private static parseStringArray(raw: string): string[] {
    if (raw.length === 0) {
      return [];
    }
    try {
      const v = JSON.parse(raw) as string[];
      if (!Array.isArray(v)) {
        return [];
      }
      const out: string[] = [];
      for (let i = 0; i < v.length; i++) {
        const s = v[i];
        if (typeof s === 'string') {
          out.push(s);
        }
      }
      return out;
    } catch {
      return [];
    }
  }

  static async getSelectedStuff(context: common.Context): Promise<string[]> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.STUFF, ''));
    return CookPreferences.parseStringArray(raw);
  }

  static async setSelectedStuff(context: common.Context, stuff: string[]): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.STUFF, JSON.stringify(stuff));
    await p.flush();
  }

  static async getCurTool(context: common.Context): Promise<string> {
    const p = await CookPreferences.getStore(context);
    return CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.TOOL, ''));
  }

  static async setCurTool(context: common.Context, tool: string): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.TOOL, tool);
    await p.flush();
  }

  static async getSearchMode(context: common.Context): Promise<SearchMode> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.MODE, 'loose'));
    if (raw === 'survival' || raw === 'strict') {
      return raw;
    }
    return 'loose';
  }

  static async setSearchMode(context: common.Context, mode: SearchMode): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.MODE, mode);
    await p.flush();
  }

  /** 获取主题变更时间戳 */
  static async getThemeChangeTimestamp(context: common.Context): Promise<number> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.THEME_CHANGE_TIMESTAMP, 0);
    if (typeof raw === 'number') {
      return raw;
    }
    return 0;
  }

  /** 设置主题变更时间戳 */
  static async setThemeChangeTimestamp(context: common.Context, timestamp: number): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.THEME_CHANGE_TIMESTAMP, timestamp);
    await p.flush();
  }

  // ─── 收藏夹 ───────────────────────────────────────────────

  static async getFolders(context: common.Context): Promise<FolderItem[]> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.FOLDERS, ''));
    if (raw.length === 0) return [];
    try {
      const v = JSON.parse(raw) as FolderItem[];
      return Array.isArray(v) ? v : [];
    } catch {
      return [];
    }
  }

  static async setFolders(context: common.Context, folders: FolderItem[]): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.FOLDERS, JSON.stringify(folders));
    await p.flush();
  }

  static async createFolder(context: common.Context, name: string): Promise<FolderItem> {
    const folders = await CookPreferences.getFolders(context);
    const folder: FolderItem = {
      id: Date.now().toString(),
      name: name.trim() || '新收藏夹',
      recipeIds: [],
      createdAt: Date.now()
    };
    folders.push(folder);
    await CookPreferences.setFolders(context, folders);
    return folder;
  }

  /**
   * 用户还没有任何收藏夹时，收藏自动归入的默认文件夹名称。
   * 与手动创建的文件夹一致持久化，之后可改名或删除。
   */
  static readonly DEFAULT_FOLDER_NAME: string = '默认收藏夹'

  /** 取默认收藏夹；不存在则创建。避免收藏时被空文件夹面板打断。 */
  static async ensureDefaultFolder(context: common.Context): Promise<FolderItem> {
    const folders = await CookPreferences.getFolders(context);
    for (let i = 0; i < folders.length; i++) {
      if (folders[i].name === CookPreferences.DEFAULT_FOLDER_NAME) {
        return folders[i];
      }
    }
    return await CookPreferences.createFolder(context, CookPreferences.DEFAULT_FOLDER_NAME);
  }

  static async addRecipeToFolder(context: common.Context, folderId: string, recipeId: number): Promise<void> {
    const folders = await CookPreferences.getFolders(context);
    for (let i = 0; i < folders.length; i++) {
      if (folders[i].id === folderId) {
        if (!folders[i].recipeIds.includes(recipeId)) {
          const newIds: number[] = [recipeId];
          for (let j = 0; j < folders[i].recipeIds.length; j++) {
            newIds.push(folders[i].recipeIds[j]);
          }
          folders[i].recipeIds = newIds;
        }
        break;
      }
    }
    await CookPreferences.setFolders(context, folders);
  }

  static async removeRecipeFromFolder(context: common.Context, folderId: string, recipeId: number): Promise<void> {
    const folders = await CookPreferences.getFolders(context);
    for (let i = 0; i < folders.length; i++) {
      if (folders[i].id === folderId) {
        const kept: number[] = [];
        for (let j = 0; j < folders[i].recipeIds.length; j++) {
          if (folders[i].recipeIds[j] !== recipeId) {
            kept.push(folders[i].recipeIds[j]);
          }
        }
        folders[i].recipeIds = kept;
        break;
      }
    }
    await CookPreferences.setFolders(context, folders);
  }

  static async removeRecipeFromAllFolders(context: common.Context, recipeId: number): Promise<void> {
    const folders = await CookPreferences.getFolders(context);
    let changed = false;
    for (let i = 0; i < folders.length; i++) {
      const kept: number[] = [];
      for (let j = 0; j < folders[i].recipeIds.length; j++) {
        if (folders[i].recipeIds[j] !== recipeId) {
          kept.push(folders[i].recipeIds[j]);
        } else {
          changed = true;
        }
      }
      folders[i].recipeIds = kept;
    }
    if (changed) {
      await CookPreferences.setFolders(context, folders);
    }
  }

  // ─── 搜索历史 ─────────────────────────────────────────────

  static async getSearchHistory(context: common.Context): Promise<string[]> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.SEARCH_HISTORY, ''));
    return CookPreferences.parseStringArray(raw);
  }

  /**
   * 将关键词插到历史队首（去重），最多保留 SEARCH_HISTORY_MAX 条。
   * 空字符串不记录。
   */
  static async addSearchHistory(context: common.Context, keyword: string): Promise<void> {
    const trimmed = keyword.trim();
    if (trimmed.length === 0) return;
    const p = await CookPreferences.getStore(context);
    const prev = await CookPreferences.getSearchHistory(context);
    const next: string[] = [trimmed];
    for (let i = 0; i < prev.length; i++) {
      if (prev[i] !== trimmed) {
        next.push(prev[i]);
      }
    }
    const capped: string[] = next.slice(0, CookPreferences.SEARCH_HISTORY_MAX);
    await p.put(CookPreferenceKeys.SEARCH_HISTORY, JSON.stringify(capped));
    await p.flush();
  }

  static async clearSearchHistory(context: common.Context): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.SEARCH_HISTORY, '[]');
    await p.flush();
  }

  // ─── 带日期的浏览历史 ─────────────────────────────────────

  /** 今天的日期键（YYYY-MM-DD），同时用于浏览历史与下厨记录 */
  static todayDateString(): string {
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  static async getDatedHistory(context: common.Context): Promise<Record<string, number[]>> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.HISTORY_DATED, ''));
    if (raw.length === 0) {
      return {};
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, number[]>;
      if (typeof parsed !== 'object' || Array.isArray(parsed)) {
        return {};
      }
      return parsed;
    } catch {
      return {};
    }
  }

  /**
   * 向带日期的历史中追加一次记录（同一天同一菜谱只记一次）。
   * 同时兼容保存到旧格式 HISTORY key。
   */
  static async recordDatedHistoryVisit(context: common.Context, recipeId: number): Promise<void> {
    if (recipeId < 0 || Math.floor(recipeId) !== recipeId) return;
    const p = await CookPreferences.getStore(context);
    const dated = await CookPreferences.getDatedHistory(context);
    const today = CookPreferences.todayDateString();
    const todayList: number[] = dated[today] ?? [];
    let alreadyIn = false;
    for (let i = 0; i < todayList.length; i++) {
      if (todayList[i] === recipeId) { alreadyIn = true; break; }
    }
    if (!alreadyIn) {
      const newList: number[] = [recipeId];
      for (let i = 0; i < todayList.length; i++) { newList.push(todayList[i]); }
      dated[today] = newList;
      await p.put(CookPreferenceKeys.HISTORY_DATED, JSON.stringify(dated));
      await p.flush();
    }
  }

  // ─── 下厨记录 ─────────────────────────────────────────────

  static async getCookedLog(context: common.Context): Promise<Record<string, number[]>> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.COOKED_LOG, ''));
    if (raw.length === 0) {
      return {};
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, number[]>;
      if (typeof parsed !== 'object' || Array.isArray(parsed)) {
        return {};
      }
      return parsed;
    } catch {
      return {};
    }
  }

  /**
   * 切换「今天做过这道菜」：未记录则写入，已记录则撤销。
   * 同一天同一道菜只记一次，返回 true 表示当前为已记录状态。
   */
  static async toggleCookedToday(context: common.Context, recipeId: number): Promise<boolean> {
    if (recipeId < 0 || Math.floor(recipeId) !== recipeId) {
      return false;
    }
    const p = await CookPreferences.getStore(context);
    const log = await CookPreferences.getCookedLog(context);
    const today = CookPreferences.todayDateString();
    const todayList: number[] = log[today] ?? [];
    const kept: number[] = [];
    let wasCooked = false;
    for (let i = 0; i < todayList.length; i++) {
      if (todayList[i] === recipeId) {
        wasCooked = true;
      } else {
        kept.push(todayList[i]);
      }
    }
    if (!wasCooked) {
      const next: number[] = [recipeId];
      for (let i = 0; i < kept.length; i++) {
        next.push(kept[i]);
      }
      log[today] = next;
    } else {
      // 保留空数组而非 delete，便于后续日期键持续存在（汇总时跳过空列表即可）
      log[today] = kept;
    }
    await p.put(CookPreferenceKeys.COOKED_LOG, JSON.stringify(log));
    await p.flush();
    return !wasCooked;
  }

  /**
   * 幂等记入「今天做过这道菜」：已记录则不动（不撤销）。
   * 供「加入今日餐桌」合并动作使用——加入餐桌即视为今天做过，累计下厨次数。
   */
  static async recordCookedToday(context: common.Context, recipeId: number): Promise<boolean> {
    if (recipeId < 0 || Math.floor(recipeId) !== recipeId) {
      return false;
    }
    const p = await CookPreferences.getStore(context);
    const log = await CookPreferences.getCookedLog(context);
    const today = CookPreferences.todayDateString();
    const todayList: number[] = log[today] ?? [];
    for (let i = 0; i < todayList.length; i++) {
      if (todayList[i] === recipeId) {
        return true;
      }
    }
    const next: number[] = [recipeId];
    for (let i = 0; i < todayList.length; i++) {
      next.push(todayList[i]);
    }
    log[today] = next;
    await p.put(CookPreferenceKeys.COOKED_LOG, JSON.stringify(log));
    await p.flush();
    return true;
  }

  private static dateKeyToDayIndex(dateStr: string): number {
    const parts = dateStr.split('-');
    if (parts.length !== 3) {
      return -1;
    }
    const y = Number(parts[0]);
    const m = Number(parts[1]);
    const d = Number(parts[2]);
    if (!(y > 0 && m > 0 && d > 0)) {
      return -1;
    }
    return Math.floor(new Date(y, m - 1, d).getTime() / 86400000);
  }

  /** 汇总下厨记录：总天数、近 7 天次数、最近做过的菜与每道菜的累计/上次日期 */
  static async getCookedSummary(context: common.Context): Promise<CookedSummary> {
    const log = await CookPreferences.getCookedLog(context);
    const keys = Object.keys(log);
    let totalTimes = 0;
    let weekTimes = 0;
    const counts: Record<string, number> = {};
    const lastDates: Record<string, string> = {};
    const todayIdx = CookPreferences.dateKeyToDayIndex(CookPreferences.todayDateString());
    for (let i = 0; i < keys.length; i++) {
      const dateKey = keys[i];
      const ids = log[dateKey];
      if (ids === undefined || ids.length === 0) {
        continue;
      }
      totalTimes++;
      const dayIdx = CookPreferences.dateKeyToDayIndex(dateKey);
      const ago = todayIdx - dayIdx;
      if (dayIdx >= 0 && ago >= 0 && ago < 7) {
        weekTimes++;
      }
      for (let j = 0; j < ids.length; j++) {
        const recipeKey = String(ids[j]);
        counts[recipeKey] = (counts[recipeKey] ?? 0) + 1;
        const prev = lastDates[recipeKey] ?? '';
        if (dateKey > prev) {
          lastDates[recipeKey] = dateKey;
        }
      }
    }
    // 按日期倒序取最近做过的菜（去重，最多 8 道）
    keys.sort((a: string, b: string): number => a < b ? 1 : (a > b ? -1 : 0));
    const recentRecipeIds: number[] = [];
    for (let i = 0; i < keys.length && recentRecipeIds.length < 8; i++) {
      const ids = log[keys[i]];
      if (ids === undefined) {
        continue;
      }
      for (let j = 0; j < ids.length && recentRecipeIds.length < 8; j++) {
        if (!recentRecipeIds.includes(ids[j])) {
          recentRecipeIds.push(ids[j]);
        }
      }
    }
    return { totalTimes, weekTimes, recentRecipeIds, lastDates, counts };
  }

  // ─── 今日餐桌 ─────────────────────────────────────────────

  static async getTodayMenuIds(context: common.Context): Promise<number[]> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.TODAY_MENU, ''));
    return CookPreferences.parseRecipeIdArray(raw);
  }

  static async setTodayMenuIds(context: common.Context, ids: number[]): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.TODAY_MENU, JSON.stringify(ids));
    await p.flush();
  }

  static async toggleTodayMenuItem(context: common.Context, recipeId: number): Promise<boolean> {
    const prev = await CookPreferences.getTodayMenuIds(context);
    let found = false;
    const next: number[] = [];
    for (let i = 0; i < prev.length; i++) {
      if (prev[i] === recipeId) { found = true; } else { next.push(prev[i]); }
    }
    if (!found) { next.unshift(recipeId); }
    await CookPreferences.setTodayMenuIds(context, next);
    return !found; // true = 已加入，false = 已移除
  }

  static async clearTodayMenu(context: common.Context): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.TODAY_MENU, '[]');
    await p.flush();
  }

  // ─── 一餐套餐 ─────────────────────────────────────────────

  static async getMealPlan(context: common.Context): Promise<MealPlan | null> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.MEAL_PLAN, ''));
    if (raw.length === 0) {
      return null;
    }
    try {
      const v = JSON.parse(raw) as MealPlan;
      if (v === null || v === undefined || !Array.isArray(v.dishIds)) {
        return null;
      }
      const ids = CookPreferences.parseRecipeIdArray(JSON.stringify(v.dishIds));
      const locked: boolean[] = Array.isArray(v.locked)
        ? v.locked.map((b: boolean) => b === true)
        : ids.map(() => false);
      const people = typeof v.people === 'number' ? Math.max(1, Math.min(6, Math.floor(v.people))) : 2;
      const meatRatio: MeatRatio = (v.meatRatio === '偏素' || v.meatRatio === '偏荤' || v.meatRatio === '均衡')
        ? v.meatRatio : '均衡';
      const tools: string[] = Array.isArray(v.tools) ? v.tools : [];
      const updatedAt = typeof v.updatedAt === 'number' ? v.updatedAt : Date.now();
      return { people, meatRatio, tools, dishIds: ids, locked, updatedAt };
    } catch {
      return null;
    }
  }

  static async setMealPlan(context: common.Context, plan: MealPlan): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.MEAL_PLAN, JSON.stringify(plan));
    await p.flush();
  }

  static async clearMealPlan(context: common.Context): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.MEAL_PLAN, '');
    await p.flush();
  }

  // ─── 个人健康目标 ─────────────────────────────────────────

  static async getDietProfile(context: common.Context): Promise<DietProfile> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.DIET_PROFILE, ''));
    if (raw.length === 0) {
      return DEFAULT_DIET_PROFILE;
    }
    try {
      const v = JSON.parse(raw) as DietProfile;
      if (v === null || v === undefined) {
        return DEFAULT_DIET_PROFILE;
      }
      const gender: Gender = v.gender === 'male' ? 'male' : 'female';
      const activity: ActivityLevel = (v.activity === 'sedentary' || v.activity === 'light' ||
        v.activity === 'moderate' || v.activity === 'active' || v.activity === 'veryActive')
        ? v.activity : 'light';
      const goal: GoalType = (v.goal === 'lose' || v.goal === 'maintain' || v.goal === 'gain')
        ? v.goal : 'maintain';
      const age: number = (typeof v.age === 'number' && v.age >= 14 && v.age <= 90)
        ? Math.round(v.age) : DEFAULT_DIET_PROFILE.age;
      const heightCm: number = (typeof v.heightCm === 'number' && v.heightCm >= 120 && v.heightCm <= 220)
        ? Math.round(v.heightCm) : DEFAULT_DIET_PROFILE.heightCm;
      const weightKg: number = (typeof v.weightKg === 'number' && v.weightKg >= 30 && v.weightKg <= 200)
        ? Math.round(v.weightKg * 10) / 10 : DEFAULT_DIET_PROFILE.weightKg;
      const weeklyRateKg: number = (typeof v.weeklyRateKg === 'number' && v.weeklyRateKg > 0 && v.weeklyRateKg <= 1)
        ? v.weeklyRateKg : DEFAULT_DIET_PROFILE.weeklyRateKg;
      return { gender, age, heightCm, weightKg, activity, goal, weeklyRateKg };
    } catch {
      return DEFAULT_DIET_PROFILE;
    }
  }

  static async setDietProfile(context: common.Context, profile: DietProfile): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.DIET_PROFILE, JSON.stringify(profile));
    await p.flush();
  }

  // ─── 每日推荐通知设置 ──────────────────────────────────────

  static async getDailyRecommendSwitch(context: common.Context): Promise<boolean> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.DAILY_RECOMMEND_SWITCH, false);
    return raw === true;
  }

  static async setDailyRecommendSwitch(context: common.Context, enabled: boolean): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.DAILY_RECOMMEND_SWITCH, enabled);
    await p.flush();
  }

  static async getDailyRecommendHour(context: common.Context): Promise<number> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.DAILY_RECOMMEND_HOUR, 8);
    return typeof raw === 'number' ? Math.max(0, Math.min(23, Math.floor(raw))) : 8;
  }

  static async setDailyRecommendHour(context: common.Context, hour: number): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.DAILY_RECOMMEND_HOUR, Math.max(0, Math.min(23, Math.floor(hour))));
    await p.flush();
  }

  static async getDailyRecommendMinute(context: common.Context): Promise<number> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.DAILY_RECOMMEND_MINUTE, 0);
    return typeof raw === 'number' ? Math.max(0, Math.min(59, Math.floor(raw))) : 0;
  }

  static async setDailyRecommendMinute(context: common.Context, minute: number): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.DAILY_RECOMMEND_MINUTE, Math.max(0, Math.min(59, Math.floor(minute))));
    await p.flush();
  }

  static async getDailyRecommendPreference(context: common.Context): Promise<string> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.DAILY_RECOMMEND_PREFERENCE, ''));
    return raw === 'random_quality' ? 'random_quality' : 'fridge_first';
  }

  static async setDailyRecommendPreference(context: common.Context, preference: string): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.DAILY_RECOMMEND_PREFERENCE, preference);
    await p.flush();
  }

  static async getRecommendHistory(context: common.Context): Promise<number[]> {
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.RECOMMEND_HISTORY, ''));
    return CookPreferences.parseRecipeIdArray(raw);
  }

  /** 将 recipeId 插到推荐历史队首，最多保留 7 条 */
  static async addToRecommendHistory(context: common.Context, recipeId: number): Promise<void> {
    if (recipeId < 0 || Math.floor(recipeId) !== recipeId) return;
    const p = await CookPreferences.getStore(context);
    const prev = await CookPreferences.getRecommendHistory(context);
    const next: number[] = [recipeId];
    for (let i = 0; i < prev.length; i++) {
      if (prev[i] !== recipeId) {
        next.push(prev[i]);
      }
    }
    const capped: number[] = next.slice(0, 7);
    await p.put(CookPreferenceKeys.RECOMMEND_HISTORY, JSON.stringify(capped));
    await p.flush();
  }

  static async getDailyReminderAgentId(context: common.Context): Promise<number> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.DAILY_REMINDER_AGENT_ID, 0);
    return typeof raw === 'number' ? raw : 0;
  }

  static async setDailyReminderAgentId(context: common.Context, reminderId: number): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.DAILY_REMINDER_AGENT_ID, reminderId);
    await p.flush();
  }

  /** 通知中点名的菜谱 ID，0 表示未指定 */
  static async getDailyReminderRecipeId(context: common.Context): Promise<number> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.DAILY_REMINDER_RECIPE_ID, 0);
    return typeof raw === 'number' ? raw : 0;
  }

  static async setDailyReminderRecipeId(context: common.Context, recipeId: number): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.DAILY_REMINDER_RECIPE_ID, recipeId);
    await p.flush();
  }

  /** 通知内容最近一次刷新日期（YYYY-M-D），'' 表示从未刷新 */
  static async getDailyReminderDate(context: common.Context): Promise<string> {
    const p = await CookPreferences.getStore(context);
    const raw = await p.get(CookPreferenceKeys.DAILY_REMINDER_DATE, '');
    return typeof raw === 'string' ? raw : '';
  }

  static async setDailyReminderDate(context: common.Context, date: string): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.DAILY_REMINDER_DATE, date);
    await p.flush();
  }

  static async deleteFolder(context: common.Context, folderId: string): Promise<void> {
    const folders = await CookPreferences.getFolders(context);
    // 找到要删除的收藏夹，取消其中所有菜的收藏
    let recipeIdsToUnfavorite: number[] = [];
    const remaining: FolderItem[] = [];
    for (let i = 0; i < folders.length; i++) {
      if (folders[i].id === folderId) {
        recipeIdsToUnfavorite = folders[i].recipeIds;
      } else {
        remaining.push(folders[i]);
      }
    }
    await CookPreferences.setFolders(context, remaining);
    if (recipeIdsToUnfavorite.length > 0) {
      const prev = await CookPreferences.getFavoriteIds(context);
      const next: number[] = [];
      for (let i = 0; i < prev.length; i++) {
        let inFolder = false;
        for (let j = 0; j < recipeIdsToUnfavorite.length; j++) {
          if (prev[i] === recipeIdsToUnfavorite[j]) {
            inFolder = true;
            break;
          }
        }
        if (!inFolder) {
          next.push(prev[i]);
        }
      }
      await CookPreferences.setFavoriteIds(context, next);
    }
  }
}