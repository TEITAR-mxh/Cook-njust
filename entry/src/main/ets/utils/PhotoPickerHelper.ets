/**
 * 系统照片选择器封装
 * 使用 photoAccessHelper.PhotoViewPicker，不申请 READ_IMAGEVIDEO 权限。
 * 符合《华为应用审核指南》第 7.17 项的 Photo Picker 替代方案要求。
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit'

export class PhotoPickerHelper {
  /**
   * 打开系统图片选择器，让用户选一张照片。
   * @returns 选中照片的 URI，用户取消则返回 null
   */
  static async selectSinglePhoto(): Promise<string | null> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
      })
      if (result && result.photoUris.length > 0) {
        return result.photoUris[0]
      }
      return null
    } catch (e) {
      console.error('[PhotoPickerHelper] 图片选择失败:', JSON.stringify(e))
      return null
    }
  }
}
