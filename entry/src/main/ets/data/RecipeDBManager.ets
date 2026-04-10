import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import type { Difficulty, RecipeItem, RecipeWithId } from '../model/recipe';

const DB_NAME = 'cook_recipes.db';
const RAW_NAME = 'recipe.json';
const CURRENT_SCHEMA_VERSION = '1';
const META_SCHEMA = 'schema_version';
const META_BUNDLE_HASH = 'recipe_bundle_hash';

const SQL_CREATE_META =
  'CREATE TABLE IF NOT EXISTS app_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)';
const SQL_CREATE_RECIPE =
  'CREATE TABLE IF NOT EXISTS recipe (' +
  'id INTEGER PRIMARY KEY NOT NULL, ' +
  'name TEXT NOT NULL, ' +
  'steps TEXT NOT NULL, ' +
  'stuff_json TEXT NOT NULL, ' +
  'tools_json TEXT NOT NULL, ' +
  'methods_json TEXT NOT NULL, ' +
  'tags_json TEXT NOT NULL, ' +
  'emojis_json TEXT NOT NULL, ' +
  'difficulty TEXT NOT NULL' +
  ')';

function toUint8Array(raw: Uint8Array | ArrayBuffer): Uint8Array {
  if (raw instanceof Uint8Array) {
    return raw;
  }
  return new Uint8Array(raw);
}

/**
 * UTF-8 字节转字符串（与 RecipeRepository 一致，不依赖 TextDecoder）
 */
function utf8BytesToString(bytes: Uint8Array): string {
  let i = 0;
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    i = 3;
  }
  const parts: string[] = [];
  const len = bytes.length;
  while (i < len) {
    const c = bytes[i++];
    if (c < 0x80) {
      parts.push(String.fromCharCode(c));
    } else if (c < 0xe0) {
      if (i >= len) {
        break;
      }
      parts.push(String.fromCharCode(((c & 0x1f) << 6) | (bytes[i++] & 0x3f)));
    } else if (c < 0xf0) {
      if (i + 1 >= len) {
        break;
      }
      const c2 = bytes[i++];
      parts.push(String.fromCharCode(((c & 0x0f) << 12) | ((c2 & 0x3f) << 6) | (bytes[i++] & 0x3f)));
    } else {
      if (i + 2 >= len) {
        break;
      }
      const cp = ((c & 0x07) << 18) | ((bytes[i++] & 0x3f) << 12) | ((bytes[i++] & 0x3f) << 6) | (bytes[i++] & 0x3f);
      if (cp > 0xffff) {
        const offset = cp - 0x10000;
        parts.push(String.fromCharCode(0xd800 + (offset >> 10)));
        parts.push(String.fromCharCode(0xdc00 + (offset & 0x3ff)));
      } else {
        parts.push(String.fromCharCode(cp));
      }
    }
  }
  return parts.join('');
}

/** rawfile 中的 JSON 行（忽略 bv / link 等废弃字段） */
interface RawRecipeRow {
  name: string
  stuff?: string[]
  tools?: string[]
  emojis?: string[]
  difficulty?: Difficulty | ''
  tags?: string[]
  methods?: string[]
  steps?: string[]
}

const HEX_DIGITS: string[] = [
  '0', '1', '2', '3', '4', '5', '6', '7',
  '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
];

function bytesToHex(data: Uint8Array): string {
  let s = '';
  for (let i = 0; i < data.length; i++) {
    const b = data[i];
    const hi = (b >> 4) & 15;
    const lo = b & 15;
    s += HEX_DIGITS[hi];
    s += HEX_DIGITS[lo];
  }
  return s;
}

function fallbackFingerprint(bytes: Uint8Array): string {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < bytes.length; i++) {
    h ^= bytes[i];
    h = Math.imul(h, 16777619) >>> 0;
  }
  return `fnv1a:${bytes.length}:${h.toString(16)}`;
}

async function sha256HexOfBytes(bytes: Uint8Array): Promise<string> {
  try {
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: bytes });
    const out = await md.digest();
    return bytesToHex(out.data);
  } catch {
    return fallbackFingerprint(bytes);
  }
}

