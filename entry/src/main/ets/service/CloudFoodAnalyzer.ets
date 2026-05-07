/**
 * 云端食物识别分析服务
 * 封装 HTTPS 多模态 API 请求，处理超时与网络异常。
 * TODO: 将 CLOUD_API_URL 替换为真实的食物识别云端接口地址。
 */
import { http } from '@kit.NetworkKit'
import { fileIo } from '@kit.CoreFileKit'

/** 云端 API 响应体结构（对应 JSON.parse 结果，避免索引访问） */
interface CloudApiResponse {
  foodName: string
  calories: number
  protein: number
  fat: number
  carbs: number
  servingWeight: number
}

/** 云端返回的识别结果结构 */
export interface CloudAnalysisResult {
  /** 识别到的食物名称（中文） */
  foodName: string
  /** 每 100g 热量（千卡） */
  calories: number
  /** 每 100g 蛋白质（g） */
  protein: number
  /** 每 100g 脂肪（g） */
  fat: number
  /** 每 100g 碳水化合物（g） */
  carbs: number
  /** 默认单份重量（g） */
  servingWeight: number
}

/**
 * TODO: 替换为真实的多模态食物识别 API URL。
 * 接口约定（POST application/json）：
 *   请求体：{ "image": "<base64 JPEG>" }
 *   响应体：{ "foodName": "番茄炒蛋", "calories": 120, "protein": 7.2,
 *             "fat": 7.3, "carbs": 6.8, "servingWeight": 200 }
 */
const CLOUD_API_URL = 'https://api.example.com/v1/food/analyze'

/** HTTP 超时（毫秒） */
const TIMEOUT_MS = 15000

export class CloudFoodAnalyzer {
  /**
   * 将本地图片文件 base64 编码后上传至云端 API 进行识别。
   * @param imageUri 本地图片 URI（file:// 路径）
   * @returns 识别结果，失败时返回 null
   */
  static async analyze(imageUri: string): Promise<CloudAnalysisResult | null> {
    let base64Data: string
    try {
      base64Data = await CloudFoodAnalyzer.uriToBase64(imageUri)
    } catch (e) {
      console.error('[CloudFoodAnalyzer] 图片转 base64 失败:', JSON.stringify(e))
      return null
    }

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(CLOUD_API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        extraData: JSON.stringify({ image: base64Data }),
        connectTimeout: TIMEOUT_MS,
        readTimeout: TIMEOUT_MS,
      })

      if (response.responseCode !== 200) {
        console.warn(`[CloudFoodAnalyzer] API 返回非 200 状态码: ${response.responseCode}`)
        return null
      }

      const body = response.result as string
      const parsed = JSON.parse(body) as CloudApiResponse

      const foodName      = parsed.foodName
      const calories      = parsed.calories
      const protein       = parsed.protein
      const fat           = parsed.fat
      const carbs         = parsed.carbs
      const servingWeight = parsed.servingWeight > 0 ? parsed.servingWeight : 200

      if (!foodName || calories <= 0) {
        console.warn('[CloudFoodAnalyzer] API 返回格式不符合预期:', body)
        return null
      }

      return { foodName, calories, protein, fat, carbs, servingWeight }
    } catch (e) {
      console.error('[CloudFoodAnalyzer] 请求失败:', JSON.stringify(e))
      return null
    } finally {
      httpRequest.destroy()
    }
  }

  // ── 内部：将图片 URI 读取并编码为 base64 字符串 ───────────────────

  private static async uriToBase64(uri: string): Promise<string> {
    // 处理 file:// 前缀
    const filePath = uri.startsWith('file://') ? uri.substring(7) : uri

    const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY)
    try {
      const stat = await fileIo.stat(filePath)
      const buf = new ArrayBuffer(stat.size)
      await fileIo.read(file.fd, buf)
      return CloudFoodAnalyzer.arrayBufferToBase64(buf)
    } finally {
      await fileIo.close(file.fd)
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
    // 末尾填充
    const pad = bytes.length % 3
    if (pad === 1) {
      result = result.slice(0, -2) + '=='
    } else if (pad === 2) {
      result = result.slice(0, -1) + '='
    }
    return result
  }
}
