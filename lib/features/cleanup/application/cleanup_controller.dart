import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../rating/rating_policy.dart';
import '../../scan/application/scan_controller.dart';
import '../../scan/domain/models.dart';
import '../../scan/domain/repository.dart';

final reviewRequesterProvider = Provider<ReviewRequester>(
  (ref) => const InAppReviewRequester(),
);

final cleanupControllerProvider =
    StateNotifierProvider<CleanupController, CleanupState>((ref) {
      return CleanupController(
        repository: ref.watch(screenshotRepositoryProvider),
        ratingPromptPolicy: ref.watch(ratingPromptPolicyProvider),
        reviewRequester: ref.watch(reviewRequesterProvider),
        onRefreshScan: () => ref.read(scanControllerProvider.notifier).rescan(),
      );
    });

class CleanupState {
  const CleanupState({
    required this.isDeleting,
    this.errorMessage,
    this.lastResult,
  });

  factory CleanupState.initial() => const CleanupState(isDeleting: false);

  final bool isDeleting;
  final String? errorMessage;
  final CleanupResult? lastResult;

  CleanupState copyWith({
    bool? isDeleting,
    String? errorMessage,
    bool clearError = false,
    CleanupResult? lastResult,
  }) {
    return CleanupState(
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class CleanupController extends StateNotifier<CleanupState> {
  CleanupController({
    required ScreenshotRepository repository,
    required RatingPromptPolicy ratingPromptPolicy,
    required ReviewRequester reviewRequester,
    required Future<void> Function() onRefreshScan,
  }) : _repository = repository,
       _ratingPromptPolicy = ratingPromptPolicy,
       _reviewRequester = reviewRequester,
       _onRefreshScan = onRefreshScan,
       super(CleanupState.initial());

  final ScreenshotRepository _repository;
  final RatingPromptPolicy _ratingPromptPolicy;
  final ReviewRequester _reviewRequester;
  final Future<void> Function() _onRefreshScan;

  Future<CleanupResult?> deleteSelected(
    List<ScreenshotAsset> selectedAssets,
  ) async {
    if (selectedAssets.isEmpty || state.isDeleting) {
      return null;
    }

    state = state.copyWith(isDeleting: true, clearError: true);
    try {
      final result = await _repository.deleteAssets(selectedAssets);

      state = state.copyWith(isDeleting: false, lastResult: result);
      unawaited(_runPostDeleteTasks(result));
      return result;
    } catch (_) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: 'Failed to delete selected screenshots.',
      );
      return null;
    }
  }

  Future<void> _runPostDeleteTasks(CleanupResult result) async {
    try {
      await _handleRatingPrompt(result);
    } catch (_) {}

    try {
      await _onRefreshScan();
    } catch (_) {}
  }

  Future<void> _handleRatingPrompt(CleanupResult result) async {
    final shouldPrompt = await _ratingPromptPolicy.shouldPrompt(
      deletedCount: result.deletedCount,
      reclaimedBytes: result.reclaimedBytes,
    );

    if (!shouldPrompt) {
      return;
    }

    final available = await _reviewRequester.isAvailable();
    if (!available) {
      return;
    }

    await _reviewRequester.requestReview();
    await _ratingPromptPolicy.markPromptedForCurrentVersion();
  }
}

abstract class ReviewRequester {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class InAppReviewRequester implements ReviewRequester {
  const InAppReviewRequester();

  @override
  Future<bool> isAvailable() async {
    return InAppReview.instance.isAvailable();
  }

  @override
  Future<void> requestReview() async {
    await InAppReview.instance.requestReview();
  }
}
