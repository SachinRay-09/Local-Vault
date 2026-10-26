# Task 6.7 — System / dark / light theme (implementation spec)

**Audience:** the next implementer. Read this **before** editing widgets.  
**Status:** spec only. Do not treat this file as “already implemented.”  
**Devices to verify on:** Infinix GT Book (Windows, i5-12450H, 16 GB) and iQOO Z9x (Android, Snapdragon 6 Gen 1, 6 GB).

This task is **theme plumbing**, not a redesign. Cryptomator 1.15, Privi, Arcile, and PhotoVault look “correct” in dark mode because they use **paired roles** (surface + onSurface, primary + onPrimary). They do **not** paint every label `Colors.white` in dark and `Colors.black` in light.

If you restyle `home_screen.dart` / `mobile_home_screen.dart` by hand, you **will** ship unreadable text. Those files are 3k / 2k LOC god screens. Leave their layout alone.

---

## 1. What “correct” looks like (how good apps actually do it)

Material 3 (same system Flutter uses) and the vault apps above share one rule:

> Never pick a raw paint for text. Pick a **role**. The role already has a contrasting partner in both light and dark.

| You are painting… | Use this role | Never use |
|-------------------|---------------|-----------|
| Screen / scaffold background | `colorScheme.surface` | `Colors.white`, `Colors.black`, `#121212` |
| Cards, tiles, dialogs | `colorScheme.surfaceContainer` / `surfaceContainerHigh` | `Colors.grey[100]`, `Colors.grey[900]` |
| Primary body text | `colorScheme.onSurface` (or omit color and use `TextTheme`) | `Colors.black`, `Colors.white` |
| Secondary / hint / captions | `colorScheme.onSurfaceVariant` | `Colors.grey`, `Colors.grey[600]` |
| Text on a filled button / FAB | `colorScheme.onPrimary` | `Colors.white` (breaks if primary is light) |
| Text on `primaryContainer` | `colorScheme.onPrimaryContainer` | `Colors.black` |
| Destructive | `colorScheme.error` + `onError` | `Colors.red` on unknown backgrounds |
| Hairlines | `colorScheme.outline` / `outlineVariant` | `Colors.grey` |

`ColorScheme.fromSeed` generates both palettes from **one seed** so indigo `0xFF5B5BD6` stays the brand in light **and** dark, with WCAG-ish contrast built in (`contrastLevel: 0.0` is enough; do not invent a custom palette).

**Flutter’s official pattern** (Material 3 migration + `ColorScheme.fromSeed`):

```dart
const seed = Color(0xFF5B5BD6);

final light = ColorScheme.fromSeed(
  seedColor: seed,
  brightness: Brightness.light,
);
final dark = ColorScheme.fromSeed(
  seedColor: seed,
  brightness: Brightness.dark,
);

MaterialApp(
  theme: ThemeData(useMaterial3: true, colorScheme: light, /* component themes from light */),
  darkTheme: ThemeData(useMaterial3: true, colorScheme: dark, /* same structure, from dark */),
  themeMode: /* system | light | dark from settings */,
);
```

`ThemeMode.system` follows Windows personalization (GT Book) and Android night mode (iQOO / Funtouch / Origin-style dark). That is the default. Do not force dark.

**What those vault apps also do (copy this, not their pixels):**

- **Chrome follows theme; media canvas stays cinema-black.** Image/video viewers sit on `Colors.black` with white overlay chrome **regardless of app theme**. That is correct: the photo is the background. Do **not** theme the viewer scaffold to `colorScheme.surface` — a light viewer around a photo looks broken and causes flash.
- **Elevated dark, not OLED #000**, for lists/settings. M3 dark `surface` is ~tone 6–10, not `#000000`. Pure black kills card edges and makes `outline` invisible. No OLED toggle in 6.7.
- **No extra font package, no dynamic-color, no Material You wallpaper harvest.** Tasks.md forbids new pub dependencies. Seed is enough.
- **Settings is a three-way, not a boolean.** System / Light / Dark. A single “Dark mode” switch fights the OS and is how apps get stuck in the wrong scheme.

---

## 2. Hard constraints (violation = reject the PR)

From `.kiro/specs/local-vault-redesign/tasks.md` Phase 6:

