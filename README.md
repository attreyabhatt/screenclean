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

## Ads Configuration

**Test ads are enabled by default.** Just run `flutter run` and you'll see test ads.

### For Production Builds

When you're ready to deploy with your production AdMob ID:

1. Edit `dart_defines.json` with your production AdMob ID:
   ```json
   {
     "ENABLE_ADS": "true",
     "ADMOB_BANNER_UNIT_ID": "your-production-admob-id"
   }
   ```

2. Build with production configuration:
   ```bash
   flutter build apk --release --dart-define-from-file=dart_defines.json
   ```

### To Disable Ads

```bash
flutter run --dart-define=ENABLE_ADS=false
```

### Manual Configuration

You can also override settings via command line:
```bash
flutter run --dart-define=ENABLE_ADS=true --dart-define=ADMOB_BANNER_UNIT_ID=<your_id>
```

**Test Ad Unit ID:** `ca-app-pub-3940256099942544/9214589741` (default)

AdMob app ID is provided to Android via `ADMOB_APP_ID` Gradle property / manifest placeholder.

## Test

```bash
flutter analyze
flutter test
```
