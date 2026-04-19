/**
 * 主题管理器 - 统一管理应用主题切换
 * 使用AppStorage进行跨页面状态管理
 */

// AppStorage is globally available in ArkTS

export class ThemeManager {
  private static readonly THEME_KEY: string = 'currentThemeMode'
  private static themeChangeCallbacks: Array<(theme: string) => void> = []

  /**
   * 获取当前主题
   */
  static getCurrentTheme(): string {
    return AppStorage.get<string>(ThemeManager.THEME_KEY) || 'light'
  }

  /**
   * 设置主题
   */
  static setTheme(theme: string): void {
    AppStorage.setOrCreate<string>(ThemeManager.THEME_KEY, theme)
    ThemeManager.notifyThemeChange(theme)
  }

  /**
   * 切换主题（亮色/暗色）
   */
  static toggleTheme(): string {
    const currentTheme = ThemeManager.getCurrentTheme()
    const newTheme = currentTheme === 'light' ? 'dark' : 'light'
    ThemeManager.setTheme(newTheme)
    return newTheme
  }

  /**
   * 订阅主题变化
   */
  static subscribeThemeChange(callback: (theme: string) => void): void {
    ThemeManager.themeChangeCallbacks.push(callback)
  }

  /**
   * 取消订阅主题变化
   */
  static unsubscribeThemeChange(callback?: (theme: string) => void): void {
    if (callback) {
      const index = ThemeManager.themeChangeCallbacks.indexOf(callback)
      if (index > -1) {
        ThemeManager.themeChangeCallbacks.splice(index, 1)
      }
    } else {
      ThemeManager.themeChangeCallbacks = []
    }
  }

  /**
   * 通知主题变化
   */
  private static notifyThemeChange(theme: string): void {
    ThemeManager.themeChangeCallbacks.forEach(callback => {
      try {
        callback(theme)
      } catch (error) {
        console.error('Theme change callback error:', error)
      }
    })
  }
}