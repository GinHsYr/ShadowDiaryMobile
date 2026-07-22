<h1 align="center">Shadow Diary</h1>
<h6 align="center">影迹</h6>

<p align="center">
  <img src="resources/icon.png" width="120" alt="Shadow Diary Logo" />
</p>

<p align="center">
  A local-first, privacy-focused diary app built with Flutter.<br/>
  Looking for the desktop version? <a href="https://github.com/GinHsYr/ShadowDiary">ShadowDiary Desktop</a>
</p>

---

## Features

### Diary
- **Rich Text Editing** — Quill-based editor with bold, italic, underline, strikethrough, alignment, blockquote, and more
- **Calendar View** — Monthly calendar with entry indicators, swipe between months
- **Quick Jump** — One-tap navigation to today, yesterday, same day last week, or same day last month
- **Mood & Weather** — Record daily mood (happy/excited/calm/tired/sad) and weather
- **Image Embedding** — Insert images from gallery, auto-converted to WebP, up to 20 per entry
- **Auto-save** — 700ms debounced auto-save, also triggers on app backgrounding
- **Full-text Search** — FTS5-powered full-text search across all diary entries

### Archives
- **People & Others** — Keep records of important people or things with name, aliases, description, avatar, and photo gallery
- **Pinyin Sorting** — Chinese archives grouped by pinyin initial (A-Z) with a side alphabet rail for quick navigation
- **Mention Stats** — Automatically counts how many times an archive is mentioned in diaries

### Media
- **Masonry Gallery** — Browse all images from diaries and archives in a unified view
- **Filter Chips** — Filter by All / Diaries / Archives with item counts
- **Full-screen Viewer** — Pinch-to-zoom and swipe between images
- **Source Linking** — View which diary or archive an image belongs to, jump to source in one tap

### Statistics
- Total diary count, current writing streak, total character count
- Monthly writing progress bar with percentage

### Appearance
- **Theme Mode** — System / Light / Dark
- **Five Color Seeds** — Neutral Black, Indigo, Teal, Rose, plus Monet dynamic color (Android 12+)
- **Material 3** — Full Material Design 3 throughout
- **Multi-language** — System / 简体中文 / English

### Security
- **App Lock** — Biometric authentication (fingerprint/face/iris) and device credential fallback (PIN/pattern/password)
- **Auto-lock** — Automatically locks the app when backgrounded

### Data
- **Backup Import** — Import ZIP backups from the desktop app with a full preview panel
- **Two Import Modes** — Overwrite (full replacement) / Incremental (only import missing dates)
- **Encrypted Storage** — SQLCipher-encrypted backup database with SHA-512 HMAC

---

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.x / Dart 3.12+ |
| State Management | flutter_riverpod |
| Routing | go_router |
| Database | SQLite + FTS5 (bundled sqlite3mc) |
| Rich Text | flutter_quill |
| Theming | dynamic_color (Monet) |
| Security | local_auth (Biometric) |
| i18n | intl / ARB |

---

## Development

**Requirements**: Flutter ≥ 3.44.6, Dart ≥ 3.12.2, Android SDK, JDK 17.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

**Android applicationId**: `com.shadowdiary.hsyr`

---

## Project Structure

```
lib/
  main.dart                  # Entry point: initializes database, launches app
  app/
    app.dart                 # MaterialApp.router configuration
    router.dart              # GoRouter route definitions
    shell.dart               # Frosted-glass bottom navigation bar
  core/
    archives/                # Archive model, repository, pinyin sorting
    backup/                  # ZIP backup import service
    database/                # SQLite schema, FTS5, triggers
    diary/                   # Diary model, statistics, repository
    media/                   # Media library aggregation
    security/                # App lock controller and gate widget
    services/                # Image services, LAN service contracts
    settings/                # Settings model and controller
    theme/                   # Theme definitions (light/dark/color schemes)
    widgets/                 # Shared widgets
  features/
    archives/                # Archive list, editor, image viewer
    editor/                  # Rich-text diary editor
    home/                    # Home page (calendar, stats cards)
    media/                   # Media gallery and image viewer
    settings/                # Settings page
  l10n/                      # Localization files (zh/en)
```

---

## License

MIT
