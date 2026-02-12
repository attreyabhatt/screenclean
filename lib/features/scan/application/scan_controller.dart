import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/photo_manager_repository.dart';
import '../domain/models.dart';
import '../domain/repository.dart';
import '../domain/scan_analyzer.dart';

final screenshotRepositoryProvider = Provider<ScreenshotRepository>(
  (ref) => const PhotoManagerScreenshotRepository(),
);

final scanControllerProvider = StateNotifierProvider<ScanController, ScanState>(
  (ref) {
    return ScanController(repository: ref.watch(screenshotRepositoryProvider));
  },
);

class ScanState {
  const ScanState({
    required this.isLoading,
    required this.isSimilarAnalysisInProgress,
    required this.hasSimilarAnalysis,
    required this.hasPermission,
    required this.report,
    this.errorMessage,
  });

  factory ScanState.initial() {
    return const ScanState(
      isLoading: false,
      isSimilarAnalysisInProgress: false,
      hasSimilarAnalysis: false,
      hasPermission: true,
      report: ScanReport.empty(),
    );
  }

  final bool isLoading;
  final bool isSimilarAnalysisInProgress;
  final bool hasSimilarAnalysis;
  final bool hasPermission;
  final ScanReport report;
  final String? errorMessage;

  ScanState copyWith({
    bool? isLoading,
    bool? isSimilarAnalysisInProgress,
    bool? hasSimilarAnalysis,
    bool? hasPermission,
    ScanReport? report,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScanState(
      isLoading: isLoading ?? this.isLoading,
      isSimilarAnalysisInProgress:
          isSimilarAnalysisInProgress ?? this.isSimilarAnalysisInProgress,
      hasSimilarAnalysis: hasSimilarAnalysis ?? this.hasSimilarAnalysis,
      hasPermission: hasPermission ?? this.hasPermission,
      report: report ?? this.report,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ScanController extends StateNotifier<ScanState> {
  ScanController({required ScreenshotRepository repository})
    : _repository = repository,
      super(ScanState.initial());

  final ScreenshotRepository _repository;
  int _scanGeneration = 0;

  Future<void> initialize() => _runScan();
  Future<void> rescan() => _runScan();

  Future<void> ensureSimilarAnalysis() async {
    if (!state.hasPermission ||
        state.isLoading ||
        state.report.assets.isEmpty ||
        state.hasSimilarAnalysis ||
        state.isSimilarAnalysisInProgress) {
      return;
    }

    final generation = _scanGeneration;
    final sourceAssets = state.report.assets;
    state = state.copyWith(isSimilarAnalysisInProgress: true);

    try {
      final enriched = await _repository.enrichSimilarCandidates(sourceAssets);
      if (generation != _scanGeneration) {
        return;
      }

      final enrichedById = <String, ScreenshotAsset>{
        for (final asset in enriched) asset.id: asset,
      };
      final mergedAssets = state.report.assets
          .map((asset) {
            final enrichedAsset = enrichedById[asset.id];
            if (enrichedAsset == null) {
              return asset.copyWith(clearSimilarGroupId: true);
            }
            return asset.copyWith(
              similarGroupId: enrichedAsset.similarGroupId,
              clearSimilarGroupId: enrichedAsset.similarGroupId == null,
            );
          })
          .toList(growable: false);

      state = state.copyWith(
        isSimilarAnalysisInProgress: false,
        hasSimilarAnalysis: true,
        report: ScanAnalyzer.buildReport(mergedAssets),
      );
    } catch (_) {
      if (generation != _scanGeneration) {
        return;
      }
      state = state.copyWith(isSimilarAnalysisInProgress: false);
    }
  }

  void optimisticallyRemoveAssetsById(Iterable<String> ids) {
    final removedIds = ids.toSet();
    if (removedIds.isEmpty || state.report.assets.isEmpty) {
      return;
    }

    final remainingAssets = state.report.assets
        .where((asset) => !removedIds.contains(asset.id))
        .toList(growable: false);

    if (remainingAssets.length == state.report.assets.length) {
      return;
    }

    state = state.copyWith(report: ScanAnalyzer.buildReport(remainingAssets));
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> _runScan() async {
    final generation = ++_scanGeneration;
    state = state.copyWith(
      isLoading: true,
      isSimilarAnalysisInProgress: false,
      hasSimilarAnalysis: false,
      clearError: true,
    );
    try {
      final hasPermission = await _repository.requestPermission();
      if (generation != _scanGeneration) {
        return;
      }

      if (!hasPermission) {
        state = state.copyWith(
          isLoading: false,
          isSimilarAnalysisInProgress: false,
          hasSimilarAnalysis: false,
          hasPermission: false,
          report: const ScanReport.empty(),
        );
        return;
      }

      final report = await _repository.scanScreenshots();
      if (generation != _scanGeneration) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isSimilarAnalysisInProgress: false,
        hasSimilarAnalysis: false,
        hasPermission: true,
        report: report,
      );
    } catch (error) {
      if (generation != _scanGeneration) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isSimilarAnalysisInProgress: false,
        hasSimilarAnalysis: false,
        errorMessage: 'Failed to scan screenshots. Please try again.',
      );
    }
  }
}
