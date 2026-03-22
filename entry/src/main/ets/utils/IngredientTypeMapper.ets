/**
 * 食材类型映射工具 - 将食材名称映射到对应的视觉类型
 * 用于 IngredientTag 组件的颜色主题
 */
import { TagType } from '../components/IngredientTag'

export class IngredientTypeMapper {
  /**
   * 肉类食材名称集合
   */
  private static readonly MEAT_SET: Set<string> = new Set([
    '午餐肉', '香肠', '腊肠', '鸡肉', '猪肉', '鸡蛋', '虾', '牛肉', '骨头', '鱼', '鱼（Todo）',
    '排骨', '鸡胸肉', '鲜虾' // 原型中的额外肉类
  ])

  /**
   * 碳水/主食类食材名称集合
   */
  private static readonly CARB_SET: Set<string> = new Set([
    '面食', '面包', '米', '方便面',
    '豆腐', '面条', '米饭' // 原型中的额外碳水
  ])

  /**
   * 根据食材名称返回对应的 TagType
   * @param name 食材名称
   * @returns TagType 枚举值
   */
  static getTagType(name: string): TagType {
    if (IngredientTypeMapper.MEAT_SET.has(name)) {
      return TagType.MEAT
    }
    if (IngredientTypeMapper.CARB_SET.has(name)) {
      return TagType.CARB
    }
    // 默认为蔬菜类型(绿色)
    return TagType.VEG
  }

  /**
   * 判断食材是否为厨具(厨具不参与颜色分类)
   * @param name 食材/厨具名称
   * @returns 是否为厨具
   */
  static isTool(name: string): boolean {
    const toolSet = new Set(['烤箱', '空气炸锅', '微波炉', '电饭煲', '一口大锅'])
    return toolSet.has(name)
  }
}
