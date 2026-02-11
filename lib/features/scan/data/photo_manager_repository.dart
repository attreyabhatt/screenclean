import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';

import '../domain/models.dart';
import '../domain/repository.dart';
import '../domain/scan_analyzer.dart';

const Set<String> _screenshotFolderKeywords = <String>{
  'screenshot',
  'screenshots',
  'screen_shot',
  'screen-shot',
  'screen shot',
  'captura de pantalla',
  'capturas de pantalla',
};

class PhotoManagerScreenshotRepository implements ScreenshotRepository {
  const PhotoManagerScreenshotRepository();

  static const int _pageSize = 200;
  static const int _visualSimilarityThreshold = 6;

  @override
  Future<bool> requestPermission() async {
    final permissionState = await PhotoManager.requestPermissionExtend();
    return permissionState.hasAccess;
  }

  @override
  Future<ScanReport> scanScreenshots() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      return const ScanReport.empty();
    }

    final allPaths = await PhotoManager.getAssetPathList(type: RequestType.image);
    final screenshotPaths =
        allPaths.where((path) => _isScreenshotFolder(path.name)).toList(growable: false);

    final now = DateTime.now();
    final assets = <ScreenshotAsset>[];

    for (final path in screenshotPaths) {
      final pathAssets = await _loadPathAssets(path, now);
      assets.addAll(pathAssets);
    }

    final withDuplicateMetadata = await ScanAnalyzer.markDuplicateCandidates(
      assets,
      _buildHashForAsset,
    );
    final withVisualSimilarityMetadata = await ScanAnalyzer.markSimilarCandidates(
      withDuplicateMetadata,
      _buildVisualHashForAsset,
      hammingDistanceThreshold: _visualSimilarityThreshold,
    );
    withVisualSimilarityMetadata.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );

    return ScanAnalyzer.buildReport(withVisualSimilarityMetadata);
  }

  @override
  Future<CleanupResult> deleteAssets(List<String> ids) async {
    if (ids.isEmpty) {
      return const CleanupResult.empty();
    }

    final sizeById = <String, int>{};
    for (final id in ids) {
      final entity = await AssetEntity.fromId(id);
      if (entity == null) {
        continue;
      }
      sizeById[id] = await _readEntitySize(entity);
    }

    final deletedIds = await PhotoManager.editor.deleteWithIds(ids);
    final failedIds = ids.where((id) => !deletedIds.contains(id)).toList(growable: false);
    final reclaimedBytes =
        deletedIds.fold<int>(0, (sum, id) => sum + (sizeById[id] ?? 0));

    return CleanupResult(
      deletedCount: deletedIds.length,
      reclaimedBytes: reclaimedBytes,
      failedIds: failedIds,
    );
  }

  Future<List<ScreenshotAsset>> _loadPathAssets(
    AssetPathEntity path,
    DateTime now,
  ) async {
    final loaded = <ScreenshotAsset>[];
    var page = 0;

    while (true) {
      final entities = await path.getAssetListPaged(page: page, size: _pageSize);
      if (entities.isEmpty) {
        break;
      }

      for (final entity in entities) {
        final sizeBytes = await _readEntitySize(entity);
        loaded.add(
          ScreenshotAsset(
            id: entity.id,
            pathId: path.id,
            name: entity.title ?? 'Screenshot',
            createdAt: entity.createDateTime,
            sizeBytes: sizeBytes,
            isOld: ScanAnalyzer.isOldItem(entity.createDateTime, now),
          ),
        );
      }

      if (entities.length < _pageSize) {
        break;
      }
      page++;
    }

    return loaded;
  }

  Future<int> _readEntitySize(AssetEntity entity) async {
    final file = await entity.file;
    if (file == null || !await file.exists()) {
      return 0;
    }
    return file.lengthSync();
  }

  Future<String?> _buildHashForAsset(ScreenshotAsset asset) async {
    final entity = await AssetEntity.fromId(asset.id);
    if (entity == null) {
      return null;
    }

    File? file;
    try {
      file = await entity.originFile;
    } catch (_) {
      file = null;
    }
    file ??= await entity.file;

    if (file == null || !await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  Future<BigInt?> _buildVisualHashForAsset(ScreenshotAsset asset) async {
    final entity = await AssetEntity.fromId(asset.id);
    if (entity == null) {
      return null;
    }

    final thumbnailBytes =
        await entity.thumbnailDataWithSize(const ThumbnailSize(72, 72));
    if (thumbnailBytes == null || thumbnailBytes.isEmpty) {
      return null;
    }

    final decoded = img.decodeImage(thumbnailBytes);
    if (decoded == null) {
      return null;
    }

    final resized = img.copyResize(
      decoded,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    );

    var hash = BigInt.zero;
    var bitIndex = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final leftPixel = resized.getPixel(x, y);
        final rightPixel = resized.getPixel(x + 1, y);
        final leftLuma = _pixelLuma(leftPixel);
        final rightLuma = _pixelLuma(rightPixel);
        if (leftLuma > rightLuma) {
          hash |= (BigInt.one << bitIndex);
        }
        bitIndex++;
      }
    }

    return hash.toUnsigned(64);
  }

  double _pixelLuma(img.Pixel pixel) {
    return (pixel.r.toDouble() * 0.299) +
        (pixel.g.toDouble() * 0.587) +
        (pixel.b.toDouble() * 0.114);
  }

  bool _isScreenshotFolder(String folderName) {
    final normalized = folderName.toLowerCase();
    return _screenshotFolderKeywords.any(normalized.contains);
  }
}
