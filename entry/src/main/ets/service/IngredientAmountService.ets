/**
 * 食材用量归一化与人数换算服务。
 * 纯函数，无副作用。
 */

/** 支持识别的中文及常见数量单位 */
const UNITS: string[] = [
  '大勺', '小勺', '毫升', '升', '克', '斤', '两', '杯', '勺', '个',
  '片', '块', '段', '条', '根', '颗', '粒', '把', '捆', '包',
  'g', 'ml', 'L', 'kg',
]

interface ParsedAmount {
  value: number
  unit: string
}

/**
 * 尝试从用量字符串中解析数值 + 单位。
 * 返回 null 表示无法解析。
 */
function parseAmount(amount: string): ParsedAmount | null {
  const trimmed = amount.trim()
  if (trimmed.length === 0) {
    return null
  }

  // 匹配最开头的数字部分（支持小数和分数如 1/2）
  let numStr = ''
  let pos = 0
  // 可选负号（实际不会有负数食材，兼容处理）
  while (pos < trimmed.length) {
    const ch = trimmed[pos]
    if ((ch >= '0' && ch <= '9') || ch === '.' || ch === '/') {
      numStr += ch
      pos++
    } else {
      break
    }
  }

  if (numStr.length === 0) {
    return null
  }

  let value: number
  if (numStr.includes('/')) {
    // 处理分数，如 "1/2"
    const parts = numStr.split('/')
    if (parts.length === 2) {
      const numerator = parseFloat(parts[0])
      const denominator = parseFloat(parts[1])
      if (isNaN(numerator) || isNaN(denominator) || denominator === 0) {
        return null
      }
      value = numerator / denominator
    } else {
      return null
    }
  } else {
    value = parseFloat(numStr)
    if (isNaN(value)) {
      return null
    }
  }

  const rest = trimmed.substring(pos).trim()

  // 匹配已知单位（从长到短，避免"大勺"被"勺"截断）
  for (let i = 0; i < UNITS.length; i++) {
    if (rest.startsWith(UNITS[i])) {
      return { value, unit: UNITS[i] }
    }
  }

  // 没找到已知单位，但有后缀文字，则以整段后缀作为单位
  if (rest.length > 0) {
    return { value, unit: rest }
  }

  // 纯数字（无单位）
  return { value, unit: '' }
}

/**
 * 格式化数字：去除尾部多余的零，最多保留 1 位小数。
 */
function formatNumber(n: number): string {
  if (n === Math.floor(n)) {
    return n.toFixed(0)
  }
  const s = n.toFixed(1)
  return s.endsWith('.0') ? n.toFixed(0) : s
}

/**
 * 将食材用量字符串按人数比例换算。
 * @param amount 原始用量字符串，如 "2个", "200克", "1/2杯"
 * @param multiplier 换算倍率（目标人数 / 原始人数）
 * @returns 换算后的字符串；若无法解析则返回原字符串
 */
export function scaleIngredientAmount(amount: string, multiplier: number): string {
  if (multiplier === 1) {
    return amount
  }
  const parsed = parseAmount(amount)
  if (parsed === null) {
    return amount
  }
  const scaled = parsed.value * multiplier
  const numPart = formatNumber(scaled)
  return parsed.unit.length > 0 ? `${numPart}${parsed.unit}` : numPart
}
