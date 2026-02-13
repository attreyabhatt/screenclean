import 'package:flutter_test/flutter_test.dart';
import 'package:screenclean/features/scan/application/scan_controller.dart';
import 'package:screenclean/features/scan/domain/models.dart';
import 'package:screenclean/features/scan/domain/repository.dart';
import 'package:screenclean/features/scan/domain/scan_analyzer.dart';
import 'package:screenclean/shared/analytics/app_analytics.dart';

void main() {
  test('optimisticallyRemoveAssetsById updates report immediately', () async {
    final assets = [
      ScreenshotAsset(
        id: 'a',
        pathId: 'path',
        name: 'a.png',
        createdAt: DateTime(2025, 1, 1),
        sizeBytes: 100,
        isOld: true,
      ),
      ScreenshotAsset(
        id: 'b',
        pathId: 'path',
        name: 'b.png',
        createdAt: DateTime(2025, 1, 2),
        sizeBytes: 200,
        isOld: false,
      ).copyWith(duplicateGroupId: 'dup-1'),
      ScreenshotAsset(
        id: 'c',
        pathId: 'path',
        name: 'c.png',
        createdAt: DateTime(2025, 1, 3),
        sizeBytes: 300,
        isOld: false,
      ).copyWith(similarGroupId: 'sim-1'),
    ];

    final repository = _FakeRepository(
      report: ScanAnalyzer.buildReport(assets),
    );
    final controller = ScanController(
      repository: repository,
      analytics: const NoopAppAnalytics(),
    );

    await controller.initialize();
    controller.optimisticallyRemoveAssetsById(const ['b']);

    expect(controller.state.report.totalCount, 2);
    expect(controller.state.report.totalBytes, 400);
    expect(controller.state.report.oldCount, 1);
    expect(controller.state.report.duplicateCount, 0);
    expect(controller.state.report.similarCount, 1);
    expect(controller.state.report.assets.map((asset) => asset.id), ['a', 'c']);
  });

  test(
    'ensureSimilarAnalysis runs once and enriches similar metadata',
    () async {
      final assets = [
        ScreenshotAsset(
          id: 'a',
          pathId: 'path',
          name: 'a.png',
          createdAt: DateTime(2025, 1, 1),
          sizeBytes: 100,
          isOld: true,
        ),
        ScreenshotAsset(
          id: 'b',
          pathId: 'path',
          name: 'b.png',
          createdAt: DateTime(2025, 1, 2),
          sizeBytes: 200,
          isOld: false,
        ),
      ];

      final repository = _FakeRepository(
        report: ScanAnalyzer.buildReport(assets),
        enrichSimilar: (items) async => items
            .map(
              (asset) => asset.id == 'b'
                  ? asset.copyWith(similarGroupId: 'sim-1')
                  : asset,
            )
            .toList(growable: false),
      );
      final controller = ScanController(
        repository: repository,
        analytics: const NoopAppAnalytics(),
      );

      await controller.initialize();
      expect(controller.state.hasSimilarAnalysis, isFalse);
      expect(controller.state.report.similarCount, 0);

      await controller.ensureSimilarAnalysis();
      expect(repository.similarEnrichmentCalls, 1);
      expect(controller.state.hasSimilarAnalysis, isTrue);
      expect(controller.state.report.similarCount, 1);

      await controller.ensureSimilarAnalysis();
      expect(repository.similarEnrichmentCalls, 1);
    },
  );
}

class _FakeRepository implements ScreenshotRepository {
  _FakeRepository({
    required this.report,
    Future<List<ScreenshotAsset>> Function(List<ScreenshotAsset> assets)?
    enrichSimilar,
  }) : _enrichSimilar = enrichSimilar;

  final ScanReport report;
  final Future<List<ScreenshotAsset>> Function(List<ScreenshotAsset> assets)?
  _enrichSimilar;
  int similarEnrichmentCalls = 0;

  @override
  Future<CleanupResult> deleteAssets(List<ScreenshotAsset> assets) async {
    return CleanupResult(
      deletedCount: assets.length,
      reclaimedBytes: 0,
      failedIds: const [],
    );
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ScanReport> scanScreenshots() async => report;

  @override
  Future<List<ScreenshotAsset>> enrichSimilarCandidates(
    List<ScreenshotAsset> assets,
  ) async {
    similarEnrichmentCalls++;
    if (_enrichSimilar == null) {
      return assets;
    }
    return _enrichSimilar(assets);
  }
}
