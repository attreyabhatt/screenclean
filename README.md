# ScreenClean - Screenshot Cleaner & Storage Saver

Tagline: **Reclaim your space in seconds.**

## MVP Features

- Scans screenshot folders and shows total screenshot count + storage usage.
- Identifies old screenshots (older than 30 days) and exact duplicates.
- Lets users bulk-select screenshots and delete them in one action.
- Shows reclaimed storage after successful cleanup.
- Prompts for app rating only after meaningful cleanups.

## Tech Stack

- Flutter + Dart
- `flutter_riverpod` for state management
- `photo_manager` for media access/deletion
- `crypto` for exact hash duplicate detection
- `shared_preferences` + `in_app_review` for rating prompt policy
- `google_mobile_ads` for future banner ad support (feature-gated)

## Run

```bash
flutter pub get
flutter run
```

## Ads (Production Hook)

Ads are disabled by default. Enable in production with:

```bash
flutter run --dart-define=ENABLE_ADS=true --dart-define=ADMOB_BANNER_UNIT_ID=<your_banner_unit_id>
```

AdMob app ID is provided to Android via `ADMOB_APP_ID` Gradle property / manifest placeholder.

## Test

```bash
flutter analyze
flutter test
```
