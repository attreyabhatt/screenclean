import 'package:flutter_test/flutter_test.dart';
import 'package:screenclean/features/scan/domain/models.dart';
import 'package:screenclean/features/scan/domain/scan_analyzer.dart';

ScreenshotAsset _asset({
  required String id,
  required DateTime createdAt,
  required int sizeBytes,
  bool isOld = false,
}) {
  return ScreenshotAsset(
    id: id,
    pathId: 'path',
    name: id,
    createdAt: createdAt,
    sizeBytes: sizeBytes,
    isOld: isOld,
  );
}

void main() {
  test('old-item boundary uses strict older-than-30-days rule', () {
    final now = DateTime(2026, 2, 10, 12);
    final olderThanThirty = now.subtract(const Duration(days: 31));
    final exactlyThirty = now.subtract(const Duration(days: 30));

    expect(ScanAnalyzer.isOldItem(olderThanThirty, now), isTrue);
    expect(ScanAnalyzer.isOldItem(exactlyThirty, now), isFalse);
  });

  test('duplicate detection marks all except oldest in exact hash group', () async {
    final baseDate = DateTime(2026, 1, 1);
    final first = _asset(id: 'a', createdAt: baseDate, sizeBytes: 100);
    final second = _asset(id: 'b', createdAt: baseDate.add(const Duration(days: 1)), sizeBytes: 100);
    final third = _asset(id: 'c', createdAt: baseDate.add(const Duration(days: 2)), sizeBytes: 100);
    final nonDuplicate = _asset(
      id: 'd',
      createdAt: baseDate.add(const Duration(days: 3)),
      sizeBytes: 120,
    );

    final hashes = {
      'a': 'same',
      'b': 'same',
      'c': 'same',
      'd': 'different',
    };

    final analyzed = await ScanAnalyzer.markDuplicateCandidates(
      [first, second, third, nonDuplicate],
      (asset) async => hashes[asset.id],
    );

    final byId = {for (final asset in analyzed) asset.id: asset};

    expect(byId['a']!.duplicateGroupId, isNull);
    expect(byId['b']!.duplicateGroupId, 'same');
    expect(byId['c']!.duplicateGroupId, 'same');
    expect(byId['d']!.duplicateGroupId, isNull);
  });

  test('visual similarity marks all except oldest in similar group', () async {
    final baseDate = DateTime(2026, 1, 1);
    final first = _asset(id: 'a', createdAt: baseDate, sizeBytes: 100);
    final second = _asset(id: 'b', createdAt: baseDate.add(const Duration(days: 1)), sizeBytes: 110);
    final third = _asset(id: 'c', createdAt: baseDate.add(const Duration(days: 2)), sizeBytes: 120);
    final different = _asset(
      id: 'd',
      createdAt: baseDate.add(const Duration(days: 3)),
      sizeBytes: 130,
    );

    final visualHashes = <String, BigInt>{
      'a': BigInt.parse('0', radix: 16),
      'b': BigInt.parse('1', radix: 16),
      'c': BigInt.parse('3', radix: 16),
      'd': BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16),
    };

    final analyzed = await ScanAnalyzer.markSimilarCandidates(
      [first, second, third, different],
      (asset) async => visualHashes[asset.id],
      hammingDistanceThreshold: 2,
    );

    final byId = {for (final asset in analyzed) asset.id: asset};
    expect(byId['a']!.similarGroupId, isNull);
    expect(byId['b']!.similarGroupId, 'sim-1');
    expect(byId['c']!.similarGroupId, 'sim-1');
    expect(byId['d']!.similarGroupId, isNull);
  });

  test('report sums counts and reclaimable bytes correctly', () {
    final assets = [
      _asset(id: '1', createdAt: DateTime(2025), sizeBytes: 200, isOld: true),
      _asset(
        id: '2',
        createdAt: DateTime(2025),
        sizeBytes: 300,
        isOld: false,
      ).copyWith(duplicateGroupId: 'dup-1'),
      _asset(
        id: '3',
        createdAt: DateTime(2025),
        sizeBytes: 500,
        isOld: false,
      ).copyWith(similarGroupId: 'sim-1'),
    ];

    final report = ScanAnalyzer.buildReport(assets);

    expect(report.totalCount, 3);
    expect(report.totalBytes, 1000);
    expect(report.oldCount, 1);
    expect(report.oldBytes, 200);
    expect(report.duplicateCount, 1);
    expect(report.duplicateBytes, 300);
    expect(report.similarCount, 1);
    expect(report.similarBytes, 500);
  });
}
