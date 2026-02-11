import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenclean/features/rating/rating_policy.dart';

void main() {
  test('prompts only on meaningful cleanup and only once per app version', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final policy = SharedPrefsRatingPromptPolicy(
      sharedPreferences: prefs,
      appVersion: '1.0.0',
    );

    final belowThreshold = await policy.shouldPrompt(
      deletedCount: 10,
      reclaimedBytes: 50 * 1024 * 1024,
    );
    expect(belowThreshold, isFalse);

    final meetsThreshold = await policy.shouldPrompt(
      deletedCount: 20,
      reclaimedBytes: 1,
    );
    expect(meetsThreshold, isTrue);

    await policy.markPromptedForCurrentVersion();
    final secondTrySameVersion = await policy.shouldPrompt(
      deletedCount: 50,
      reclaimedBytes: 500 * 1024 * 1024,
    );
    expect(secondTrySameVersion, isFalse);
  });

  test('new app version can prompt again', () async {
    SharedPreferences.setMockInitialValues({
      'last_prompted_version': '1.0.0',
    });
    final prefs = await SharedPreferences.getInstance();
    final policy = SharedPrefsRatingPromptPolicy(
      sharedPreferences: prefs,
      appVersion: '1.1.0',
    );

    final shouldPrompt = await policy.shouldPrompt(
      deletedCount: 25,
      reclaimedBytes: 150 * 1024 * 1024,
    );

    expect(shouldPrompt, isTrue);
  });
}
