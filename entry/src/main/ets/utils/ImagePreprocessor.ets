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

    // 2. 解码为 PixelMap（desiredSize 仅限制解码尺寸，防止超大图内存爆炸）
    const imageSource: image.ImageSource = image.createImageSource(buf)
    const maxDim: number = Math.max(targetW, targetH)
    const decodeOpts: image.DecodingOptions = {
      desiredSize: { width: maxDim * 2, height: maxDim * 2 }
    }
    const pixelMap: image.PixelMap = await imageSource.createPixelMap(decodeOpts)
    imageSource.release()

    // 3. 读取源像素（RGBA，实际尺寸可能不等于 targetW×targetH）
    const pixelInfo: image.ImageInfo = await pixelMap.getImageInfo()
    const srcW: number = pixelInfo.size.width
    const srcH: number = pixelInfo.size.height
    const srcCount: number = srcW * srcH
    const rgbaBuf: ArrayBuffer = new ArrayBuffer(srcCount * 4)
    await pixelMap.readPixelsToBuffer(rgbaBuf)
    pixelMap.release()
    const src: Uint8Array = new Uint8Array(rgbaBuf)

    // 4. 双线性插值缩放到精确 targetW×targetH（不保持比例，拉伸）+ RGB 归一化 → CHW。
    //    注意：desiredSize 是等比缩放，非正方形原图解码尺寸 ≠ 224×224，
    //    必须在此补齐到模型要求的精确尺寸，否则输入张量字节数与模型不匹配。
    const meanR: number = means[0]
    const meanG: number = means[1]
    const meanB: number = means[2]
    const stdR: number = stds[0]
    const stdG: number = stds[1]
    const stdB: number = stds[2]
    const dstW: number = targetW
    const dstH: number = targetH
    const chw: Float32Array = new Float32Array(3 * dstW * dstH)

    const scaleX: number = srcW / dstW
    const scaleY: number = srcH / dstH
    for (let dy: number = 0; dy < dstH; dy++) {
      const sy: number = dy * scaleY
      const y0: number = Math.floor(sy)
      const y1: number = y0 + 1 < srcH ? y0 + 1 : y0
      const wy: number = sy - y0
      const dstRowBase: number = dy * dstW
      for (let dx: number = 0; dx < dstW; dx++) {
        const sx: number = dx * scaleX
        const x0: number = Math.floor(sx)
        const x1: number = x0 + 1 < srcW ? x0 + 1 : x0
        const wx: number = sx - x0
        const i00: number = (y0 * srcW + x0) * 4
        const i01: number = (y0 * srcW + x1) * 4
        const i10: number = (y1 * srcW + x0) * 4
        const i11: number = (y1 * srcW + x1) * 4
        const dstIdx: number = dstRowBase + dx
        // R
        const rTop: number = (src[i00] / 255.0) * (1 - wx) + (src[i01] / 255.0) * wx
        const rBot: number = (src[i10] / 255.0) * (1 - wx) + (src[i11] / 255.0) * wx
        const r: number = rTop * (1 - wy) + rBot * wy
        // G
        const gTop: number = (src[i00 + 1] / 255.0) * (1 - wx) + (src[i01 + 1] / 255.0) * wx
        const gBot: number = (src[i10 + 1] / 255.0) * (1 - wx) + (src[i11 + 1] / 255.0) * wx
        const g: number = gTop * (1 - wy) + gBot * wy
        // B
        const bTop: number = (src[i00 + 2] / 255.0) * (1 - wx) + (src[i01 + 2] / 255.0) * wx
        const bBot: number = (src[i10 + 2] / 255.0) * (1 - wx) + (src[i11 + 2] / 255.0) * wx
        const b: number = bTop * (1 - wy) + bBot * wy
        chw[0 * dstW * dstH + dstIdx] = (r - meanR) / stdR
        chw[1 * dstW * dstH + dstIdx] = (g - meanG) / stdG
        chw[2 * dstW * dstH + dstIdx] = (b - meanB) / stdB
      }
    }

    return chw
  }
}
