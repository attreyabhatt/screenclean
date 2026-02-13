import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/theme.dart';
import 'features/ads/ad_service.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/rating/rating_policy.dart';
import 'shared/analytics/app_analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();
  final adService = AdService();
  final analytics = await _initializeFirebaseAnalytics();
  final appAnalytics = analytics == null
      ? const NoopAppAnalytics()
      : FirebaseAppAnalytics(analytics);

  await adService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        appVersionProvider.overrideWithValue(packageInfo.version),
        adServiceProvider.overrideWithValue(adService),
        appAnalyticsProvider.overrideWithValue(appAnalytics),
      ],
      child: ScreenCleanApp(analytics: analytics),
    ),
  );
}

Future<FirebaseAnalytics?> _initializeFirebaseAnalytics() async {
  try {
    await Firebase.initializeApp();
    final analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    await analytics.logAppOpen();
    return analytics;
  } catch (error) {
    debugPrint('Firebase Analytics initialization skipped: $error');
    return null;
  }
}

class ScreenCleanApp extends StatelessWidget {
  const ScreenCleanApp({super.key, this.analytics});

  final FirebaseAnalytics? analytics;

  @override
  Widget build(BuildContext context) {
    final navigatorObservers = analytics == null
        ? <NavigatorObserver>[]
        : <NavigatorObserver>[FirebaseAnalyticsObserver(analytics: analytics!)];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ScreenClean - Screenshot Cleaner & Storage Saver',
      theme: buildAppTheme(),
      navigatorObservers: navigatorObservers,
      home: const HomeScreen(),
    );
  }
}
