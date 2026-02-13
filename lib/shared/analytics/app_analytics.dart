import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appAnalyticsProvider = Provider<AppAnalytics>(
  (ref) => const NoopAppAnalytics(),
);

abstract class AppAnalytics {
  Future<void> logScanStarted();

  Future<void> logScanCompleted({
    required int totalCount,
    required int totalBytes,
    required int oldCount,
    required int similarCount,
  });

  Future<void> logScanPermissionDenied();

  Future<void> logScanFailed();

  Future<void> logDeleteConfirmed({
    required int selectedCount,
    required int selectedBytes,
  });

  Future<void> logBytesReclaimed({
    required int deletedCount,
    required int reclaimedBytes,
    required int failedCount,
  });
}

class FirebaseAppAnalytics implements AppAnalytics {
  const FirebaseAppAnalytics(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logScanStarted() {
    return _analytics.logEvent(name: 'scan_started');
  }

  @override
  Future<void> logScanCompleted({
    required int totalCount,
    required int totalBytes,
    required int oldCount,
    required int similarCount,
  }) {
    return _analytics.logEvent(
      name: 'scan_completed',
      parameters: <String, Object>{
        'total_count': totalCount,
        'total_bytes': totalBytes,
        'old_count': oldCount,
        'similar_count': similarCount,
      },
    );
  }

  @override
  Future<void> logScanPermissionDenied() {
    return _analytics.logEvent(name: 'scan_permission_denied');
  }

  @override
  Future<void> logScanFailed() {
    return _analytics.logEvent(name: 'scan_failed');
  }

  @override
  Future<void> logDeleteConfirmed({
    required int selectedCount,
    required int selectedBytes,
  }) {
    return _analytics.logEvent(
      name: 'cleanup_delete_confirmed',
      parameters: <String, Object>{
        'selected_count': selectedCount,
        'selected_bytes': selectedBytes,
      },
    );
  }

  @override
  Future<void> logBytesReclaimed({
    required int deletedCount,
    required int reclaimedBytes,
    required int failedCount,
  }) {
    return _analytics.logEvent(
      name: 'cleanup_bytes_reclaimed',
      parameters: <String, Object>{
        'deleted_count': deletedCount,
        'reclaimed_bytes': reclaimedBytes,
        'failed_count': failedCount,
      },
    );
  }
}

class NoopAppAnalytics implements AppAnalytics {
  const NoopAppAnalytics();

  @override
  Future<void> logScanStarted() async {}

  @override
  Future<void> logScanCompleted({
    required int totalCount,
    required int totalBytes,
    required int oldCount,
    required int similarCount,
  }) async {}

  @override
  Future<void> logScanPermissionDenied() async {}

  @override
  Future<void> logScanFailed() async {}

  @override
  Future<void> logDeleteConfirmed({
    required int selectedCount,
    required int selectedBytes,
  }) async {}

  @override
  Future<void> logBytesReclaimed({
    required int deletedCount,
    required int reclaimedBytes,
    required int failedCount,
  }) async {}
}
