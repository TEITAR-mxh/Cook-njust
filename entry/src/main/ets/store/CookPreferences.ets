import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { SearchMode } from '../model/recipe';

const PREF_STORE_NAME = 'cook_storage';

/** 与 Web `useAppStore` / `defaultSettings` 一致 */
export interface UserSettings {
  keepLocalData: boolean
}

const DEFAULT_SETTINGS: UserSettings = { keepLocalData: true };

/**
 * Preferences 内的字段名（单文件多 key）。
 * Web 端 localStorage 为 `cook:settings` 等；此处用短 key，语义对齐即可。
 */
export class CookPreferenceKeys {
  static readonly SETTINGS: string = 'settings'
  /** 后续：食材多选，建议存 JSON 字符串 string[] */
  static readonly STUFF: string = 'stuff'
  static readonly TOOL: string = 'tool'
  static readonly MODE: string = 'mode'
  static readonly FAVORITES: string = 'favorites'
  static readonly HISTORY: string = 'history'
}

/**
 * 应用偏好设置（Preferences），在首次调用任意读写方法时用 context 懒加载。
 * getPreferences 与 warmUp / 首页并发时合并为单次打开，避免竞态。
 */
export class CookPreferences {
  private static store: preferences.Preferences | null = null;
  private static opening: Promise<preferences.Preferences> | null = null;
  private static readonly HISTORY_MAX: number = 50;

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

  /** 关闭「保留本地数据」时可清空已持久化的选料（与 Web 行为接近） */
  static async clearCookPersisted(context: common.Context): Promise<void> {
    const p = await CookPreferences.getStore(context);
    await p.put(CookPreferenceKeys.STUFF, '[]');
    await p.put(CookPreferenceKeys.TOOL, '');
    await p.put(CookPreferenceKeys.MODE, 'loose');
    await p.put(CookPreferenceKeys.HISTORY, '[]');
    await p.flush();
  }

  /** 浏览历史：菜谱 id 数组，下标 0 为最近访问（与 Web Dexie id 一致） */
  private static parseHistoryIds(raw: string): number[] {
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
    return CookPreferences.parseHistoryIds(raw);
  }

  /** 记录一次打开视频：去重后插到队首，最多保留 HISTORY_MAX 条 */
  static async recordHistoryVisit(context: common.Context, recipeId: number): Promise<void> {
    if (recipeId < 0 || Math.floor(recipeId) !== recipeId) {
      return;
    }
    const p = await CookPreferences.getStore(context);
    const raw = CookPreferences.getSettingsString(await p.get(CookPreferenceKeys.HISTORY, ''));
    const prev = CookPreferences.parseHistoryIds(raw);
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
}