- Do **not** rewrite HomeScreen / MobileHomeScreen.
- Do **not** restyle individual list tiles “for dark mode.”
- Do **not** add `dynamic_color`, Google Fonts, or any theme package.
- Do **not** touch crypto, `JobRunner`, import, export, blob format, or Isolates.
- Do **not** set `scaffoldBackgroundColor: Colors.black` in `darkTheme`.
- Do **not** use `ThemeData.dark().copyWith(...)` mixed with a light `ColorScheme` (classic “black text on dark” bug).
- Do **not** set `themeMode` without also supplying **both** `theme` and `darkTheme`. If `darkTheme` is missing, Flutter falls back to a generic dark theme that will **not** match our seed and will clash with leftover hardcoded greys.

---

## 3. Exact files to touch

| File | Change |
|------|--------|
| `lib/models/app_settings.dart` | Add `String themeMode = 'system';` with a comment listing `system` \| `light` \| `dark`. |
| `lib/models/app_settings.g.dart` | Regenerate: `dart run build_runner build --delete-conflicting-outputs`. |
| `lib/services/settings_service.dart` | `getThemeMode()` / `setThemeMode(String)` (or load/save via existing `getOrCreate` + `saveSettings`). Validate the string; unknown → `'system'`. |
| `lib/app/app.dart` | Dual `ThemeData`; `themeMode` from a `ValueNotifier<ThemeMode>` (or equivalent). Load persisted value in `initState` after first frame. Keep crash-recovery code **byte-for-byte** except dialog text style (see §5). |
| `lib/ui/settings/settings_screen.dart` | Appearance card: `SegmentedButton<ThemeMode>` or three `RadioListTile`s. On change: persist + update the app-level notifier. Do **not** rebuild the whole navigator stack. |
| **Optional tiny helper** `lib/app/vault_theme.dart` | `ColorScheme` + `ThemeData` factories so `app.dart` stays readable. **No** Riverpod. |

**Do not create** a Theme inherited from a new package. A `ValueNotifier<ThemeMode>` held by `VaultApp` (static or passed) is enough.

Isar 3 adds a new field with a Dart default without a manual migration. Existing vaults on GT Book / Z9x keep working; unread `themeMode` becomes `'system'`. Still run `build_runner` or the app will not compile.

If Task 6.9 (`blockScreenshots`) lands in the same week, add **both** Isar fields and run `build_runner` **once**.

---

## 4. `VaultApp` theme construction (copy this structure)

Build **two** `ThemeData` objects with the **same** component overrides, each fed by its own `ColorScheme`. Copy-pasting only `theme:` and forgetting `darkTheme:` is the #1 Flutter bug.

```dart
ThemeData buildVaultTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent, // avoid M3 tint wash on AppBar
    ),
    cardTheme: CardThemeData( // if analyzer wants CardTheme, keep current type
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    dividerColor: scheme.outlineVariant,
    // IconButton / ListTile inherit. Do not set iconTheme to Colors.black.
  );
}
```

`MaterialApp`:

```dart
theme: buildVaultTheme(lightScheme),
darkTheme: buildVaultTheme(darkScheme),
themeMode: _themeMode, // from notifier
```

**Login spinner trap (already in `login_screen.dart`):** a `CircularProgressIndicator()` inside a `FilledButton` uses `colorScheme.primary` on a `primary` fill → invisible in **both** modes. When you touch that file (only if you must), use:

```dart
CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
```

Do not “fix” it by setting the indicator to `Colors.white`.

Map persisted strings:

```dart
ThemeMode parseThemeMode(String raw) {
  switch (raw) {
    case 'light': return ThemeMode.light;
    case 'dark': return ThemeMode.dark;
    default: return ThemeMode.system;
  }
}
```

---

## 5. Hardcoded colors in this repo (inventory)

Most of the tree is already role-based (`Theme.of(context).colorScheme.*`, default `ListTile` / `Text`). That is why 6.7 is small.

### 5.1 Leave as-is (cinema overlays — correct on purpose)

| Location | Why |
|----------|-----|
| `lib/ui/viewers/image_viewer_screen.dart` — `Colors.black` scaffold, white icons | Photo canvas. Independent of app theme. |
| `lib/ui/widgets/optimized_image_viewer.dart` — same | Same. |
| `lib/ui/widgets/context_menu_region.dart` — `Colors.transparent` | Hit target, not paint. |

Video viewer: keep the playback surface dark. Captions that sit **beside** the player (not over pixels) should use `colorScheme.onSurfaceVariant`, not `Colors.grey`.

### 5.2 Must fix or they invert (the actual mess risk)

Replace with roles. **Do not** invert with `isDark ? Colors.white : Colors.black`.

