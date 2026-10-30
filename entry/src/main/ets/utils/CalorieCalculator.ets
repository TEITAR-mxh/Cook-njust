/**
 * 热量计算工具类
 * 内置 60+ 种常见食物的营养数据，支持本地查询、模糊匹配与份量换算。
 * 数据来源：《中国食物成分表（第6版）》，每 100g 可食部分计。
 */

/** 每 100g 可食部分的营养素含量 */
export interface NutrientData {
  /** 热量（千卡） */
  calories: number
  /** 蛋白质（g） */
  protein: number
  /** 脂肪（g） */
  fat: number
  /** 碳水化合物（g） */
  carbs: number
  /** 默认单份重量（g），用于份量换算 */
  servingWeight: number
}

/** 识别+计算后的食物营养结果 */
export interface FoodNutrition {
  foodName: string
  quantity: number
  unit: string
  /** 总热量（千卡） */
  totalCalories: number
  /** 总蛋白质（g） */
  totalProtein: number
  /** 总脂肪（g） */
  totalFat: number
  /** 总碳水（g） */
  totalCarbs: number
  /** 来源：'local' = 本地库，'cloud' = 云端，'manual' = 手动输入 */
  source: 'local' | 'cloud' | 'manual'
}

/** fuzzyMatch 返回结果（避免 ArkTS 禁止内联对象字面量类型） */
export interface FuzzyMatchResult {
  name: string
  data: NutrientData
}

/** calcByQuantity 返回结果（避免 ArkTS 不支持 Pick<> 工具类型） */
export interface CalcResult {
  totalCalories: number
  totalProtein: number
  totalFat: number
  totalCarbs: number
}

