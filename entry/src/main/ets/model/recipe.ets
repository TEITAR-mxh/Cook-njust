/** 与 Web `useRecipeStore` 一致：生存 / 模糊 / 严格 */
export type SearchMode = 'survival' | 'loose' | 'strict'

export type Difficulty = '简单' | '普通' | '困难'

export interface RecipeItem {
  name: string
  link?: string
  bv?: string
  stuff: string[]
  emojis?: string[]
  difficulty?: Difficulty | ''
  tags?: string[]
  methods?: ('炒' | '煎' | '烘' | '炸')[]
  tools: string[]
}

export type Recipes = RecipeItem[]

/** 与 Web 端 Dexie 一致：数组下标作为稳定 id，供收藏/历史引用 */
export interface RecipeWithId extends RecipeItem {
  id: number
}

export interface StuffItem {
  name: string
  emoji: string
  image?: string
  alias?: string
  icon?: string
  label?: string
}
