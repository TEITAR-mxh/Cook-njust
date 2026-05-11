
/**
 * 品牌色定义 - 支持明暗模式
 */
export class AppColors {
  // 品牌色
  static readonly BRAND_COLOR: string = '#FF4757'
  static readonly BRAND_COLOR_LIGHT: string = '#FFE4E6'
  static readonly BRAND_GRADIENT_START: string = '#FF6B6B'
  static readonly BRAND_GRADIENT_END: string = '#FF4757'
  static readonly FAVORITE_ACTIVE: string = '#FF6B6B'

  // 背景色
  static readonly BG_COLOR: string = '#F4F5F7'
  static readonly CARD_BG: string = '#FFFFFF'
  static readonly TABLE_BG: string = '#FDFBF7' // 餐桌专属色调

  // 灰度色系
  static readonly GRAY_50: string = '#F9FAFB'
  static readonly GRAY_100: string = '#F3F4F6'
  static readonly GRAY_200: string = '#E5E7EB'
  static readonly GRAY_300: string = '#D1D5DB'
  static readonly GRAY_400: string = '#9CA3AF'
  static readonly GRAY_500: string = '#6B7280'
  static readonly GRAY_600: string = '#4B5563'
  static readonly GRAY_800: string = '#1F2937'
  static readonly GRAY_900: string = '#111827'

  // 语义色 - 食材标签
  static readonly MEAT_BG: string = '#FEF2F2'
  static readonly MEAT_BORDER: string = '#FCA5A5'
  static readonly MEAT_TEXT: string = '#DC2626'

  static readonly VEG_BG: string = '#F0FDF4'
  static readonly VEG_BORDER: string = '#86EFAC'
  static readonly VEG_TEXT: string = '#16A34A'

  static readonly CARB_BG: string = '#FFFBEB'
  static readonly CARB_BORDER: string = '#FDE047'
  static readonly CARB_TEXT: string = '#D97706'

  static readonly TOOL_BG: string = '#EFF6FF'
  static readonly TOOL_BORDER: string = '#93C5FD'
  static readonly TOOL_TEXT: string = '#2563EB'

  // Bilibili 品牌色
  static readonly BILI_PINK: string = '#FB7299'

  // 餐桌木纹底纹色
  static readonly TABLE_DOT: string = '#E5E0D8'

  // ====== 深色主题颜色 ======
  // 深色背景色
  static readonly DARK_BG_COLOR: string = '#121212'
  static readonly DARK_CARD_BG: string = '#1E1E1E'
  static readonly DARK_TABLE_BG: string = '#1A1A1A'

  // 深色灰度色系
  static readonly DARK_GRAY_50: string = '#252525'
  static readonly DARK_GRAY_100: string = '#2D2D2D'
  static readonly DARK_GRAY_200: string = '#3D3D3D'
  static readonly DARK_GRAY_300: string = '#4D4D4D'
  static readonly DARK_GRAY_400: string = '#6D6D6D'
  static readonly DARK_GRAY_500: string = '#8D8D8D'
  static readonly DARK_GRAY_600: string = '#ADADAD'
  static readonly DARK_GRAY_800: string = '#CDCDCD'
  static readonly DARK_GRAY_900: string = '#EDEDED'

  // 深色语义色
  static readonly DARK_MEAT_BG: string = '#2A1A1A'
  static readonly DARK_MEAT_BORDER: string = '#5A2A2A'
  static readonly DARK_MEAT_TEXT: string = '#FF6B6B'

  static readonly DARK_VEG_BG: string = '#1A2A1A'
  static readonly DARK_VEG_BORDER: string = '#2A5A2A'
  static readonly DARK_VEG_TEXT: string = '#4ADE80'  // 柔和绿，替代高饱和 #6BFF6B

  static readonly DARK_CARB_BG: string = '#2A2A1A'
  static readonly DARK_CARB_BORDER: string = '#5A5A2A'
  static readonly DARK_CARB_TEXT: string = '#FBBF24'  // 琥珀色，替代纯黄 #FFFF6B

  static readonly DARK_TOOL_BG: string = '#1A1A2A'
  static readonly DARK_TOOL_BORDER: string = '#2A2A5A'
  static readonly DARK_TOOL_TEXT: string = '#60A5FA'  // 柔和蓝，替代高饱和 #6B6BFF

  static readonly DARK_TABLE_DOT: string = '#2A2A2A'
}

/**
 * 主题管理器 - 提供明暗主题的颜色获取
 *
 * 数据流：
 *   EntryAbility.onConfigurationUpdate → AppStorage('isSystemDarkMode')
 *   SettingsPage.changeThemeMode      → AppStorage('currentThemeMode')
 *   ThemeManager.getColor             → 读取 AppStorage 解析系统默认模式
 */
export class ThemeManager {
  /**
   * 根据主题模式返回对应颜色。
   * '系统默认' 时从 AppStorage 读取 EntryAbility 写入的系统深色状态，
   * 无需权限，零延迟，跟随系统实时切换。
   */
  static getColor(lightColor: string, darkColor: string, themeMode: string): string {
    if (themeMode === '深色模式') {
      return darkColor;
    }
    if (themeMode === '浅色模式') {
      return lightColor;
    }
    // '系统默认'：读取 EntryAbility.onConfigurationUpdate 写入的系统深色状态
    const isDark: boolean = AppStorage.get<boolean>('isSystemDarkMode') ?? false;
    return isDark ? darkColor : lightColor;
  }

  // 获取背景色
  static getBackgroundColor(themeMode: string): string {
    return ThemeManager.getColor(AppColors.BG_COLOR, AppColors.DARK_BG_COLOR, themeMode)
  }

  // 获取卡片背景色
  static getCardBackgroundColor(themeMode: string): string {
    return ThemeManager.getColor(AppColors.CARD_BG, AppColors.DARK_CARD_BG, themeMode)
  }

  // 获取文本颜色
  static getTextColor(themeMode: string): string {
    return ThemeManager.getColor(AppColors.GRAY_900, AppColors.DARK_GRAY_900, themeMode)
  }

  // 获取次要文本颜色
  static getSecondaryTextColor(themeMode: string): string {
    return ThemeManager.getColor(AppColors.GRAY_500, AppColors.DARK_GRAY_500, themeMode)
  }

  // 获取边框颜色
  static getBorderColor(themeMode: string): string {
    return ThemeManager.getColor(AppColors.GRAY_100, AppColors.DARK_GRAY_100, themeMode)
  }
}
