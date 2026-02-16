import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const bool kEnableAds = bool.fromEnvironment('ENABLE_ADS', defaultValue: false);
const String kAdmobBannerUnitId = String.fromEnvironment(
  'ADMOB_BANNER_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/9214589741', // Test ad unit
);

final adServiceProvider = Provider<AdService>(
  (ref) => throw UnimplementedError('adServiceProvider must be overridden'),
);

class AdService {
  bool _initialized = false;

  bool get isBannerEnabled => kEnableAds && kAdmobBannerUnitId.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized || !kEnableAds) {
      return;
    }
    await MobileAds.instance.initialize();
    _initialized = true;
  }
}

class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kEnableAds || kAdmobBannerUnitId.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAd();
    });
  }

  Future<void> _loadAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (!mounted || adaptiveSize == null) {
      return;
    }

    final ad = BannerAd(
      adUnitId: kAdmobBannerUnitId,
      request: const AdRequest(),
      size: adaptiveSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
        },
      ),
    );

    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
