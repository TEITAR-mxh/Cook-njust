export interface ShoppingListResult {
  missingItems: string[]
  matchedItems: string[]
}

export class ShoppingListService {
  private static normalize(value: string): string {
    return value.trim().replace(/\s+/g, '').toLowerCase()
  }

  private static isMatched(required: string, selected: string[]): boolean {
    const requiredNormalized = ShoppingListService.normalize(required)
    for (let i = 0; i < selected.length; i++) {
      const selectedNormalized = ShoppingListService.normalize(selected[i])
      if (selectedNormalized.length === 0) {
        continue
      }
      if (selectedNormalized === requiredNormalized) {
        return true
      }
      if (requiredNormalized.includes(selectedNormalized) || selectedNormalized.includes(requiredNormalized)) {
        return true
      }
    }
    return false
  }

  static diff(selectedStuff: string[], recipeStuff: string[]): ShoppingListResult {
    const missingItems: string[] = []
    const matchedItems: string[] = []

    for (let i = 0; i < recipeStuff.length; i++) {
      const item = recipeStuff[i]
      if (ShoppingListService.isMatched(item, selectedStuff)) {
        matchedItems.push(item)
      } else {
        missingItems.push(item)
      }
    }

    return {
      missingItems,
      matchedItems
    }
  }

  static toClipboardText(recipeName: string, missingItems: string[], matchedItems: string[] = []): string {
    const lines: string[] = []
    lines.push(`购物清单 - ${recipeName}`)
    lines.push('------------------------')
    for (let i = 0; i < missingItems.length; i++) {
      lines.push(`- ${missingItems[i]}`)
    }
    if (matchedItems.length > 0) {
      lines.push('')
      lines.push(`已有食材: ${matchedItems.join(', ')}`)
    }
    return lines.join('\n')
  }
}