| File | Today | Replace with |
|------|-------|----------------|
| `lib/app/app.dart` ~185 | `TextStyle(..., color: Colors.grey)` on interrupted-job copy | `Theme.of(context).colorScheme.onSurfaceVariant` (cannot be `const`) |
| `lib/ui/home/home_screen.dart` | Several `Colors.grey` captions in progress/status dialogs (~2675, 2680, 2802, 2807, 2925, 3050, 3057) | `onSurfaceVariant` or `textTheme.bodySmall` (no color) |
| `lib/ui/mobile/mobile_home_screen.dart` | Empty-state `Colors.grey` icon/text (~1667, 1673); progress `Colors.grey` (~1954) | `onSurfaceVariant` |
| `lib/ui/viewers/video_viewer_screen.dart` ~131 | `Colors.grey` | `onSurfaceVariant` |
| `lib/services/progressive_loading_service.dart` ~166–189 | `Colors.grey[200/100/400/600]` placeholder boxes | `surfaceContainerHighest` + `onSurfaceVariant` via `Theme.of(context)` if this widget is still on a user-visible path; if unused in production UI, **do not resurrect it** |

### 5.3 Semantic greens / reds / oranges (snackbars, banners)

These are **status**, not body text. They are readable on both themes **if** you do not also hardcode the label color to black/white.

Rules:

- `SnackBar(backgroundColor: Colors.green)` + default `Text` → in M3 the content color comes from `SnackBarTheme` (`onInverseSurface`, usually light). After §4’s `snackBarTheme`, a green bar + light-themed content can clash. Prefer:
  - default `SnackBar` (uses `inverseSurface`), **or**
  - `SnackBar(backgroundColor: colorScheme.primary, content: Text(..., style: TextStyle(color: colorScheme.onPrimary)))`, **or**
  - keep green/red **only** for the icon, not the bar.
- Info banners in `home_screen.dart` that use `Colors.blue.withOpacity(0.1)` + `Colors.blue` icons: opacity washes fail in dark (blue-on-dark-blue). Prefer `colorScheme.primaryContainer` fill + `onPrimaryContainer` icon/text. **Minimal change:** wrap those `BoxDecoration` colors with scheme containers; do not redesign the banner.
- `FilledButton.styleFrom(backgroundColor: Colors.red)` (mobile delete): set `foregroundColor: colorScheme.onError` if you switch to `error`, or leave Material defaults by using `styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)`.

Do **not** walk 3k lines changing every `Colors.green` icon. Icons on `surface` are fine (green/red/amber remain visible). **Text** on `surface` that is `Colors.grey` is the bug.

### 5.4 Forbidden “fixes”

```dart
// WRONG — will look fine in the mode you tested and fail in the other
color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black

// WRONG — grey[600] dies on dark surface; grey[400] dies on light
color: Colors.grey[600]

// WRONG — forces OLED and kills card contrast
darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.black)

// WRONG — ThemeData.dark() primary is teal/purple defaults, not our seed
darkTheme: ThemeData.dark()
```

---

## 6. How widgets should get color (so god screens stay untouched)

Flutter already applies the active `ColorScheme` to:

`Scaffold`, `AppBar`, `Card`, `ListTile`, `AlertDialog`, `TextField`, `FilledButton`, `TextButton`, `Checkbox`, `Radio`, `PopupMenu`, `LinearProgressIndicator`, default `Text` (via `textTheme`).

`OptimizedFolderItem` / `OptimizedFileItem` use `ListTile` + `colorScheme.primaryContainer` — they will flip correctly with **zero** edits.

Grid cells in `home_screen.dart` already use `colorScheme.surface` / `primaryContainer` / `onSurface` via `textTheme.bodySmall`. Leave them.

**Therefore the implementer should spend time on `app.dart` + settings + the grey captions in §5.2, not on layout.**

If a `Text(...)` has **no** `style` color, it is already correct. If it has `const TextStyle(color: Colors.grey)`, it is not.

---

## 7. Settings UI (Appearance)

Place under the grouping Task 6.8 will introduce. If 6.8 is not done yet, add a `Card` titled **Appearance** with:

- Subtitle: “Follow the device theme, or lock light / dark.”
- Control: `SegmentedButton<ThemeMode>` with System, Light, Dark.

On selection:

1. `setState` locally so the control updates.
2. `settings.setThemeMode(...)`.
3. `VaultApp.themeModeNotifier.value = parsed`.

Instant preview: `MaterialApp` rebuilds from the notifier. AuthGate / Home stay mounted. **Do not** `pushAndRemoveUntil` to apply theme.

Default for new and existing installs: **system**. Do not default to dark; the user already lives in light and must not be surprised on first launch after the update. Dark-first vault apps default dark because they never shipped light-only. We did.

