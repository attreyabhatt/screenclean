import 'package:flutter_test/flutter_test.dart';
import 'package:screenclean/features/cleanup/application/cleanup_controller.dart';
import 'package:screenclean/features/rating/rating_policy.dart';
import 'package:screenclean/features/scan/domain/models.dart';
import 'package:screenclean/features/scan/domain/repository.dart';
import 'package:screenclean/shared/analytics/app_analytics.dart';

void main() {
  test('deleteSelected runs delete, refresh, and rating prompt flow', () async {
    final repository = _FakeRepository();
    final ratingPolicy = _FakeRatingPolicy(expectedPrompt: true);
    final reviewer = _FakeReviewRequester();
    var refreshCalls = 0;

    final controller = CleanupController(
      repository: repository,
      analytics: const NoopAppAnalytics(),
      ratingPromptPolicy: ratingPolicy,
      reviewRequester: reviewer,
      onRefreshScan: () async => refreshCalls++,
    );

    final selected = [
      ScreenshotAsset(
        id: 'id-1',
        pathId: 'p',
        name: 'a.png',
        createdAt: DateTime(2026, 1, 1),
        sizeBytes: 1200,
        isOld: true,
      ),
      ScreenshotAsset(
        id: 'id-2',
        pathId: 'p',
        name: 'b.png',
        createdAt: DateTime(2026, 1, 2),
        sizeBytes: 2000,
        isOld: false,
      ),
    ];

    final result = await controller.deleteSelected(selected);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(result, isNotNull);
    expect(result!.deletedCount, 2);
    expect(repository.deletedAssets.map((asset) => asset.id), ['id-1', 'id-2']);
    expect(refreshCalls, 1);
    expect(reviewer.requested, isTrue);
    expect(ratingPolicy.marked, isTrue);
  });
}

class _FakeRepository implements ScreenshotRepository {
  List<ScreenshotAsset> deletedAssets = [];

  @override
  Future<CleanupResult> deleteAssets(List<ScreenshotAsset> assets) async {
    deletedAssets = assets;
    return CleanupResult(
      deletedCount: assets.length,
      reclaimedBytes: 3 * 1024 * 1024,
      failedIds: const [],
    );
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ScanReport> scanScreenshots() async => const ScanReport.empty();

  @override
  Future<List<ScreenshotAsset>> enrichSimilarCandidates(
    List<ScreenshotAsset> assets,
  ) async {
    return assets;
  }
}

class _FakeRatingPolicy implements RatingPromptPolicy {
  _FakeRatingPolicy({required this.expectedPrompt});

  final bool expectedPrompt;
  bool marked = false;

  @override
  Future<void> markPromptedForCurrentVersion() async {
    marked = true;
  }

  @override
  Future<bool> shouldPrompt({
    required int deletedCount,
    required int reclaimedBytes,
  }) async {
    return expectedPrompt;
  }
}

class _FakeReviewRequester implements ReviewRequester {
  bool requested = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> requestReview() async {
    requested = true;
  }
}
