import 'models.dart';

typedef AssetHashProvider = Future<String?> Function(ScreenshotAsset asset);
typedef AssetVisualHashProvider = Future<BigInt?> Function(ScreenshotAsset asset);

class ScanAnalyzer {
  const ScanAnalyzer._();

  static const int oldThresholdDays = 30;

  static bool isOldItem(DateTime createdAt, DateTime now) {
    final threshold = now.subtract(const Duration(days: oldThresholdDays));
    return createdAt.isBefore(threshold);
  }

  static Future<List<ScreenshotAsset>> markDuplicateCandidates(
    List<ScreenshotAsset> assets,
    AssetHashProvider hashProvider,
  ) async {
    final mutableById = <String, ScreenshotAsset>{
      for (final asset in assets)
        asset.id: asset.copyWith(clearDuplicateGroupId: true),
    };

    final groupedBySize = <int, List<ScreenshotAsset>>{};
    for (final asset in assets) {
      groupedBySize.putIfAbsent(asset.sizeBytes, () => <ScreenshotAsset>[]).add(asset);
    }

    for (final sizeGroup in groupedBySize.values.where((group) => group.length > 1)) {
      final groupedByHash = <String, List<ScreenshotAsset>>{};
      for (final asset in sizeGroup) {
        final hash = await hashProvider(asset);
        if (hash == null || hash.isEmpty) {
          continue;
        }
        groupedByHash.putIfAbsent(hash, () => <ScreenshotAsset>[]).add(asset);
      }

      for (final entry in groupedByHash.entries.where((entry) => entry.value.length > 1)) {
        final sortedGroup = [...entry.value]
          ..sort((left, right) {
            final byDate = left.createdAt.compareTo(right.createdAt);
            if (byDate != 0) {
              return byDate;
            }
            return left.id.compareTo(right.id);
          });

        for (var index = 1; index < sortedGroup.length; index++) {
          final candidate = sortedGroup[index];
          final existing = mutableById[candidate.id];
          if (existing == null) {
            continue;
          }
          mutableById[candidate.id] = existing.copyWith(duplicateGroupId: entry.key);
        }
      }
    }

    return assets.map((asset) => mutableById[asset.id] ?? asset).toList(growable: false);
  }

  static Future<List<ScreenshotAsset>> markSimilarCandidates(
    List<ScreenshotAsset> assets,
    AssetVisualHashProvider hashProvider, {
    int maxCandidates = 400,
    int hammingDistanceThreshold = 6,
  }) async {
    final mutableById = <String, ScreenshotAsset>{
      for (final asset in assets)
        asset.id: asset.copyWith(clearSimilarGroupId: true),
    };

    final candidates = assets.where((asset) => !asset.isDuplicateCandidate).toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    if (candidates.length > maxCandidates) {
      candidates.removeRange(maxCandidates, candidates.length);
    }

    final hashesById = <String, BigInt>{};
    for (final asset in candidates) {
      final hash = await hashProvider(asset);
      if (hash == null) {
        continue;
      }
      hashesById[asset.id] = hash;
    }

    final hashedAssets = candidates.where((asset) => hashesById.containsKey(asset.id)).toList();
    if (hashedAssets.length < 2) {
      return assets.map((asset) => mutableById[asset.id] ?? asset).toList(growable: false);
    }

    final indexById = <String, int>{};
    for (var index = 0; index < hashedAssets.length; index++) {
      indexById[hashedAssets[index].id] = index;
    }

    final parent = List<int>.generate(hashedAssets.length, (index) => index);
    int find(int index) {
      if (parent[index] != index) {
        parent[index] = find(parent[index]);
      }
      return parent[index];
    }

    void union(int left, int right) {
      final leftRoot = find(left);
      final rightRoot = find(right);
      if (leftRoot != rightRoot) {
        parent[rightRoot] = leftRoot;
      }
    }

    for (var left = 0; left < hashedAssets.length; left++) {
      for (var right = left + 1; right < hashedAssets.length; right++) {
        final leftHash = hashesById[hashedAssets[left].id];
        final rightHash = hashesById[hashedAssets[right].id];
        if (leftHash == null || rightHash == null) {
          continue;
        }
        final distance = _hammingDistance64(leftHash, rightHash);
        if (distance <= hammingDistanceThreshold) {
          union(left, right);
        }
      }
    }

    final groups = <int, List<ScreenshotAsset>>{};
    for (final asset in hashedAssets) {
      final index = indexById[asset.id];
      if (index == null) {
        continue;
      }
      groups.putIfAbsent(find(index), () => <ScreenshotAsset>[]).add(asset);
    }

    var groupNumber = 0;
    for (final group in groups.values.where((group) => group.length > 1)) {
      groupNumber++;
      final groupId = 'sim-$groupNumber';
      final sortedGroup = [...group]
        ..sort((left, right) {
          final byDate = left.createdAt.compareTo(right.createdAt);
          if (byDate != 0) {
            return byDate;
          }
          return left.id.compareTo(right.id);
        });

      for (var index = 1; index < sortedGroup.length; index++) {
        final candidate = sortedGroup[index];
        final existing = mutableById[candidate.id];
        if (existing == null) {
          continue;
        }
        mutableById[candidate.id] = existing.copyWith(similarGroupId: groupId);
      }
    }

    return assets.map((asset) => mutableById[asset.id] ?? asset).toList(growable: false);
  }

  static ScanReport buildReport(List<ScreenshotAsset> assets) {
    final totalBytes = assets.fold<int>(0, (sum, asset) => sum + asset.sizeBytes);
    final oldAssets = assets.where((asset) => asset.isOld);
    final duplicateAssets = assets.where((asset) => asset.isDuplicateCandidate);
    final similarAssets = assets.where((asset) => asset.isSimilarCandidate);

    final oldBytes = oldAssets.fold<int>(0, (sum, asset) => sum + asset.sizeBytes);
    final duplicateBytes = duplicateAssets.fold<int>(0, (sum, asset) => sum + asset.sizeBytes);
    final similarBytes = similarAssets.fold<int>(0, (sum, asset) => sum + asset.sizeBytes);

    return ScanReport(
      totalCount: assets.length,
      totalBytes: totalBytes,
      oldCount: oldAssets.length,
      oldBytes: oldBytes,
      duplicateCount: duplicateAssets.length,
      duplicateBytes: duplicateBytes,
      similarCount: similarAssets.length,
      similarBytes: similarBytes,
      assets: assets,
    );
  }

  static int _hammingDistance64(BigInt left, BigInt right) {
    var value = (left ^ right).toUnsigned(64);
    var count = 0;
    while (value > BigInt.zero) {
      if ((value & BigInt.one) == BigInt.one) {
        count++;
      }
      value = value >> 1;
    }
    return count;
  }
}
