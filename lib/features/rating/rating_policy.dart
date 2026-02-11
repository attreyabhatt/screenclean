import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final appVersionProvider = Provider<String>(
  (ref) => throw UnimplementedError('appVersionProvider must be overridden'),
);

final ratingPromptPolicyProvider = Provider<RatingPromptPolicy>((ref) {
  return SharedPrefsRatingPromptPolicy(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    appVersion: ref.watch(appVersionProvider),
  );
});

abstract class RatingPromptPolicy {
  Future<bool> shouldPrompt({
    required int deletedCount,
    required int reclaimedBytes,
  });

  Future<void> markPromptedForCurrentVersion();
}

class SharedPrefsRatingPromptPolicy implements RatingPromptPolicy {
  const SharedPrefsRatingPromptPolicy({
    required SharedPreferences sharedPreferences,
    required String appVersion,
  })  : _sharedPreferences = sharedPreferences,
        _appVersion = appVersion;

  static const int _minDeletedCount = 20;
  static const int _minReclaimedBytes = 100 * 1024 * 1024;
  static const String _lastPromptedVersionKey = 'last_prompted_version';
  static const String _lastPromptedAtKey = 'last_prompted_at';

  final SharedPreferences _sharedPreferences;
  final String _appVersion;

  @override
  Future<bool> shouldPrompt({
    required int deletedCount,
    required int reclaimedBytes,
  }) async {
    if (deletedCount <= 0) {
      return false;
    }

    final meetsThreshold =
        deletedCount >= _minDeletedCount || reclaimedBytes >= _minReclaimedBytes;
    if (!meetsThreshold) {
      return false;
    }

    final lastPromptedVersion =
        _sharedPreferences.getString(_lastPromptedVersionKey);
    return lastPromptedVersion != _appVersion;
  }

  @override
  Future<void> markPromptedForCurrentVersion() async {
    await _sharedPreferences.setString(_lastPromptedVersionKey, _appVersion);
    await _sharedPreferences.setString(
      _lastPromptedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}
