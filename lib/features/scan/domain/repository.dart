import 'models.dart';

abstract class ScreenshotRepository {
  Future<bool> requestPermission();
  Future<ScanReport> scanScreenshots();
  Future<List<ScreenshotAsset>> enrichSimilarCandidates(
    List<ScreenshotAsset> assets,
  );
  Future<CleanupResult> deleteAssets(List<ScreenshotAsset> assets);
}
