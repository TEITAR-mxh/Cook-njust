/**
 * Global design tokens for API 22 ArkUI pages.
 * Keep this file as the single source of truth for color, radius, spacing and shadow.
 */

export interface TagTone {
  bg: string
  border: string
  text: string
}

export class DSColor {
  static readonly BRAND_PRIMARY: string = '#FC4C52'
  static readonly BRAND_ACCENT: string = '#FF7A59'
  static readonly BG_CANVAS: string = '#F4F6FB'
  static readonly BG_ELEVATED: string = '#FFFFFF'
  static readonly BG_SOFT: string = '#EEF1F7'
  static readonly SHEET_BG: string = '#F8FAFF'
  static readonly TEXT_PRIMARY: string = '#141A2A'
  static readonly TEXT_SECONDARY: string = '#4C556B'
  static readonly TEXT_TERTIARY: string = '#7E879B'
  static readonly STROKE_SOFT: string = '#DDE3EF'
  static readonly STROKE_STRONG: string = '#C6CFDE'
  static readonly MASK: string = '#66101522'
}

export class DSRadius {
  static readonly XS: number = 8
  static readonly SM: number = 12
  static readonly MD: number = 16
  static readonly LG: number = 22
  static readonly XL: number = 28
  static readonly PILL: number = 999
}

export class DSSpace {
  static readonly XS: number = 6
  static readonly SM: number = 10
  static readonly MD: number = 14
  static readonly LG: number = 20
  static readonly XL: number = 28
}

export class DSType {
  static readonly HERO: number = 26
  static readonly TITLE: number = 18
  static readonly BODY: number = 14
  static readonly CAPTION: number = 12
}

export class DSShadow {
  static readonly CARD: ShadowOptions = {
    radius: 16,
    color: '#140F172A',
    offsetX: 0,
    offsetY: 6
  }

  static readonly INSET_SOFT: ShadowOptions = {
    radius: 8,
    color: '#14FFFFFF',
    offsetX: -2,
    offsetY: -2
  }

  static readonly FLOATING_SHEET: ShadowOptions = {
    radius: 28,
    color: '#1F0B1220',
    offsetX: 0,
    offsetY: -10
  }
}

export class DSSheet {
  static readonly DETENTS: [SheetSize, SheetSize] = [SheetSize.MEDIUM, SheetSize.LARGE]
  static readonly SCROLL_FRICTION: number = 0.78
  static readonly EDGE_EFFECT: number = 8
  // 弹簧速度：值越大，吸附回弹速度越快，推荐范围 1.5–3.5
  static readonly SPRING_VELOCITY: number = 2.0
}

const TAG_TONES: TagTone[] = [
  { bg: '#EDF5FF', border: '#D4E4FF', text: '#2F5FB6' },
  { bg: '#EFFFF5', border: '#D6F5E3', text: '#207A49' },
  { bg: '#FFF3EC', border: '#FFDCCF', text: '#B5542C' },
  { bg: '#F5F0FF', border: '#E4D9FF', text: '#6A44B8' },
  { bg: '#FFF9E8', border: '#F9E7B7', text: '#8E6A0D' }
]

export function pickTagTone(index: number): TagTone {
  return TAG_TONES[index % TAG_TONES.length]
}