export class CalorieCalculator {
  /**
   * 本地营养数据库（60+ 种常见中国食材与菜肴）
   * Key：食物标准名称（中文）
   */
  private static readonly DB: Map<string, NutrientData> = new Map<string, NutrientData>([
    // ── 主食与谷物 ───────────────────────────────────────────────────
    ['米饭',    { calories: 116, protein: 2.6,  fat: 0.3,  carbs: 25.6, servingWeight: 200 }],
    ['糙米饭',  { calories: 111, protein: 2.8,  fat: 0.9,  carbs: 22.8, servingWeight: 200 }],
    ['面条',    { calories: 137, protein: 4.8,  fat: 0.7,  carbs: 28.2, servingWeight: 200 }],
    ['馒头',    { calories: 221, protein: 7.0,  fat: 1.1,  carbs: 47.0, servingWeight: 100 }],
    ['白粥',    { calories:  46, protein: 1.1,  fat: 0.3,  carbs:  9.8, servingWeight: 250 }],
    ['包子',    { calories: 236, protein: 8.0,  fat: 5.6,  carbs: 38.0, servingWeight: 100 }],
    ['饺子',    { calories: 239, protein: 9.5,  fat: 6.3,  carbs: 35.5, servingWeight: 150 }],
    ['面包',    { calories: 265, protein: 8.3,  fat: 3.2,  carbs: 51.5, servingWeight: 100 }],
    ['玉米',    { calories: 112, protein: 4.0,  fat: 1.2,  carbs: 22.8, servingWeight: 150 }],
    ['燕麦',    { calories: 389, protein: 16.9, fat: 6.9,  carbs: 66.3, servingWeight:  80 }],
    ['红薯',    { calories:  86, protein: 1.6,  fat: 0.2,  carbs: 19.7, servingWeight: 150 }],
    ['土豆',    { calories:  77, protein: 2.0,  fat: 0.2,  carbs: 17.2, servingWeight: 200 }],
    // ── 肉禽蛋水产 ───────────────────────────────────────────────────
    ['猪肉',    { calories: 143, protein: 20.3, fat:  6.2, carbs:  1.5, servingWeight: 100 }],
    ['猪排骨',  { calories: 278, protein: 18.3, fat: 22.6, carbs:  0.0, servingWeight: 150 }],
    ['猪肝',    { calories: 129, protein: 19.3, fat:  3.5, carbs:  5.0, servingWeight: 100 }],
    ['牛肉',    { calories: 106, protein: 20.2, fat:  2.3, carbs:  1.2, servingWeight: 100 }],
    ['羊肉',    { calories: 203, protein: 19.0, fat: 14.0, carbs:  0.0, servingWeight: 100 }],
    ['鸡胸肉',  { calories: 133, protein: 19.4, fat:  5.0, carbs:  2.5, servingWeight: 150 }],
    ['鸡腿',    { calories: 181, protein: 16.0, fat: 11.6, carbs:  3.0, servingWeight: 150 }],
    ['鸡翅',    { calories: 240, protein: 17.4, fat: 19.0, carbs:  0.0, servingWeight: 100 }],
    ['三文鱼',  { calories: 208, protein: 20.0, fat: 13.0, carbs:  0.0, servingWeight: 150 }],
    ['草鱼',    { calories: 113, protein: 16.6, fat:  5.2, carbs:  0.0, servingWeight: 150 }],
    ['对虾',    { calories:  93, protein: 18.6, fat:  0.8, carbs:  2.8, servingWeight: 100 }],
    ['螃蟹',    { calories: 103, protein: 17.5, fat:  2.6, carbs:  2.3, servingWeight: 150 }],
    ['鸡蛋',    { calories: 144, protein: 13.3, fat:  8.8, carbs:  2.8, servingWeight:  60 }],
    // ── 蔬菜 ─────────────────────────────────────────────────────────
    ['西红柿',  { calories:  19, protein: 0.9,  fat: 0.2,  carbs:  4.0, servingWeight: 200 }],
    ['番茄',    { calories:  19, protein: 0.9,  fat: 0.2,  carbs:  4.0, servingWeight: 200 }],
    ['黄瓜',    { calories:  15, protein: 0.8,  fat: 0.2,  carbs:  2.9, servingWeight: 200 }],
    ['白菜',    { calories:  17, protein: 1.5,  fat: 0.1,  carbs:  3.2, servingWeight: 200 }],
    ['菠菜',    { calories:  28, protein: 2.6,  fat: 0.3,  carbs:  4.5, servingWeight: 200 }],
    ['胡萝卜',  { calories:  37, protein: 1.0,  fat: 0.2,  carbs:  8.8, servingWeight: 100 }],
    ['茄子',    { calories:  21, protein: 1.1,  fat: 0.2,  carbs:  4.9, servingWeight: 200 }],
    ['豆腐',    { calories:  76, protein: 8.1,  fat: 3.7,  carbs:  4.2, servingWeight: 150 }],
    ['木耳',    { calories:  21, protein: 1.5,  fat: 0.2,  carbs:  5.3, servingWeight: 100 }],
    ['香菇',    { calories:  19, protein: 2.2,  fat: 0.3,  carbs:  5.2, servingWeight: 100 }],
    ['洋葱',    { calories:  40, protein: 1.1,  fat: 0.2,  carbs:  9.0, servingWeight: 100 }],
    ['青椒',    { calories:  23, protein: 1.0,  fat: 0.2,  carbs:  5.5, servingWeight: 100 }],
    ['豆芽',    { calories:  18, protein: 2.1,  fat: 0.1,  carbs:  3.8, servingWeight: 100 }],
    ['西兰花',  { calories:  33, protein: 4.2,  fat: 0.6,  carbs:  6.6, servingWeight: 200 }],
    ['冬瓜',    { calories:  10, protein: 0.4,  fat: 0.2,  carbs:  2.6, servingWeight: 300 }],
    ['芹菜',    { calories:  14, protein: 0.6,  fat: 0.1,  carbs:  3.3, servingWeight: 150 }],
    // ── 水果 ─────────────────────────────────────────────────────────
    ['苹果',    { calories:  52, protein: 0.3,  fat: 0.2,  carbs: 13.8, servingWeight: 200 }],
    ['香蕉',    { calories:  89, protein: 1.1,  fat: 0.3,  carbs: 22.8, servingWeight: 120 }],
    ['橙子',    { calories:  47, protein: 0.9,  fat: 0.1,  carbs: 11.8, servingWeight: 200 }],
    ['葡萄',    { calories:  67, protein: 0.6,  fat: 0.4,  carbs: 17.2, servingWeight: 200 }],
    ['西瓜',    { calories:  30, protein: 0.6,  fat: 0.3,  carbs:  7.6, servingWeight: 300 }],
    // ── 乳制品与豆制品 ───────────────────────────────────────────────
    ['牛奶',    { calories:  65, protein: 3.3,  fat: 3.6,  carbs:  4.8, servingWeight: 250 }],
    ['酸奶',    { calories:  72, protein: 2.5,  fat: 2.7,  carbs:  9.3, servingWeight: 200 }],
    ['豆浆',    { calories:  33, protein: 3.0,  fat: 1.6,  carbs:  2.0, servingWeight: 300 }],
    // ── 常见家常菜 ───────────────────────────────────────────────────
    ['番茄炒蛋', { calories: 120, protein: 7.2, fat: 7.3,  carbs:  6.8, servingWeight: 200 }],
    ['西红柿炒鸡蛋', { calories: 120, protein: 7.2, fat: 7.3, carbs: 6.8, servingWeight: 200 }],
    ['红烧肉',  { calories: 508, protein: 7.7,  fat: 50.6, carbs:  7.5, servingWeight: 150 }],
    ['麻婆豆腐', { calories:  95, protein: 6.0, fat: 6.2,  carbs:  4.5, servingWeight: 200 }],
    ['蒸蛋',    { calories:  65, protein: 7.5,  fat: 3.4,  carbs:  2.0, servingWeight: 150 }],
    ['水煮鱼',  { calories: 150, protein: 15.0, fat: 8.5,  carbs:  3.0, servingWeight: 300 }],
    ['宫保鸡丁', { calories: 180, protein: 14.0, fat: 9.5, carbs:  8.0, servingWeight: 200 }],
    ['炒青菜',  { calories:  45, protein: 2.0,  fat: 2.5,  carbs:  5.0, servingWeight: 200 }],
    ['蛋炒饭',  { calories: 200, protein: 5.5,  fat: 6.0,  carbs: 31.0, servingWeight: 250 }],
    ['糖醋里脊', { calories: 260, protein: 12.0, fat: 12.0, carbs: 27.0, servingWeight: 200 }],
    ['清蒸鱼',  { calories: 100, protein: 18.0, fat: 2.5,  carbs:  0.0, servingWeight: 300 }],
    ['回锅肉',  { calories: 395, protein: 12.0, fat: 37.0, carbs:  5.0, servingWeight: 150 }],
    ['拌黄瓜',  { calories:  25, protein: 0.8,  fat: 0.5,  carbs:  4.5, servingWeight: 200 }],
    ['酸辣土豆丝', { calories: 80, protein: 1.8, fat: 2.5, carbs: 14.0, servingWeight: 200 }],
    // ── 坚果零食 ─────────────────────────────────────────────────────
    ['花生',    { calories: 567, protein: 25.8, fat: 49.2, carbs: 16.1, servingWeight:  30 }],
    ['腰果',    { calories: 553, protein: 18.2, fat: 43.8, carbs: 30.2, servingWeight:  30 }],
    ['核桃',    { calories: 654, protein: 15.2, fat: 65.2, carbs: 13.7, servingWeight:  20 }],
    ['白砂糖',  { calories: 400, protein:  0.0, fat:  0.0, carbs: 100.0, servingWeight: 10 }],
    // ── 西式主食 / 三明治 / 面食 ─────────────────────────────────────
    ['汉堡',    { calories: 290, protein: 13.0, fat: 12.0, carbs: 32.0, servingWeight: 200 }],
    ['披萨',    { calories: 270, protein: 11.0, fat: 10.0, carbs: 33.0, servingWeight: 150 }],
    ['热狗',    { calories: 290, protein: 10.0, fat: 17.0, carbs: 24.0, servingWeight: 150 }],
    ['三明治',  { calories: 250, protein: 12.0, fat: 11.0, carbs: 26.0, servingWeight: 200 }],
    ['俱乐部三明治', { calories: 250, protein: 12.0, fat: 11.0, carbs: 26.0, servingWeight: 200 }],
    ['烤奶酪三明治', { calories: 350, protein: 13.0, fat: 18.0, carbs: 34.0, servingWeight: 150 }],
    ['手撕猪肉三明治', { calories: 280, protein: 15.0, fat: 13.0, carbs: 26.0, servingWeight: 200 }],
    ['龙虾卷',  { calories: 280, protein: 14.0, fat: 14.0, carbs: 26.0, servingWeight: 200 }],
    ['早餐卷饼', { calories: 220, protein: 10.0, fat: 11.0, carbs: 22.0, servingWeight: 200 }],
    ['墨西哥卷饼', { calories: 220, protein: 10.0, fat: 11.0, carbs: 20.0, servingWeight: 200 }],
    ['鸡肉墨西哥饼', { calories: 280, protein: 14.0, fat: 14.0, carbs: 26.0, servingWeight: 200 }],
    ['玉米片',  { calories: 340, protein: 9.0,  fat: 18.0, carbs: 36.0, servingWeight: 150 }],
    ['意式烤面包', { calories: 180, protein: 4.0, fat: 8.0, carbs: 24.0, servingWeight: 120 }],
    ['蒜香面包', { calories: 330, protein: 8.0,  fat: 14.0, carbs: 44.0, servingWeight: 100 }],
    ['法式吐司', { calories: 230, protein: 7.0,  fat: 9.0,  carbs: 30.0, servingWeight: 150 }],
    ['法式吐司三明治', { calories: 250, protein: 13.0, fat: 14.0, carbs: 20.0, servingWeight: 180 }],
    ['松饼',    { calories: 230, protein: 6.0,  fat: 8.0,  carbs: 34.0, servingWeight: 150 }],
    ['华夫饼',  { calories: 310, protein: 7.0,  fat: 14.0, carbs: 40.0, servingWeight: 100 }],
    // ── 西式面食 / 烩饭 ─────────────────────────────────────────────
    ['意大利面', { calories: 160, protein: 6.0, fat: 2.0, carbs: 30.0, servingWeight: 250 }],
    ['番茄肉酱面', { calories: 160, protein: 8.0, fat: 6.0, carbs: 20.0, servingWeight: 250 }],
    ['培根蛋酱面', { calories: 200, protein: 9.0, fat: 9.0, carbs: 22.0, servingWeight: 250 }],
    ['奶酪通心粉', { calories: 200, protein: 8.0, fat: 9.0, carbs: 22.0, servingWeight: 250 }],
    ['意式饺子', { calories: 230, protein: 9.0, fat: 8.0, carbs: 30.0, servingWeight: 200 }],
    ['意式烩饭', { calories: 180, protein: 5.0, fat: 6.0, carbs: 27.0, servingWeight: 250 }],
    ['意大利土豆团', { calories: 180, protein: 5.0, fat: 4.0, carbs: 32.0, servingWeight: 200 }],
    ['千层面',  { calories: 180, protein: 10.0, fat: 8.0, carbs: 18.0, servingWeight: 250 }],
    ['拉面',    { calories: 150, protein: 6.0,  fat: 4.0,  carbs: 22.0, servingWeight: 300 }],
    ['泰式炒河粉', { calories: 190, protein: 8.0, fat: 7.0, carbs: 25.0, servingWeight: 250 }],
    ['越南河粉', { calories: 100, protein: 6.0, fat: 2.0, carbs: 15.0, servingWeight: 300 }],
    ['西班牙海鲜饭', { calories: 160, protein: 7.0, fat: 5.0, carbs: 22.0, servingWeight: 300 }],
    ['石锅拌饭', { calories: 150, protein: 5.0, fat: 4.0, carbs: 24.0, servingWeight: 300 }],
    ['炸酱面',  { calories: 180, protein: 7.0, fat: 6.0, carbs: 26.0, servingWeight: 300 }],
    // ── 西式肉 / 鱼 / 海鲜 ──────────────────────────────────────────
    ['牛排',    { calories: 250, protein: 24.0, fat: 17.0, carbs:  0.0, servingWeight: 150 }],
    ['菲力牛排', { calories: 250, protein: 24.0, fat: 17.0, carbs:  0.0, servingWeight: 150 }],
    ['上肋牛排', { calories: 300, protein: 20.0, fat: 24.0, carbs:  0.0, servingWeight: 150 }],
    ['猪排',    { calories: 250, protein: 22.0, fat: 17.0, carbs:  0.0, servingWeight: 150 }],
    ['烤猪肋排', { calories: 290, protein: 20.0, fat: 22.0, carbs:  5.0, servingWeight: 150 }],
    ['生牛肉片', { calories: 120, protein: 20.0, fat:  4.0, carbs:  1.0, servingWeight: 100 }],
    ['鞑靼牛肉', { calories: 130, protein: 19.0, fat:  5.5, carbs:  1.0, servingWeight: 100 }],
    ['鹅肝',    { calories: 460, protein: 11.0, fat: 44.0, carbs:  4.0, servingWeight: 80 }],
    ['烤三文鱼', { calories: 200, protein: 22.0, fat: 12.0, carbs:  0.0, servingWeight: 150 }],
    ['生鱼片',  { calories: 130, protein: 20.0, fat:  5.0, carbs:  1.0, servingWeight: 100 }],
    ['金枪鱼塔塔', { calories: 150, protein: 22.0, fat: 6.0, carbs: 1.0, servingWeight: 100 }],
    ['炸鱼薯条', { calories: 240, protein: 12.0, fat: 12.0, carbs: 20.0, servingWeight: 250 }],
    ['炸鱿鱼',  { calories: 230, protein: 13.0, fat: 12.0, carbs: 18.0, servingWeight: 150 }],
    ['蟹肉饼',  { calories: 200, protein: 12.0, fat: 11.0, carbs: 14.0, servingWeight: 150 }],
    ['青口贝',  { calories:  86, protein: 12.0, fat:  2.2, carbs:  4.0, servingWeight: 150 }],
    ['生蚝',    { calories:  80, protein:  9.0, fat:  2.3, carbs:  4.0, servingWeight: 100 }],
    ['扇贝',    { calories: 110, protein: 17.0, fat:  1.5, carbs:  5.0, servingWeight: 150 }],
    ['法式蜗牛', { calories: 130, protein: 16.0, fat:  6.0, carbs:  2.0, servingWeight: 100 }],
    ['北京烤鸭', { calories: 340, protein: 15.0, fat: 28.0, carbs:  6.0, servingWeight: 150 }],
    ['咖喱鸡',  { calories: 160, protein: 15.0, fat:  8.0, carbs:  7.0, servingWeight: 250 }],
    ['酸橘汁腌鱼', { calories: 90, protein: 15.0, fat: 2.0, carbs: 4.0, servingWeight: 150 }],
    // ── 西式小吃 / 薯类 / 豆类 ─────────────────────────────────────
    ['薯条',    { calories: 310, protein: 4.0,  fat: 15.0, carbs: 41.0, servingWeight: 150 }],
    ['洋葱圈',  { calories: 350, protein: 5.0,  fat: 18.0, carbs: 42.0, servingWeight: 100 }],
    ['春卷',    { calories: 230, protein: 6.0,  fat: 11.0, carbs: 27.0, servingWeight: 150 }],
    ['煎饺',    { calories: 230, protein: 9.0,  fat:  7.0, carbs: 32.0, servingWeight: 150 }],
    ['章鱼小丸子', { calories: 220, protein: 8.0, fat: 10.0, carbs: 24.0, servingWeight: 150 }],
    ['寿司',    { calories: 150, protein: 6.0,  fat:  1.5, carbs: 28.0, servingWeight: 200 }],
    ['紫菜包饭', { calories: 150, protein: 6.0, fat: 1.5, carbs: 28.0, servingWeight: 200 }],
    ['毛豆',    { calories: 120, protein: 11.0, fat:  5.0, carbs:  9.0, servingWeight: 100 }],
    ['鹰嘴豆泥', { calories: 160, protein: 5.0,  fat:  9.0, carbs: 15.0, servingWeight: 100 }],
    ['炸豆丸子', { calories: 330, protein: 13.0, fat: 18.0, carbs: 32.0, servingWeight: 150 }],
    ['印度咖喱角', { calories: 260, protein: 6.0, fat: 14.0, carbs: 28.0, servingWeight: 100 }],
    ['鳄梨酱',  { calories: 160, protein: 2.0,  fat: 15.0, carbs:  8.0, servingWeight: 100 }],
    ['肉汁奶酪薯条', { calories: 300, protein: 8.0, fat: 15.0, carbs: 32.0, servingWeight: 250 }],
    ['虾仁玉米糊', { calories: 180, protein: 10.0, fat: 7.0, carbs: 20.0, servingWeight: 250 }],
    ['法式洋葱汤', { calories: 80, protein: 3.0, fat: 3.0, carbs: 10.0, servingWeight: 250 }],
    ['蛤蜊浓汤', { calories: 100, protein: 5.0, fat: 5.0, carbs: 9.0, servingWeight: 250 }],
    ['龙虾浓汤', { calories: 110, protein: 6.0, fat: 6.0, carbs: 8.0, servingWeight: 250 }],
    ['味噌汤',  { calories:  40, protein: 2.0, fat: 1.5, carbs: 4.0, servingWeight: 250 }],
    ['酸辣汤',  { calories:  60, protein: 3.0, fat: 2.0, carbs: 7.0, servingWeight: 250 }],
    // ── 西式沙拉 ────────────────────────────────────────────────────
    ['凯撒沙拉', { calories: 120, protein: 4.0, fat: 9.0, carbs: 6.0, servingWeight: 200 }],
    ['希腊沙拉', { calories:  90, protein: 4.0, fat: 6.0, carbs: 5.0, servingWeight: 200 }],
    ['甜菜沙拉', { calories:  60, protein: 1.5, fat: 3.5, carbs: 6.0, servingWeight: 150 }],
    ['卡普雷塞沙拉', { calories: 130, protein: 7.0, fat: 9.0, carbs: 4.0, servingWeight: 180 }],
    ['海藻沙拉', { calories:  70, protein: 2.0, fat: 4.0, carbs: 7.0, servingWeight: 150 }],
    // ── 西式早餐 / 蛋类 ────────────────────────────────────────────
    ['煎蛋卷',  { calories: 150, protein: 10.0, fat: 11.0, carbs:  2.0, servingWeight: 150 }],
    ['班尼迪克蛋', { calories: 230, protein: 12.0, fat: 17.0, carbs: 8.0, servingWeight: 200 }],
    ['魔鬼蛋',  { calories: 160, protein: 9.0, fat: 13.0, carbs: 2.0, servingWeight: 100 }],
    ['牧场蛋',  { calories: 200, protein: 10.0, fat: 12.0, carbs: 15.0, servingWeight: 200 }],
    // ── 西式甜点 / 烘焙 ────────────────────────────────────────────
    ['苹果派',  { calories: 265, protein: 3.0, fat: 12.5, carbs: 37.0, servingWeight: 100 }],
    ['芝士蛋糕', { calories: 320, protein: 6.0, fat: 20.0, carbs: 30.0, servingWeight: 100 }],
    ['巧克力蛋糕', { calories: 370, protein: 4.5, fat: 20.0, carbs: 45.0, servingWeight: 100 }],
    ['胡萝卜蛋糕', { calories: 410, protein: 4.5, fat: 24.0, carbs: 45.0, servingWeight: 100 }],
    ['红丝绒蛋糕', { calories: 370, protein: 4.0, fat: 18.0, carbs: 48.0, servingWeight: 100 }],
    ['纸杯蛋糕', { calories: 350, protein: 4.0, fat: 15.0, carbs: 50.0, servingWeight: 80 }],
    ['草莓奶油蛋糕', { calories: 300, protein: 4.0, fat: 15.0, carbs: 38.0, servingWeight: 120 }],
    ['巧克力慕斯', { calories: 280, protein: 4.0, fat: 19.0, carbs: 24.0, servingWeight: 100 }],
    ['焦糖布丁', { calories: 280, protein: 4.0, fat: 18.0, carbs: 26.0, servingWeight: 120 }],
    ['意式奶冻', { calories: 280, protein: 4.0, fat: 20.0, carbs: 22.0, servingWeight: 120 }],
    ['提拉米苏', { calories: 360, protein: 5.0, fat: 20.0, carbs: 40.0, servingWeight: 100 }],
    ['冰淇淋',  { calories: 210, protein: 3.5, fat: 11.0, carbs: 24.0, servingWeight: 100 }],
    ['冻酸奶',  { calories: 120, protein: 3.0, fat: 3.0, carbs: 20.0, servingWeight: 150 }],
    ['甜甜圈',  { calories: 420, protein: 5.0, fat: 22.0, carbs: 50.0, servingWeight: 80 }],
    ['马卡龙',  { calories: 430, protein: 6.0, fat: 16.0, carbs: 65.0, servingWeight: 50 }],
    ['曲奇饼干', { calories: 480, protein: 5.0, fat: 24.0, carbs: 64.0, servingWeight: 50 }],
    ['果仁蜜饼', { calories: 420, protein: 6.5, fat: 25.0, carbs: 45.0, servingWeight: 80 }],
    ['贝涅饼',  { calories: 420, protein: 6.0, fat: 22.0, carbs: 50.0, servingWeight: 80 }],
    ['西班牙油条', { calories: 410, protein: 5.0, fat: 22.0, carbs: 50.0, servingWeight: 80 }],
    ['卡诺里卷', { calories: 340, protein: 6.0, fat: 20.0, carbs: 35.0, servingWeight: 80 }],
    ['面包布丁', { calories: 200, protein: 5.0, fat: 6.0, carbs: 32.0, servingWeight: 150 }],
    ['奶酪拼盘', { calories: 350, protein: 20.0, fat: 28.0, carbs: 2.0, servingWeight: 100 }],
  ])

