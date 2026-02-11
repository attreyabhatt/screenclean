import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/photo_manager_repository.dart';
import '../domain/models.dart';
import '../domain/repository.dart';

final screenshotRepositoryProvider = Provider<ScreenshotRepository>(
  (ref) => const PhotoManagerScreenshotRepository(),
);

final scanControllerProvider =
    StateNotifierProvider<ScanController, ScanState>((ref) {
  return ScanController(repository: ref.watch(screenshotRepositoryProvider));
});

class ScanState {
  const ScanState({
    required this.isLoading,
    required this.hasPermission,
    required this.report,
    this.errorMessage,
  });

  factory ScanState.initial() {
    return const ScanState(
      isLoading: false,
      hasPermission: true,
      report: ScanReport.empty(),
    );
  }

  final bool isLoading;
  final bool hasPermission;
  final ScanReport report;
  final String? errorMessage;

  ScanState copyWith({
    bool? isLoading,
    bool? hasPermission,
    ScanReport? report,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScanState(
      isLoading: isLoading ?? this.isLoading,
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

  Future<void> initialize() => _runScan();
  Future<void> rescan() => _runScan();

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> _runScan() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final hasPermission = await _repository.requestPermission();
      if (!hasPermission) {
        state = state.copyWith(
          isLoading: false,
          hasPermission: false,
          report: const ScanReport.empty(),
        );
        return;
      }

      final report = await _repository.scanScreenshots();
      state = state.copyWith(
        isLoading: false,
        hasPermission: true,
        report: report,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to scan screenshots. Please try again.',
      );
    }
  }
}