---

## 8. Task 6.7 vs the rest of Phase 6 (do not break the pipeline)

| Task | Overlap | Rule |
|------|---------|------|
| **6.1** ZIP isolate + STORE | None | Theme must not import `archive_writer`. Export jitter fix is isolate work; theme is UI isolate paint only. |
| **6.2** Change password UI | Both edit Settings | 6.2 = Security card; 6.7 = Appearance card. Do not nest the password form in Appearance. |
| **6.3** Resume dialog | Both edit `app.dart` | Keep `_checkInterruptedJobs` logic. Only change the grey caption color. Resume vs Discard behavior stays as 6.3 specifies. Merge carefully. |
| **6.4** Rollback-marker dialog | `app.dart` | New dialog must use default `AlertDialog` (scheme-backed). No `Colors.white` body. |
| **6.5** Delete deprecated | `progressive_loading_service` / thermal color helpers | If you still need to recolor placeholders, check 6.5 has not deleted the file. Do not revive deprecated thermal color APIs. |
| **6.6** v0→v1 migrate | Settings | Another Settings row, not a theme concern. |
| **6.8** Progress + Settings chrome | Settings + progress dialogs | 6.8 will add a storage bar + Security/Appearance groups. Put the theme control **inside** Appearance so 6.8 does not duplicate it. Progress dialog greys in §5.2 should become `onSurfaceVariant` so 6.8’s byte bar is readable in dark. |
| **6.9** FLAG_SECURE | `AppSettings` | Second boolean field. Default off. Unrelated to colors. |

**Will 6.7 break import/export/crypto?** No, if you do not call those services. Theme rebuilds are a `MaterialApp` `setState`/`ValueListenableBuilder`. Native AES, Isar writes, and `JobRunner`’s one-file loop are unchanged.

**Performance on these two devices:** switching theme is a one-frame widget rebuild. No extra isolate, no disk besides one Isar `put`. Import of 750 MB stays ~10–15 s (GT Book) / ~20–30 s (Z9x). Do not wrap `JobRunner` in `Consumer` / Riverpod “to observe theme.”

**RAM:** `ThemeData` × 2 is a few KB. Safe on 6 GB Z9x.

---

## 9. Verification checklist (implementer must run)

Contrast (both devices, all three modes: System with OS light, System with OS dark, locked Light, locked Dark):

- [ ] Login: password label, error text, Unlock button label, spinner **on** the button
- [ ] Setup / recovery
- [ ] Home list + grid filenames and byte captions
- [ ] Empty folder state (grey icon today)
- [ ] Search field + results
- [ ] Settings cards, storage numbers, new Appearance control
- [ ] Import progress dialog (desktop + mobile)
- [ ] Export progress dialog (Windows only)
- [ ] Interrupted-job dialog
- [ ] Image viewer still black canvas, white chrome (do not “theme” it)
- [ ] SnackBars readable
- [ ] Context menus / overflow menus

Functional:

- [ ] Import a small folder in dark mode (files land, names readable)
- [ ] Export on GT Book still produces a ZIP that re-imports
- [ ] Unlock / lock still works
- [ ] Theme survives process kill (Isar persist)
- [ ] `flutter analyze` 0 issues
- [ ] Vault health check passes
- [ ] Windows: Settings → Personalization → Colors → Dark/Light while app is open (`ThemeMode.system` should follow without restart)
- [ ] Z9x: system dark mode toggle while app is in foreground or after resume

**Pass criterion:** no text where you have to squint; no white-on-white fields; no black-on-indigo buttons. If in doubt, screenshot and check: body text vs `surface` should look obviously grey-white on dark and grey-black on light.

---

## 10. Suggested implementation order (short)

1. Add `themeMode` on `AppSettings` + `build_runner`.
2. Extract `buildVaultTheme` + dual schemes in `app.dart`; hard-code `themeMode: ThemeMode.system` first. Hot-restart. Flip OS dark. Confirm login + home without Settings.
3. Replace §5.2 greys (small, targeted diffs).
4. Wire Settings + notifier + persist.
5. Device pass on GT Book then Z9x.
6. Stop. Do not “while I’m here” restyle the grid.

---

## 11. Out of scope (do not do in 6.7)

- OLED pure-black toggle
- Per-folder colors, manga reader theme, system Material You
- Filename encryption, Riverpod, parallel import workers
- Changing `Card` radii, navigation, typography scale
- `ResizeImage` / viewer flash
- Defaulting existing users to dark
