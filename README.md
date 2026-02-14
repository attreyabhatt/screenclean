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

Ads are disabled by default. To enable ads:

### Option 1: Using Configuration File (Recommended)

1. Copy the example configuration:
   ```bash
   cp dart_defines.example.json dart_defines.json
   ```

2. Edit `dart_defines.json` with your AdMob IDs:
   ```json
   {
     "ENABLE_ADS": "true",
     "ADMOB_BANNER_UNIT_ID": "your-admob-banner-unit-id"
   }
   ```

3. Run with configuration:
   ```bash
   flutter run --dart-define-from-file=dart_defines.json
   ```

4. Or use VS Code launch configurations (already set up in `.vscode/launch.json`)

### Option 2: Command Line

```bash
flutter run --dart-define=ENABLE_ADS=true --dart-define=ADMOB_BANNER_UNIT_ID=<your_banner_unit_id>
```

### Test Ad Unit IDs

For testing, use Google's test ad units:
- Banner: `ca-app-pub-3940256099942544/9214589741`

AdMob app ID is provided to Android via `ADMOB_APP_ID` Gradle property / manifest placeholder.

## Test

```bash
flutter analyze
flutter test
```
