/**
 * 图片预处理工具
 * 将相机/相册图片处理为模型输入所需的归一化张量（Float32Array）。
 * HiAI NPU 和 MindSpore Lite 引擎共用此预处理逻辑。
 */
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'

export class ImagePreprocessor {
  /**
   * 对本地图片进行缩放和归一化，输出 CHW 格式的 Float32Array。
   *
   * @param imageUri   图片文件 URI
   * @param targetW    模型输入宽度，默认 224
   * @param targetH    模型输入高度，默认 224
   * @param means      RGB 均值，默认 ImageNet [0.485, 0.456, 0.406]（已缩放至 [0,1] 场景）
   * @param stds       RGB 标准差，默认 ImageNet [0.229, 0.224, 0.225]
   * @returns Float32Array(3 × targetW × targetH)，CHW 排布，值域约 [-2.1, 2.6]
   */
  static async preprocess(
    imageUri: string,
    targetW: number = 224,
    targetH: number = 224,
    means: number[] = [0.485, 0.456, 0.406],
    stds: number[] = [0.229, 0.224, 0.225]
  ): Promise<Float32Array> {
    // 1. 读取文件字节
    const file: fileIo.File = await fileIo.open(imageUri, fileIo.OpenMode.READ_ONLY)
    let fd: number = -1
    let buf: ArrayBuffer

    try {
      fd = file.fd
      const stat: fileIo.Stat = await fileIo.stat(imageUri)
      buf = new ArrayBuffer(stat.size)
      const readLen = await fileIo.read(fd, buf)
      if (readLen <= 0) {
        throw new Error(`read returned ${readLen}`)
      }
    } finally {
      if (fd >= 0) {
        try { await fileIo.close(fd) } catch (_e) { /* ignore */ }
      }
    }

    // 2. 解码为 PixelMap（利用系统解码器自动缩放）
    const imageSource: image.ImageSource = image.createImageSource(buf)
    const decodeOpts: image.DecodingOptions = {
      desiredSize: { width: targetW, height: targetH }
    }
    const pixelMap: image.PixelMap = await imageSource.createPixelMap(decodeOpts)
    imageSource.release()

    // 3. 读取像素数据（RGBA → Float32Array 3×H×W CHW）
    const pixelInfo: image.ImageInfo = await pixelMap.getImageInfo()
    const width: number = pixelInfo.size.width
    const height: number = pixelInfo.size.height
    const pixelCount: number = width * height
    const rgbaBuf: ArrayBuffer = new ArrayBuffer(pixelCount * 4)
    await pixelMap.readPixelsToBuffer(rgbaBuf)
    pixelMap.release()
    const pixels: Uint8Array = new Uint8Array(rgbaBuf)

    // 4. RGB 提取 + 归一化 → CHW
    const meanR: number = means[0]
    const meanG: number = means[1]
    const meanB: number = means[2]
    const stdR: number = stds[0]
    const stdG: number = stds[1]
    const stdB: number = stds[2]
    const area: number = pixelCount
    const chw: Float32Array = new Float32Array(3 * area)

    for (let i: number = 0; i < pixelCount; i++) {
      const r: number = pixels[i * 4] / 255.0
      const g: number = pixels[i * 4 + 1] / 255.0
      const b: number = pixels[i * 4 + 2] / 255.0
      chw[0 * area + i] = (r - meanR) / stdR
      chw[1 * area + i] = (g - meanG) / stdG
      chw[2 * area + i] = (b - meanB) / stdB
    }

    return chw
  }
}
