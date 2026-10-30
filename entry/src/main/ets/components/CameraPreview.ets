/**
 * 应用内相机实时取景组件
 * 封装 XComponent（SURFACE）+ Camera Kit 会话：实时预览、拍照抓帧、存沙箱。
 * 对外通过 CameraPreviewController 暴露 takePhoto / switchCamera / setFlashMode。
 *
 * 拍照产物保存到应用沙箱 filesDir（不进系统相册），返回 `file://` URI，
 * 供识别链路（ImagePreprocessor / CloudFoodAnalyzer 的 fileIo.open）直接读取。
 */
import { camera } from '@kit.CameraKit'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'

/** 父组件调用本组件方法的控制器（仿 XComponentController 模式） */
export class CameraPreviewController {
  takePhoto: () => Promise<string | null> = async () => null
  switchCamera: () => void = () => {}
  setFlashMode: (mode: camera.FlashMode) => void = () => {}
}

@Component
export struct CameraPreview {
  /** 控制器：父组件通过它触发拍照 / 翻转 / 闪光 */
  controller: CameraPreviewController = new CameraPreviewController()
  /** 拍照成功回调（返回沙箱 file:// URI） */
  onPhotoCaptured: (uri: string) => void = () => {}
  /** 相机初始化/运行错误回调 */
  onCameraError: (msg: string) => void = () => {}
  /**
   * 预览画面宽高比回调（竖屏显示下的 width / height）。
   * 宿主需据此设置 XComponent 的比例：SURFACE 不接受 objectFit，
   * 若表面比例与预览缓冲不一致，相机会被直接拉伸导致画面变形。
   */
  onPreviewAspect: (aspect: number) => void = () => {}

  private xcController: XComponentController = new XComponentController()
  private surfaceId: string = ''

  private cameraManager: camera.CameraManager | null = null
  private cameraList: camera.CameraDevice[] = []
  private cameraIndex: number = -1
  private cameraInput: camera.CameraInput | null = null
  private previewOutput: camera.PreviewOutput | null = null
  private photoOutput: camera.PhotoOutput | null = null
  private session: camera.PhotoSession | null = null
  private flashMode: camera.FlashMode = camera.FlashMode.FLASH_MODE_CLOSE
  private inited: boolean = false
  private releasing: boolean = false
  /** 等待中的拍照 Promise resolve */
  private pendingCapture: ((uri: string | null) => void) | null = null

  aboutToAppear(): void {
    this.controller.takePhoto = (): Promise<string | null> => this.capturePhoto()
    this.controller.switchCamera = (): void => { void this.switchCameraInternal() }
    this.controller.setFlashMode = (m: camera.FlashMode): void => { this.setFlashInternal(m) }
  }

  aboutToDisappear(): void {
    void this.releaseCamera()
  }

  // ── 相机初始化 ─────────────────────────────────────────────────────────

  private onSurfaceReady(): void {
    this.surfaceId = this.xcController.getXComponentSurfaceId()
    void this.initCamera()
  }

