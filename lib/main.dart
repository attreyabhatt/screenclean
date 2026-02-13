import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final firebaseServices = await _initializeFirebaseServices();
  final appAnalytics = firebaseServices.analytics == null
      ? const NoopAppAnalytics()
      : FirebaseAppAnalytics(firebaseServices.analytics!);

  await adService.initialize();

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appVersionProvider.overrideWithValue(packageInfo.version),
            adServiceProvider.overrideWithValue(adService),
            appAnalyticsProvider.overrideWithValue(appAnalytics),
          ],
          child: ScreenCleanApp(analytics: firebaseServices.analytics),
        ),
      );
    },
    (error, stackTrace) {
      final crashlytics = firebaseServices.crashlytics;
      if (crashlytics != null) {
        unawaited(crashlytics.recordError(error, stackTrace, fatal: true));
      } else {
        debugPrint('Uncaught zone error: $error');
      }
    },
  );
}

Future<_FirebaseServices> _initializeFirebaseServices() async {
  try {
    await Firebase.initializeApp();
    final analytics = FirebaseAnalytics.instance;
    final crashlytics = FirebaseCrashlytics.instance;

    await analytics.setAnalyticsCollectionEnabled(true);
    await analytics.logAppOpen();
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      crashlytics.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(crashlytics.recordError(error, stackTrace, fatal: true));
      return true;
    };

    return _FirebaseServices(analytics: analytics, crashlytics: crashlytics);
  } catch (error) {
    debugPrint('Firebase initialization skipped: $error');
    return const _FirebaseServices();
  }
}

class _FirebaseServices {
  const _FirebaseServices({this.analytics, this.crashlytics});

  final FirebaseAnalytics? analytics;
  final FirebaseCrashlytics? crashlytics;
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
