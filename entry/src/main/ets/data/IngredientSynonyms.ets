/**
 * 食材同义词库：键为规范名（foodCatalog.ets 中使用的名称），值为同义词数组。
 * 查找时需双向展开：选择"番茄"能匹配含"西红柿"的菜谱，反之亦然。
 */
export const INGREDIENT_SYNONYMS: Map<string, string[]> = new Map<string, string[]>([
  ['番茄', ['西红柿', '圣女果', '樱桃番茄', '小番茄']],
  ['土豆', ['马铃薯', '洋芋', '薯仔', '土豆片', '土豆丝']],
  ['鸡蛋', ['蛋', '鸡子', '鸡卵', '笨鸡蛋', '土鸡蛋', '蛋液']],
  ['胡萝卜', ['红萝卜', '黄萝卜', '胡萝卜丝']],
  ['包菜', ['卷心菜', '圆白菜', '莲花白', '洋白菜', '甘蓝']],
  ['白萝卜', ['萝卜', '白萝卜丝', '萝卜丝']],
  ['猪肉', ['猪肉片', '猪里脊', '猪肉末', '瘦肉', '猪瘦肉', '猪腿肉']],
  ['豆腐', ['嫩豆腐', '老豆腐', '北豆腐', '南豆腐', '内酯豆腐', '豆腐块']],
  ['菌菇', ['蘑菇', '口蘑', '香菇', '冬菇', '椎茸', '平菇', '杏鲍菇', '白玉菇']],
  ['木耳', ['黑木耳', '云耳', '树耳', '木耳丝']],
  ['韭菜', ['韭黄', '韭苔', '韭菜段']],
  ['米饭', ['白饭', '白米饭', '大米饭', '米', '大米', '粳米', '籼米']],
  ['面条', ['挂面', '拉面', '细面', '宽面', '切面', '碱水面', '细圆面']],
  ['洋葱', ['洋葱丝', '洋葱块', '圆葱']],
  ['青椒', ['甜椒', '灯笼椒', '柿子椒', '彩椒', '菜椒']],
  ['红椒', ['红辣椒', '朝天椒', '小红椒', '干辣椒', '辣椒']],
  ['鸡肉', ['鸡胸肉', '鸡腿肉', '鸡翅', '鸡腿', '整鸡', '鸡块']],
  ['虾', ['鲜虾', '河虾', '对虾', '大虾', '基围虾', '草虾']],
  ['虾仁', ['去皮虾', '剥壳虾', '熟虾仁']],
  ['牛肉', ['牛里脊', '牛腩', '牛肉末', '牛腱子', '牛肉片', '肥牛']],
  ['花菜', ['菜花', '西兰花', '绿花椰菜', '白花椰菜', '花椰菜']],
  ['面食', ['面粉', '中筋面粉', '低筋面粉', '高筋面粉', '全麦面粉', '小麦粉']],
  ['粉丝', ['龙口粉丝', '番薯粉丝', '红薯粉丝', '粉条', '宽粉']],
  ['豆皮', ['千张', '豆腐皮', '油皮', '薄百叶']],
])

/**
 * 给定一个食材名，返回它的所有等价名（含自身）。
 * 用于在搜索时扩展用户选择的食材集合。
 */
export function getIngredientAliases(name: string): string[] {
  const result: string[] = [name]

  // 1. 该名作为 key：加入其所有同义词
  const synonymsAsKey = INGREDIENT_SYNONYMS.get(name)
  if (synonymsAsKey !== undefined) {
    for (let i = 0; i < synonymsAsKey.length; i++) {
      result.push(synonymsAsKey[i])
    }
  }

  // 2. 该名作为 value：找到对应的 key 及其他同义词
  INGREDIENT_SYNONYMS.forEach((synonyms: string[], key: string) => {
    let isAlias = false
    for (let i = 0; i < synonyms.length; i++) {
      if (synonyms[i] === name) {
        isAlias = true
        break
      }
    }
    if (isAlias) {
      // 加入 key 本身
      let keyAlreadyIn = false
      for (let i = 0; i < result.length; i++) {
        if (result[i] === key) {
          keyAlreadyIn = true
          break
        }
      }
      if (!keyAlreadyIn) {
        result.push(key)
      }
      // 加入同组的其他同义词
      for (let i = 0; i < synonyms.length; i++) {
        let alreadyIn = false
        for (let j = 0; j < result.length; j++) {
          if (result[j] === synonyms[i]) {
            alreadyIn = true
            break
          }
        }
        if (!alreadyIn) {
          result.push(synonyms[i])
        }
      }
    }
  })

  return result
}
