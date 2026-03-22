import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

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
}
