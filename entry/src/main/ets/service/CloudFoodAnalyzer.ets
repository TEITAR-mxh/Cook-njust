/**
 * 百度 AI 菜品识别服务
 * 鉴权流程：API Key + Secret Key → access_token（缓存 25 天） → 菜品识别接口
 * 接口文档：https://ai.baidu.com/ai-doc/IMAGERECOGNITION/Nk3bcxe23
 */
import { http } from '@kit.NetworkKit'
import { fileIo } from '@kit.CoreFileKit'
import { CalorieCalculator } from '../utils/CalorieCalculator'
import { BAIDU_API_KEY, BAIDU_SECRET_KEY } from '../config/CloudApiConfig'

/** access_token 接口响应 */
interface TokenResponse {
  access_token: string
  expires_in: number
}

/** 单条菜品识别结果 */
interface DishItem {
  name: string
  probability: string
  calorie: string
  has_calorie: boolean
}

/** 菜品识别接口响应 */
interface DishResponse {
  result_num: number
  result: DishItem[]
  error_code?: number
  error_msg?: string
}

/** 对外暴露的识别结果 */
export interface CloudAnalysisResult {
  foodName: string
  calories: number
  protein: number
  fat: number
  carbs: number
  servingWeight: number
}

// ── 常量 ─────────────────────────────────────────────────────────────────────

const TOKEN_URL =
  `https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials` +
  `&client_id=${BAIDU_API_KEY}&client_secret=${BAIDU_SECRET_KEY}`

const DISH_API_BASE = 'https://aip.baidubce.com/rest/2.0/image-classify/v2/dish'

/** 默认营养（未命中本地库时使用） */
const DEFAULT_SERVING = 200

const TIMEOUT_MS = 20000

// ── 状态缓存（静态，app 生命周期内有效） ──────────────────────────────────────

let cachedToken: string = ''
/** token 过期时间戳（ms），提前 1 小时刷新 */
let tokenExpiry: number = 0

export class CloudFoodAnalyzer {

  // ── 公共入口 ──────────────────────────────────────────────────────────────

  /**
   * 识别本地图片文件中的菜品，返回名称 + 营养数据。
   * @param imageUri  本地图片 URI（file://media/... 或 file:// 路径）
   * @returns 识别结果，失败时返回 null
   */
  static async analyze(imageUri: string): Promise<CloudAnalysisResult | null> {
    // 1. 获取 access_token
    let token: string
    try {
      token = await CloudFoodAnalyzer.ensureToken()
    } catch (e) {
      console.error('[CloudFoodAnalyzer] 获取 token 失败:', JSON.stringify(e))
      return null
    }

    // 2. 图片转 base64
    let base64: string
    try {
      base64 = await CloudFoodAnalyzer.uriToBase64(imageUri)
    } catch (e) {
      console.error('[CloudFoodAnalyzer] 图片读取失败:', JSON.stringify(e))
      return null
    }

    // 3. 调用菜品识别接口
    let foodName: string
    try {
      foodName = await CloudFoodAnalyzer.callDishApi(token, base64)
    } catch (e) {
      console.error('[CloudFoodAnalyzer] 菜品识别请求失败:', JSON.stringify(e))
      return null
    }

    if (foodName.length === 0) return null

    // 4. 本地营养库查询
    const nutrient =
      CalorieCalculator.lookup(foodName) ??
      CalorieCalculator.fuzzyMatch([foodName])?.data

    if (nutrient !== null && nutrient !== undefined) {
      return {
        foodName,
        calories:      nutrient.calories,
        protein:       nutrient.protein,
        fat:           nutrient.fat,
        carbs:         nutrient.carbs,
        servingWeight: nutrient.servingWeight,
      }
    }

    // 5. 本地未命中：用食物名 + 默认营养占位，让用户调整份量
    console.warn(`[CloudFoodAnalyzer] "${foodName}" 不在本地库，使用默认营养数据`)
    return {
      foodName,
      calories:      150,
      protein:       6,
      fat:           5,
      carbs:         20,
      servingWeight: DEFAULT_SERVING,
    }
  }

  // ── token 管理 ────────────────────────────────────────────────────────────

