import 'package:flutter_test/flutter_test.dart';
import 'package:screenclean/features/cleanup/application/cleanup_controller.dart';
import 'package:screenclean/features/rating/rating_policy.dart';
import 'package:screenclean/features/scan/domain/models.dart';
import 'package:screenclean/features/scan/domain/repository.dart';

void main() {
  test('deleteSelected runs delete, refresh, and rating prompt flow', () async {
    final repository = _FakeRepository();
    final ratingPolicy = _FakeRatingPolicy(expectedPrompt: true);
    final reviewer = _FakeReviewRequester();
    var refreshCalls = 0;

    final controller = CleanupController(
      repository: repository,
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

    expect(result, isNotNull);
    expect(result!.deletedCount, 2);
    expect(repository.deletedIds, ['id-1', 'id-2']);
    expect(refreshCalls, 1);
    expect(reviewer.requested, isTrue);
    expect(ratingPolicy.marked, isTrue);
  });
}

class _FakeRepository implements ScreenshotRepository {
  List<String> deletedIds = [];

  @override
  Future<CleanupResult> deleteAssets(List<String> ids) async {
    deletedIds = ids;
    return CleanupResult(
      deletedCount: ids.length,
      reclaimedBytes: 3 * 1024 * 1024,
      failedIds: const [],
    );
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ScanReport> scanScreenshots() async => const ScanReport.empty();
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
