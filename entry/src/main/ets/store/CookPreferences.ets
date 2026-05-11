import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { SearchMode } from '../model/recipe';

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
  static readonly THEME_CHANGE_TIMESTAMP: string = 'theme_change_timestamp'
  static readonly FOLDERS: string = 'folders'
  /** 搜索关键词历史（string[]，最新在前，最多 20 条） */
  static readonly SEARCH_HISTORY: string = 'search_history'
  /** 带日期的浏览历史（Record<YYYY-MM-DD, number[]>） */
  static readonly HISTORY_DATED: string = 'history_dated'
  /** 今日餐桌菜谱 ID 列表（number[]） */
  static readonly TODAY_MENU: string = 'today_menu'
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
    if (raw === 'strict' || raw === 'survival' || raw === 'loose') {
      return raw as SearchMode;
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

  private static todayDateString(): string {
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