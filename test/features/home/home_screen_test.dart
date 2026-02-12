import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenclean/features/cleanup/application/cleanup_controller.dart';
import 'package:screenclean/features/home/presentation/home_screen.dart';
import 'package:screenclean/features/rating/rating_policy.dart';
import 'package:screenclean/features/scan/application/scan_controller.dart';
import 'package:screenclean/features/scan/domain/models.dart';
import 'package:screenclean/features/scan/domain/repository.dart';

void main() {
  testWidgets('renders summary and supports bulk selection + delete', (tester) async {
    final fakeRepository = _FakeScreenshotRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenshotRepositoryProvider.overrideWithValue(fakeRepository),
          ratingPromptPolicyProvider.overrideWithValue(_NeverPromptRatingPolicy()),
          reviewRequesterProvider.overrideWithValue(_NoopReviewRequester()),
        ],
        child: const MaterialApp(
          home: HomeScreen(
            thumbnailLoader: _fakeThumbnailLoader,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-total-count')), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    await tester.tap(find.byKey(const Key('select-all-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-selected-button')), findsOneWidget);
    expect(find.textContaining('Delete 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-selected-button')));
    await tester.pumpAndSettle();
    expect(find.text('This action cannot be undone.'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fakeRepository.deletedIds.length, 3);
  });

  testWidgets('changing filter drops selection not visible in new filter', (tester) async {
    final fakeRepository = _FakeScreenshotRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenshotRepositoryProvider.overrideWithValue(fakeRepository),
          ratingPromptPolicyProvider.overrideWithValue(_NeverPromptRatingPolicy()),
          reviewRequesterProvider.overrideWithValue(_NoopReviewRequester()),
        ],
        child: const MaterialApp(
          home: HomeScreen(
            thumbnailLoader: _fakeThumbnailLoader,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-old')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('select-all-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Delete 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-duplicates')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-selected-button')), findsNothing);
  });
}

Future<Uint8List?> _fakeThumbnailLoader(String _) async => null;

class _FakeScreenshotRepository implements ScreenshotRepository {
  _FakeScreenshotRepository()
      : _assets = [
          ScreenshotAsset(
            id: '1',
            pathId: 'path',
            name: 'a.png',
            createdAt: DateTime(2025, 10, 1),
            sizeBytes: 1200,
            isOld: true,
          ),
          ScreenshotAsset(
            id: '2',
            pathId: 'path',
            name: 'b.png',
            createdAt: DateTime(2026, 1, 1),
            sizeBytes: 1400,
            isOld: false,
          ).copyWith(duplicateGroupId: 'dup-x'),
          ScreenshotAsset(
            id: '3',
            pathId: 'path',
            name: 'c.png',
            createdAt: DateTime(2026, 1, 5),
            sizeBytes: 1600,
            isOld: false,
          ),
        ];

  final List<ScreenshotAsset> _assets;
  List<String> deletedIds = [];

  @override
  Future<CleanupResult> deleteAssets(List<String> ids) async {
    deletedIds = ids;
    return CleanupResult(
      deletedCount: ids.length,
      reclaimedBytes: 4096,
      failedIds: const [],
    );
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ScanReport> scanScreenshots() async {
    return ScanReport(
      totalCount: _assets.length,
      totalBytes: _assets.fold<int>(0, (sum, item) => sum + item.sizeBytes),
      oldCount: _assets.where((item) => item.isOld).length,
      oldBytes: _assets
          .where((item) => item.isOld)
          .fold<int>(0, (sum, item) => sum + item.sizeBytes),
      duplicateCount: _assets.where((item) => item.isDuplicateCandidate).length,
      duplicateBytes: _assets
          .where((item) => item.isDuplicateCandidate)
          .fold<int>(0, (sum, item) => sum + item.sizeBytes),
      similarCount: _assets.where((item) => item.isSimilarCandidate).length,
      similarBytes: _assets
          .where((item) => item.isSimilarCandidate)
          .fold<int>(0, (sum, item) => sum + item.sizeBytes),
      assets: _assets,
    );
  }
}

class _NeverPromptRatingPolicy implements RatingPromptPolicy {
  @override
  Future<void> markPromptedForCurrentVersion() async {}

  @override
  Future<bool> shouldPrompt({
    required int deletedCount,
    required int reclaimedBytes,
  }) async {
    return false;
  }
}

class _NoopReviewRequester implements ReviewRequester {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> requestReview() async {}
}
