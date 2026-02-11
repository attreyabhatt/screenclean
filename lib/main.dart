import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/theme.dart';
import 'features/ads/ad_service.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/rating/rating_policy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();
  final adService = AdService();

  await adService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        appVersionProvider.overrideWithValue(packageInfo.version),
        adServiceProvider.overrideWithValue(adService),
      ],
      child: const ScreenCleanApp(),
    ),
  );
}

class ScreenCleanApp extends StatelessWidget {
  const ScreenCleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ScreenClean - Screenshot Cleaner & Storage Saver',
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