  private async initCamera(): Promise<void> {
    if (this.inited || this.surfaceId.length === 0) return
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
      if (!ctx) { this.onCameraError('无法获取应用上下文'); return }

      this.cameraManager = camera.getCameraManager(ctx)
      this.cameraList = this.cameraManager.getSupportedCameras()
      if (this.cameraList.length === 0) { this.onCameraError('未检测到可用摄像头'); return }

      this.cameraIndex = this.cameraList.findIndex(
        (d: camera.CameraDevice) => d.cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK)
      if (this.cameraIndex < 0) this.cameraIndex = 0

      await this.startSession()
      this.inited = true
    } catch (e) {
      console.error('[CameraPreview] init error:', JSON.stringify(e))
      this.onCameraError('相机启动失败，请检查权限或稍后重试')
    }
  }

  private async startSession(): Promise<void> {
    if (this.cameraManager === null || this.cameraIndex < 0) return
    const device: camera.CameraDevice = this.cameraList[this.cameraIndex]
    const cap = this.cameraManager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO)
    if (cap.previewProfiles.length === 0 || cap.photoProfiles.length === 0) {
      throw new Error('相机能力不支持预览/拍照')
    }

    this.cameraInput = this.cameraManager.createCameraInput(device)
    await this.cameraInput.open()

    const previewProfile: camera.Profile = this.pickPreviewProfile(cap.previewProfiles)
    this.previewOutput = this.cameraManager.createPreviewOutput(previewProfile, this.surfaceId)
    // 上报竖屏显示比例，供宿主设置 XComponent 比例，避免缓冲被拉伸变形
    const pw: number = previewProfile.size.width
    const ph: number = previewProfile.size.height
    this.onPreviewAspect(Math.min(pw, ph) / Math.max(pw, ph))
    this.photoOutput = this.cameraManager.createPhotoOutput(cap.photoProfiles[0])
    this.photoOutput.on('photoAvailable', (err: Error, photo: camera.Photo) => {
      void this.onPhotoAvailable(err, photo)
    })

    this.session = this.cameraManager.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession
    this.session.beginConfig()
    this.session.addInput(this.cameraInput)
    this.session.addOutput(this.previewOutput)
    this.session.addOutput(this.photoOutput)
    await this.session.commitConfig()
    await this.session.start()
    // 启动后应用闪光模式（PhotoSession 继承 Flash 接口）
    this.session.setFlashMode(this.flashMode)
  }

  /**
   * 选择预览分辨率：优先竖屏宽高比最接近 3:4 的档位（构图稳定、裁切可控），
   * 比例并列时取像素面积最大者。避免把 16:9 缓冲硬塞进 3:4 表面造成拉伸。
   */
  private pickPreviewProfile(profiles: camera.Profile[]): camera.Profile {
    let best: camera.Profile = profiles[0]
    let bestDiff: number = Number.MAX_VALUE
    let bestArea: number = 0
    for (const p of profiles) {
      const w: number = p.size.width
      const h: number = p.size.height
      if (w <= 0 || h <= 0) {
        continue
      }
      const aspect: number = Math.min(w, h) / Math.max(w, h)
      const diff: number = Math.abs(aspect - 3 / 4)
      const area: number = w * h
      if (diff < bestDiff - 1e-6 || (Math.abs(diff - bestDiff) <= 1e-6 && area > bestArea)) {
        best = p
        bestDiff = diff
        bestArea = area
      }
    }
    return best
  }

  // ── 拍照 ─────────────────────────────────────────────────────────────

  private async capturePhoto(): Promise<string | null> {
    if (this.photoOutput === null || this.session === null) return null
    return new Promise<string | null>((resolve: (uri: string | null) => void) => {
      this.pendingCapture = resolve
      const settings: camera.PhotoCaptureSetting = {
        quality: camera.QualityLevel.QUALITY_LEVEL_MEDIUM,
        rotation: camera.ImageRotation.ROTATION_0,
      }
      this.photoOutput!.capture(settings).catch(() => {
        if (this.pendingCapture !== null) {
          this.pendingCapture = null
          resolve(null)
        }
      })
    })
  }

  private async onPhotoAvailable(err: Error, photo: camera.Photo): Promise<void> {
    if (this.pendingCapture === null) return
    const resolve = this.pendingCapture
    this.pendingCapture = null
    if (err !== undefined && err !== null) {
      resolve(null)
      return
    }
    try {
      const img: image.Image = photo.main
      const comp = await img.getComponent(image.ComponentType.JPEG)
      const uri = await this.saveToSandbox(comp.byteBuffer)
      resolve(uri)
    } catch (e) {
      console.error('[CameraPreview] capture save error:', JSON.stringify(e))
      resolve(null)
    } finally {
      try { await photo.release() } catch (_e) { /* ignore */ }
    }
  }

  private async saveToSandbox(buf: ArrayBuffer): Promise<string> {
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined
    if (!host) throw new Error('无应用上下文')
    const targetPath = `${host.filesDir}/scan_${Date.now()}.jpg`
    const f = await fileIo.open(targetPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
    try {
      await fileIo.write(f.fd, buf)
    } finally {
      await fileIo.close(f.fd)
    }
    // Image() 加载本地沙箱文件必须使用 file:// 前缀（裸绝对路径不支持）
    return `file://${targetPath}`
  }

  // ── 翻转 / 闪光 ───────────────────────────────────────────────────────

  private async switchCameraInternal(): Promise<void> {
    if (this.cameraList.length < 2 || this.cameraManager === null) return
    try {
      await this.teardownSession()
      this.cameraIndex = (this.cameraIndex + 1) % this.cameraList.length
      await this.startSession()
    } catch (e) {
      console.error('[CameraPreview] switch error:', JSON.stringify(e))
      this.onCameraError('切换摄像头失败')
    }
  }

  private setFlashInternal(mode: camera.FlashMode): void {
    this.flashMode = mode
    if (this.session !== null && this.inited) {
      try { this.session.setFlashMode(mode) } catch (e) { /* ignore */ }
    }
  }

  // ── 释放 ─────────────────────────────────────────────────────────────

  private async teardownSession(): Promise<void> {
    if (this.session !== null) {
      try { await this.session.stop() } catch (_e) { /* ignore */ }
    }
    if (this.previewOutput !== null) {
      try { await this.previewOutput.release() } catch (_e) { /* ignore */ }
      this.previewOutput = null
    }
    if (this.photoOutput !== null) {
      try { await this.photoOutput.release() } catch (_e) { /* ignore */ }
      this.photoOutput = null
    }
    if (this.cameraInput !== null) {
      try { await this.cameraInput.close() } catch (_e) { /* ignore */ }
      this.cameraInput = null
    }
    if (this.session !== null) {
      try { await this.session.release() } catch (_e) { /* ignore */ }
      this.session = null
    }
  }

  private async releaseCamera(): Promise<void> {
    if (this.releasing) return
    this.releasing = true
    try {
      await this.teardownSession()
      this.inited = false
    } finally {
      this.releasing = false
    }
  }

  // ── build ─────────────────────────────────────────────────────────────

  build() {
    XComponent({
      id: 'cameraPreviewSurface',
      type: XComponentType.SURFACE,
      controller: this.xcController,
    })
      .onLoad(() => { this.onSurfaceReady() })
      .onDestroy(() => { void this.releaseCamera() })
      .width('100%')
      .height('100%')
  }
}
