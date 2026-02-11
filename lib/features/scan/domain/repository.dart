import 'models.dart';

abstract class ScreenshotRepository {
  Future<bool> requestPermission();
  Future<ScanReport> scanScreenshots();
  Future<CleanupResult> deleteAssets(List<String> ids);
}