  /** 英文 Food-101 标签 → 中文名映射（food_labels.txt 后 101 个英文标签） */
  private static readonly EN_TO_ZH: Map<string, string> = new Map<string, string>([
    ['apple_pie', '苹果派'],
    ['baby_back_ribs', '烤猪肋排'],
    ['baklava', '果仁蜜饼'],
    ['beef_carpaccio', '生牛肉片'],
    ['beef_tartare', '鞑靼牛肉'],
    ['beet_salad', '甜菜沙拉'],
    ['beignets', '贝涅饼'],
    ['bibimbap', '石锅拌饭'],
    ['bread_pudding', '面包布丁'],
    ['breakfast_burrito', '早餐卷饼'],
    ['bruschetta', '意式烤面包'],
    ['caesar_salad', '凯撒沙拉'],
    ['cannoli', '卡诺里卷'],
    ['caprese_salad', '卡普雷塞沙拉'],
    ['carrot_cake', '胡萝卜蛋糕'],
    ['ceviche', '酸橘汁腌鱼'],
    ['cheesecake', '芝士蛋糕'],
    ['cheese_plate', '奶酪拼盘'],
    ['chicken_curry', '咖喱鸡'],
    ['chicken_quesadilla', '鸡肉墨西哥饼'],
    ['chicken_wings', '鸡翅'],
    ['chocolate_cake', '巧克力蛋糕'],
    ['chocolate_mousse', '巧克力慕斯'],
    ['churros', '西班牙油条'],
    ['clam_chowder', '蛤蜊浓汤'],
    ['club_sandwich', '俱乐部三明治'],
    ['crab_cakes', '蟹肉饼'],
    ['creme_brulee', '焦糖布丁'],
    ['croque_madame', '法式吐司三明治'],
    ['cup_cakes', '纸杯蛋糕'],
    ['deviled_eggs', '魔鬼蛋'],
    ['donuts', '甜甜圈'],
    ['dumplings', '饺子'],
    ['edamame', '毛豆'],
    ['eggs_benedict', '班尼迪克蛋'],
    ['escargots', '法式蜗牛'],
    ['falafel', '炸豆丸子'],
    ['filet_mignon', '菲力牛排'],
    ['fish_and_chips', '炸鱼薯条'],
    ['foie_gras', '鹅肝'],
    ['french_fries', '薯条'],
    ['french_onion_soup', '法式洋葱汤'],
    ['french_toast', '法式吐司'],
    ['fried_calamari', '炸鱿鱼'],
    ['fried_rice', '蛋炒饭'],
    ['frozen_yogurt', '冻酸奶'],
    ['garlic_bread', '蒜香面包'],
    ['gnocchi', '意大利土豆团'],
    ['greek_salad', '希腊沙拉'],
    ['grilled_cheese_sandwich', '烤奶酪三明治'],
    ['grilled_salmon', '三文鱼'],
    ['guacamole', '鳄梨酱'],
    ['gyoza', '煎饺'],
    ['hamburger', '汉堡'],
    ['hot_and_sour_soup', '酸辣汤'],
    ['hot_dog', '热狗'],
    ['huevos_rancheros', '牧场蛋'],
    ['hummus', '鹰嘴豆泥'],
    ['ice_cream', '冰淇淋'],
    ['lasagna', '千层面'],
    ['lobster_bisque', '龙虾浓汤'],
    ['lobster_roll_sandwich', '龙虾卷'],
    ['macaroni_and_cheese', '奶酪通心粉'],
    ['macarons', '马卡龙'],
    ['miso_soup', '味噌汤'],
    ['mussels', '青口贝'],
    ['nachos', '玉米片'],
    ['omelette', '煎蛋卷'],
    ['onion_rings', '洋葱圈'],
    ['oysters', '生蚝'],
    ['pad_thai', '泰式炒河粉'],
    ['paella', '西班牙海鲜饭'],
    ['pancakes', '松饼'],
    ['panna_cotta', '意式奶冻'],
    ['peking_duck', '北京烤鸭'],
    ['pho', '越南河粉'],
    ['pizza', '披萨'],
    ['pork_chop', '猪排'],
    ['poutine', '肉汁奶酪薯条'],
    ['prime_rib', '上肋牛排'],
    ['pulled_pork_sandwich', '手撕猪肉三明治'],
    ['ramen', '拉面'],
    ['ravioli', '意式饺子'],
    ['red_velvet_cake', '红丝绒蛋糕'],
    ['risotto', '意式烩饭'],
    ['samosa', '印度咖喱角'],
    ['sashimi', '生鱼片'],
    ['scallops', '扇贝'],
    ['seaweed_salad', '海藻沙拉'],
    ['shrimp_and_grits', '虾仁玉米糊'],
    ['spaghetti_bolognese', '番茄肉酱面'],
    ['spaghetti_carbonara', '培根蛋酱面'],
    ['spring_rolls', '春卷'],
    ['steak', '牛排'],
    ['strawberry_shortcake', '草莓奶油蛋糕'],
    ['sushi', '寿司'],
    ['tacos', '墨西哥卷饼'],
    ['takoyaki', '章鱼小丸子'],
    ['tiramisu', '提拉米苏'],
    ['tuna_tartare', '金枪鱼塔塔'],
    ['waffles', '华夫饼'],
  ])

