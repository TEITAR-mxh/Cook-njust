import { common } from '@kit.AbilityKit';
import type { RecipeItem, RecipeWithId } from '../model/recipe';

const RAW_NAME = 'recipe.json';

function toUint8Array(raw: Uint8Array | ArrayBuffer): Uint8Array {
  if (raw instanceof Uint8Array) {
    return raw;
  }
  return new Uint8Array(raw);
}

/**
 * UTF-8 字节转字符串（不依赖系统 TextDecoder，避免各 SDK API 不一致）
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

export class RecipeRepository {
  private static instance: RecipeRepository | null = null;
  private recipes: RecipeWithId[] = [];

  static getInstance(): RecipeRepository {
    if (RecipeRepository.instance === null) {
      RecipeRepository.instance = new RecipeRepository();
    }
    return RecipeRepository.instance;
  }

  /**
   * 从 resources/rawfile/recipe.json 加载；为每条记录补上与 Web 一致的 id（数组下标）。
   */
  async load(context: common.Context): Promise<void> {
    let raw: Uint8Array | ArrayBuffer;
    try {
      raw = await context.resourceManager.getRawFileContent(RAW_NAME);
    } catch (firstErr) {
      // createModuleContext 在部分 Context 上不存在，直接调用会报 undefined is not callable
      const ctx = context as common.UIAbilityContext;
      if (typeof ctx.createModuleContext === 'function') {
        const moduleCtx = ctx.createModuleContext('entry');
        raw = await moduleCtx.resourceManager.getRawFileContent(RAW_NAME);
      } else {
        throw new Error(String(firstErr));
      }
    }
    const bytes = toUint8Array(raw);
    const text = utf8BytesToString(bytes);
    const parsed: RecipeItem[] = JSON.parse(text) as RecipeItem[];
    this.recipes = parsed.map((item: RecipeItem, index: number): RecipeWithId => {
      const r: RecipeWithId = {
        id: index,
        name: item.name,
        stuff: item.stuff ?? [],
        tools: item.tools ?? [],
      };
      if (item.link !== undefined) {
        r.link = item.link;
      }
      if (item.bv !== undefined) {
        r.bv = item.bv;
      }
      if (item.emojis !== undefined) {
        r.emojis = item.emojis;
      }
      if (item.difficulty !== undefined) {
        r.difficulty = item.difficulty;
      }
      if (item.tags !== undefined) {
        r.tags = item.tags;
      }
      if (item.methods !== undefined) {
        r.methods = item.methods;
      }
      return r;
    });
  }

  getAll(): RecipeWithId[] {
    return this.recipes;
  }

  getCount(): number {
    return this.recipes.length;
  }
}