function parseStringArrayJson(text: string): string[] {
  try {
    const v = JSON.parse(text) as string[];
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

function parseMethodsJson(text: string): ('炒' | '煎' | '烘' | '炸')[] {
  try {
    const arr = JSON.parse(text) as string[];
    if (!Array.isArray(arr)) {
      return [];
    }
    const out: ('炒' | '煎' | '烘' | '炸')[] = [];
    for (let i = 0; i < arr.length; i++) {
      const m = arr[i];
      if (m === '炒' || m === '煎' || m === '烘' || m === '炸') {
        out.push(m);
      }
    }
    return out;
  } catch {
    return [];
  }
}

function parseStepsJson(text: string): string[] {
  try {
    const v = JSON.parse(text) as string[];
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

export class RecipeDBManager {
  private static instance: RecipeDBManager | null = null;
  private store: relationalStore.RdbStore | null = null;
  private opening: Promise<relationalStore.RdbStore> | null = null;

  static getInstance(): RecipeDBManager {
    if (RecipeDBManager.instance === null) {
      RecipeDBManager.instance = new RecipeDBManager();
    }
    return RecipeDBManager.instance;
  }

  private async readRawRecipeBytes(context: common.Context): Promise<Uint8Array> {
    let raw: Uint8Array | ArrayBuffer;
    try {
      raw = await context.resourceManager.getRawFileContent(RAW_NAME);
    } catch (firstErr) {
      const ctx = context as common.UIAbilityContext;
      if (typeof ctx.createModuleContext === 'function') {
        const moduleCtx = ctx.createModuleContext('entry');
        raw = await moduleCtx.resourceManager.getRawFileContent(RAW_NAME);
      } else {
        throw new Error(String(firstErr));
      }
    }
    return toUint8Array(raw);
  }

  private async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    if (this.store !== null) {
      return this.store;
    }
    if (this.opening !== null) {
      return await this.opening;
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
    };
    this.opening = relationalStore.getRdbStore(context, config)
      .then((s: relationalStore.RdbStore) => {
        this.store = s;
        this.opening = null;
        return s;
      })
      .catch(() => {
        this.opening = null;
        throw new Error('getRdbStore failed');
      });
    return await this.opening;
  }

  private async ensureTables(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql(SQL_CREATE_META);
    await store.executeSql(SQL_CREATE_RECIPE);
  }

  private async getMeta(store: relationalStore.RdbStore, key: string): Promise<string> {
    const rs = await store.querySql('SELECT value FROM app_meta WHERE key = ?', [key]);
    let v = '';
    if (rs.goToFirstRow()) {
      v = rs.getString(rs.getColumnIndex('value'));
    }
    rs.close();
    return v;
  }

  private async setMeta(store: relationalStore.RdbStore, key: string, value: string): Promise<void> {
    await store.executeSql('INSERT OR REPLACE INTO app_meta (key, value) VALUES (?, ?)', [key, value]);
  }

  private async getRecipeCount(store: relationalStore.RdbStore): Promise<number> {
    const rs = await store.querySql('SELECT COUNT(*) AS c FROM recipe');
    let n = 0;
    if (rs.goToFirstRow()) {
      n = rs.getLong(rs.getColumnIndex('c'));
    }
    rs.close();
    return n;
  }

  private async migrateSchemaIfNeeded(store: relationalStore.RdbStore): Promise<void> {
    const v = await this.getMeta(store, META_SCHEMA);
    if (v === CURRENT_SCHEMA_VERSION) {
      return;
    }
    const count = await this.getRecipeCount(store);
    if (v.length > 0 || count > 0) {
      await store.executeSql('DROP TABLE IF EXISTS recipe');
      await store.executeSql('DROP TABLE IF EXISTS app_meta');
    }
    await this.ensureTables(store);
    await this.setMeta(store, META_SCHEMA, CURRENT_SCHEMA_VERSION);
  }

  private rowToRecipeWithId(
    id: number,
    name: string,
    stepsJson: string,
    stuffJson: string,
    toolsJson: string,
    methodsJson: string,
    tagsJson: string,
    emojisJson: string,
    difficulty: string,
  ): RecipeWithId {
    const stuff = parseStringArrayJson(stuffJson);
    const tools = parseStringArrayJson(toolsJson);
    const methods = parseMethodsJson(methodsJson);
    const tags = parseStringArrayJson(tagsJson);
    const emojis = parseStringArrayJson(emojisJson);
    const steps = parseStepsJson(stepsJson);
    const r: RecipeWithId = {
      id: id,
      name: name,
      stuff: stuff,
      tools: tools,
    };
    r.steps = steps;
    const diff = difficulty as Difficulty | '';
    if (diff.length > 0) {
      r.difficulty = diff;
    }
    if (tags.length > 0) {
      r.tags = tags;
    }
    if (emojis.length > 0) {
      r.emojis = emojis;
    }
    if (methods.length > 0) {
      r.methods = methods;
    }
    return r;
  }

  private async importFromParsed(store: relationalStore.RdbStore, items: RawRecipeRow[], bundleHash: string): Promise<void> {
    await store.beginTransaction();
    try {
      await store.executeSql('DELETE FROM recipe');
      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const row: RecipeItem = {
          name: item.name,
          stuff: item.stuff ?? [],
          tools: item.tools ?? [],
        };
        if (item.emojis !== undefined) {
          row.emojis = item.emojis;
        }
        if (item.difficulty !== undefined) {
          row.difficulty = item.difficulty;
        }
        if (item.tags !== undefined) {
          row.tags = item.tags;
        }
        if (item.methods !== undefined) {
          const mh: ('炒' | '煎' | '烘' | '炸')[] = [];
          for (let j = 0; j < item.methods.length; j++) {
            const m = item.methods[j];
            if (m === '炒' || m === '煎' || m === '烘' || m === '炸') {
              mh.push(m);
            }
          }
          if (mh.length > 0) {
            row.methods = mh;
          }
        }
        const stepsArr = item.steps ?? [];
        const diffStr = row.difficulty !== undefined ? String(row.difficulty) : '';
        const bucket: relationalStore.ValuesBucket = {
          id: i,
          name: row.name,
          steps: JSON.stringify(stepsArr),
          stuff_json: JSON.stringify(row.stuff),
          tools_json: JSON.stringify(row.tools),
          methods_json: JSON.stringify(row.methods ?? []),
          tags_json: JSON.stringify(row.tags ?? []),
          emojis_json: JSON.stringify(row.emojis ?? []),
          difficulty: diffStr,
        };
        await store.insert('recipe', bucket);
      }
      await this.setMeta(store, META_BUNDLE_HASH, bundleHash);
      await store.commit();
    } catch {
      await store.rollBack();
      throw new Error('recipe import failed');
    }
  }

  /**
   * 打开库、迁移表结构、按 bundle 哈希决定是否从 rawfile 全量重导。
   */
  async ensureReady(context: common.Context): Promise<void> {
    const store = await this.getStore(context);
    await this.ensureTables(store);
    await this.migrateSchemaIfNeeded(store);

    const bytes = await this.readRawRecipeBytes(context);
    const hash = await sha256HexOfBytes(bytes);
    const oldHash = await this.getMeta(store, META_BUNDLE_HASH);
    const count = await this.getRecipeCount(store);
    if (oldHash === hash && count > 0) {
      return;
    }

    const text = utf8BytesToString(bytes);
    const parsed = JSON.parse(text) as RawRecipeRow[];
    if (!Array.isArray(parsed)) {
      throw new Error('recipe.json is not an array');
    }
    await this.importFromParsed(store, parsed, hash);
  }

  /**
   * 从当前库读出全部菜谱（调用前需已 ensureReady）。
   */
  async readAllRecipes(): Promise<RecipeWithId[]> {
    if (this.store === null) {
      return [];
    }
    const rs = await this.store.querySql(
      'SELECT id, name, steps, stuff_json, tools_json, methods_json, tags_json, emojis_json, difficulty ' +
        'FROM recipe ORDER BY id ASC',
    );
    const out: RecipeWithId[] = [];
    while (rs.goToNextRow()) {
      const id = rs.getLong(rs.getColumnIndex('id'));
      const name = rs.getString(rs.getColumnIndex('name'));
      const steps = rs.getString(rs.getColumnIndex('steps'));
      const stuffJson = rs.getString(rs.getColumnIndex('stuff_json'));
      const toolsJson = rs.getString(rs.getColumnIndex('tools_json'));
      const methodsJson = rs.getString(rs.getColumnIndex('methods_json'));
      const tagsJson = rs.getString(rs.getColumnIndex('tags_json'));
      const emojisJson = rs.getString(rs.getColumnIndex('emojis_json'));
      const difficulty = rs.getString(rs.getColumnIndex('difficulty'));
      out.push(this.rowToRecipeWithId(id, name, steps, stuffJson, toolsJson, methodsJson, tagsJson, emojisJson, difficulty));
    }
    rs.close();
    return out;
  }
}