  /** 将英文 Food-101 标签转为中文名（无映射则原样返回） */
  private static normalizeName(name: string): string {
    return CalorieCalculator.EN_TO_ZH.get(name) ?? name
  }

  /** 查询食物营养数据（精确匹配，自动做英文→中文转换）。查不到返回 null。 */
  static lookup(foodName: string): NutrientData | null {
    return CalorieCalculator.DB.get(CalorieCalculator.normalizeName(foodName)) ?? null
  }

  /**
   * 模糊匹配：从候选名称列表中找最接近的食物。
   * 先尝试"候选项是否包含数据库 key"或"数据库 key 是否包含候选项"；
   * 再用字符级 Jaccard 相似度降序排列，取得分 > 0.3 的最高项。
   * @param candidates 端侧或云端返回的候选名称（中英文均可）
   * @returns 匹配到的食物名 + 数据，或 null
   */
  static fuzzyMatch(candidates: string[]): FuzzyMatchResult | null {
    let bestName: string = ''
    let bestScore: number = 0
    let bestData: NutrientData | null = null

    const dbKeys = Array.from(CalorieCalculator.DB.keys())

    for (const candidate of candidates) {
      const trimmed = candidate.trim()
      const c = CalorieCalculator.normalizeName(trimmed)
      if (c.length === 0) continue

      for (const key of dbKeys) {
        // 直接包含优先
        if (c.includes(key) || key.includes(c)) {
          const data = CalorieCalculator.DB.get(key)
          if (data !== undefined) {
            return { name: key, data }
          }
        }
        // Jaccard 字符集相似度
        const score = CalorieCalculator.jaccardSimilarity(c, key)
        if (score > bestScore) {
          bestScore = score
          bestName = key
          bestData = CalorieCalculator.DB.get(key) ?? null
        }
      }
    }

    if (bestScore >= 0.3 && bestData !== null) {
      return { name: bestName, data: bestData }
    }
    return null
  }

