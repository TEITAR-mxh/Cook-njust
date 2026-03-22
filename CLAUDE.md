# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **HarmonyOS (NEXT) recipe application** built with ArkTS that helps users discover and cook recipes. The app features:
- Recipe search by ingredients and cooking tools (with multiple search modes: strict, loose, survival)
- Recipe library browsing
- Random recipe discovery
- Favorites and browsing history
- Video links to cooking tutorials (Bilibili and external links)

The app uses a custom recipe data format stored in `entry/src/main/resources/rawfile/recipe.json` with array indices serving as stable recipe IDs (matching the Web version's Dexie approach).

## Development Commands

### Building
```bash
# Build the project using Node.js-based Hvigor
node ./hvigor/hvigor-wrapper.js --mode module -p module=entry@default -p product=default assembleHap

# Or use the standard Hvigor command if available in DevEco Studio
hvigorw assembleHap
```

### Testing
```bash
# Run unit tests (LocalUnit.test.ets)
node ./hvigor/hvigor-wrapper.js --mode module -p module=entry@default test

# Run instrumented tests (ohosTest directory)
# Note: Requires DevEco Studio or HDC for device deployment
```

### Linting
The project uses code-linter.json5 configuration with:
- Performance and TypeScript ESLint rules
- Security rules for cryptographic operations
- Lints all `**/*.ets` files (excluding test/mock/build directories)

Run linting through DevEco Studio's built-in linter or CLI tools.

## Architecture

### Core Singleton Pattern
**RecipeRepository** (entry/src/main/ets/data/RecipeRepository.ets:55) - Singleton that loads recipe.json from rawfile resources. Recipes are indexed by array position to provide stable IDs for favorites/history.

**CookPreferences** (entry/src/main/ets/store/CookPreferences.ets:32) - Singleton managing HarmonyOS Preferences storage with concurrent-safe lazy initialization. Handles:
- User settings (keepLocalData toggle)
- Selected ingredients and cooking tools
- Search mode persistence
- Favorites (max 500 items, newest first)
- Browsing history (max 50 items, newest first)

### Service Layer (Pure Functions)
**RecipeSearchService** (entry/src/main/ets/service/RecipeSearchService.ets:7) - Pure search algorithms matching Web version:
- `strict`: All selected ingredients + tool must be present
- `loose`: Any selected ingredient + tool (if specified) must be present
- `survival`: Recipe uses ONLY the selected ingredients (survival mode logic)

**RecipeVideoLauncher** (entry/src/main/ets/service/RecipeVideoLauncher.ets:14) - Handles opening external video links (Bilibili BV codes or direct URLs). Falls back to clipboard copy with toast if no browser available.

### UI Structure
**Index.ets** (entry/src/main/ets/pages/Index.ets:13) - Main tab-based navigation with 4 tabs:
1. **做菜 (Cook)**: Ingredient/tool selection with search mode toggle
2. **菜谱 (Library)**: Full recipe browsing with name search
3. **发现 (Discover)**: Random recipe picker (only recipes with video links)
4. **我的 (My)**: Settings, favorites, and history navigation

**FavoritesPage.ets** and **HistoryPage.ets** - Secondary pages for viewing stored recipes.

### Data Flow Pattern
1. **Bootstrap** (Index.ets:57): Load RecipeRepository → Load CookPreferences → Initialize state → Run initial searches
2. **State Updates**: User interactions update `@State` variables → Trigger `runSearch()` → Optionally persist via `persistCookIfNeeded()`
3. **Page Lifecycle**: `onPageShow()` refreshes favorites/history from Preferences to sync across navigation

### Important Implementation Details

**ArkUI @State Deep Copy Requirement** (Index.ets:189): When assigning objects to `@State` variables, use deep clones to ensure ArkUI's reactivity system detects changes. The discover tab uses `cloneRecipeForDiscoverState()` because direct assignment from repository doesn't trigger UI updates.

**UTF-8 Manual Decoding** (RecipeRepository.ets:16): Uses custom `utf8BytesToString()` instead of TextDecoder to avoid HarmonyOS SDK API inconsistencies across versions.

**Immersive UI** (EntryAbility.ets:40): Uses `setWindowLayoutFullScreen(true)` with transparent navigation bar to create seamless bottom tab bar integration with system gesture area.

**Status Bar Inset Handling** (StatusBarInset.ets): Dynamically calculates safe area top padding using window safe area APIs to handle notches/status bars.

**Preferences Lazy Loading** (CookPreferences.ets:38): Thread-safe singleton pattern with promise-based concurrent initialization prevention.

## Testing Notes

- Unit tests in `entry/src/test/` use local test framework
- Instrumented tests in `entry/src/ohosTest/` require device/emulator
- Mock configuration available in `entry/src/mock/mock-config.json5`

## File Organization

```
entry/src/main/ets/
├── data/           # Data layer (RecipeRepository, foodCatalog)
├── model/          # TypeScript types (RecipeItem, SearchMode, etc.)
├── pages/          # UI pages (Index, HistoryPage, FavoritesPage)
├── service/        # Business logic services (RecipeSearchService, RecipeVideoLauncher)
├── store/          # Persistence layer (CookPreferences)
├── util/           # Utilities (StatusBarInset)
├── entryability/   # App lifecycle (EntryAbility)
└── entrybackupability/ # Backup extension
```

## Key Compatibility Notes

- Target SDK: HarmonyOS 6.0.2(22) (NEXT)
- Language: ArkTS (TypeScript subset for HarmonyOS)
- Build tool: Hvigor (Huawei's Gradle-like system)
- Device types: Phone only (module.json5:8)
- Main entry: EntryAbility with Index page as launch target

## Data Model Alignment

This app maintains parity with a Web version:
- Recipe IDs are array indices (not UUIDs)
- Search modes match Web `useRecipeStore` implementation
- Preferences keys align semantically (though storage mechanism differs)
- Recipe JSON format is shared between platforms
