import 'dart:typed_data';

class ScreenshotAsset {
  const ScreenshotAsset({
    required this.id,
    required this.pathId,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
    required this.isOld,
    this.duplicateGroupId,
    this.similarGroupId,
    this.thumbnailData,
  });

  final String id;
  final String pathId;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
  final bool isOld;
  final String? duplicateGroupId;
  final String? similarGroupId;
  final Uint8List? thumbnailData;

  bool get isDuplicateCandidate => duplicateGroupId != null;
  bool get isSimilarCandidate => similarGroupId != null;

  ScreenshotAsset copyWith({
    String? id,
    String? pathId,
    String? name,
    DateTime? createdAt,
    int? sizeBytes,
    bool? isOld,
    String? duplicateGroupId,
    bool clearDuplicateGroupId = false,
    String? similarGroupId,
    bool clearSimilarGroupId = false,
    Uint8List? thumbnailData,
  }) {
    return ScreenshotAsset(
      id: id ?? this.id,
      pathId: pathId ?? this.pathId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isOld: isOld ?? this.isOld,
      duplicateGroupId:
          clearDuplicateGroupId ? null : duplicateGroupId ?? this.duplicateGroupId,
      similarGroupId:
          clearSimilarGroupId ? null : similarGroupId ?? this.similarGroupId,
      thumbnailData: thumbnailData ?? this.thumbnailData,
    );
  }
}

class ScanReport {
  const ScanReport({
    required this.totalCount,
    required this.totalBytes,
    required this.oldCount,
    required this.oldBytes,
    required this.duplicateCount,
    required this.duplicateBytes,
    required this.similarCount,
    required this.similarBytes,
    required this.assets,
  });

  const ScanReport.empty()
      : totalCount = 0,
        totalBytes = 0,
        oldCount = 0,
        oldBytes = 0,
        duplicateCount = 0,
        duplicateBytes = 0,
        similarCount = 0,
        similarBytes = 0,
        assets = const [];

  final int totalCount;
  final int totalBytes;
  final int oldCount;
  final int oldBytes;
  final int duplicateCount;
  final int duplicateBytes;
  final int similarCount;
  final int similarBytes;
  final List<ScreenshotAsset> assets;
}

class CleanupResult {
  const CleanupResult({
    required this.deletedCount,
    required this.reclaimedBytes,
    required this.failedIds,
  });

  const CleanupResult.empty()
      : deletedCount = 0,
        reclaimedBytes = 0,
        failedIds = const [];

  final int deletedCount;
  final int reclaimedBytes;
  final List<String> failedIds;
}