  /**
   * 按份量计算总营养素。
   * @param data   每 100g 营养数据
   * @param quantity  份数（如 1.5 份）
   * @param servingWeightOverride  可选：覆盖默认单份重量（g）
   */
  static calcByQuantity(
    data: NutrientData,
    quantity: number,
    servingWeightOverride?: number
  ): CalcResult {
    const grams = (servingWeightOverride ?? data.servingWeight) * quantity
    const factor = grams / 100.0
    return {
      totalCalories: Math.round(data.calories * factor),
      totalProtein:  Math.round(data.protein  * factor * 10) / 10,
      totalFat:      Math.round(data.fat       * factor * 10) / 10,
      totalCarbs:    Math.round(data.carbs     * factor * 10) / 10,
    }
  }

  /** 返回数据库中所有食物名称列表（供 UI 手动选择用） */
  static getAllFoodNames(): string[] {
    return Array.from(CalorieCalculator.DB.keys())
  }

  // ── 内部：Jaccard 字符集相似度 ──────────────────────────────────────

  private static jaccardSimilarity(a: string, b: string): number {
    const setA = new Set<string>(a.split(''))
    const setB = new Set<string>(b.split(''))
    let intersection = 0
    setA.forEach((ch: string) => {
      if (setB.has(ch)) intersection++
    })
    const union = setA.size + setB.size - intersection
    return union === 0 ? 0 : intersection / union
  }
}