  private static async ensureToken(): Promise<string> {
    const now = Date.now()
    if (cachedToken.length > 0 && now < tokenExpiry) {
      return cachedToken
    }

    const req = http.createHttp()
    try {
      const res = await req.request(TOKEN_URL, {
        method: http.RequestMethod.GET,
        connectTimeout: TIMEOUT_MS,
        readTimeout: TIMEOUT_MS,
      })
      if (res.responseCode !== 200) {
        throw new Error(`token 接口返回 ${res.responseCode}`)
      }
      const parsed = JSON.parse(res.result as string) as TokenResponse
      cachedToken = parsed.access_token
      // 提前 1 小时过期，避免边界失效（expires_in 单位秒）
      tokenExpiry = now + (parsed.expires_in - 3600) * 1000
      return cachedToken
    } finally {
      req.destroy()
    }
  }

  // ── 菜品识别接口 ──────────────────────────────────────────────────────────

  private static async callDishApi(token: string, base64: string): Promise<string> {
    const url = `${DISH_API_BASE}?access_token=${token}`

    // 百度菜品接口要求 application/x-www-form-urlencoded
    // base64 中可能含 + / = 需要 URL 编码
    const encodedImage = CloudFoodAnalyzer.urlEncodeBase64(base64)
    const body = `image=${encodedImage}&baike_num=0`

    const req = http.createHttp()
    try {
      const res = await req.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        extraData: body,
        connectTimeout: TIMEOUT_MS,
        readTimeout: TIMEOUT_MS,
      })

      if (res.responseCode !== 200) {
        throw new Error(`菜品接口返回 ${res.responseCode}`)
      }

      const parsed = JSON.parse(res.result as string) as DishResponse

      if (parsed.error_code !== undefined && parsed.error_code !== 0) {
        console.warn(`[CloudFoodAnalyzer] 百度 API 错误 ${parsed.error_code}: ${parsed.error_msg ?? ''}`)
        return ''
      }

      if (parsed.result_num <= 0 || parsed.result.length === 0) {
        return ''
      }

      // 取置信度最高的第一条
      const top = parsed.result[0]
      console.info(`[CloudFoodAnalyzer] 识别结果: ${top.name} (${top.probability})`)
      return top.name.trim()
    } finally {
      req.destroy()
    }
  }

  // ── 工具方法 ──────────────────────────────────────────────────────────────

  /**
   * 将图片 URI 读取并编码为 base64 字符串。
   * 支持 file://media/... 媒体库 URI（直接传入 fileIo.open，不需剥离前缀）。
   */
  private static async uriToBase64(uri: string): Promise<string> {
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY)
    try {
      const stat = await fileIo.stat(uri)
      const buf  = new ArrayBuffer(stat.size)
      try {
        await fileIo.read(file.fd, buf)
      } catch {
        throw new Error('读取文件内容失败')
      }
      return CloudFoodAnalyzer.arrayBufferToBase64(buf)
    } finally {
      try {
        await fileIo.close(file.fd)
      } catch {
        // 关闭失败时静默忽略，避免掩盖 try 块中的原始异常
      }
    }
  }

  private static arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer)
    const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    let result = ''
    let i = 0
    while (i < bytes.length) {
      const b0 = bytes[i++]
      const b1 = i < bytes.length ? bytes[i++] : 0
      const b2 = i < bytes.length ? bytes[i++] : 0
      result += CHARS.charAt(b0 >> 2)
      result += CHARS.charAt(((b0 & 3) << 4) | (b1 >> 4))
      result += CHARS.charAt(((b1 & 15) << 2) | (b2 >> 6))
      result += CHARS.charAt(b2 & 63)
    }
    const pad = bytes.length % 3
    if (pad === 1) {
      result = result.slice(0, -2) + '=='
    } else if (pad === 2) {
      result = result.slice(0, -1) + '='
    }
    return result
  }

  /**
   * 对 base64 字符串进行 URL 编码。
   * base64 中的 + → %2B，/ → %2F，= → %3D。
   */
  private static urlEncodeBase64(b64: string): string {
    return b64
      .split('+').join('%2B')
      .split('/').join('%2F')
      .split('=').join('%3D')
  }
}
