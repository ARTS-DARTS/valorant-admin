import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import 'ad_service.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _createAd());
    }
  }

  void _createAd() {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width.round();
    setState(() {
      _bannerAd = BannerAd(
        adUnitId: AdService.bannerUnitId,
        adSize: BannerAdSize.sticky(width: screenWidth),
        adRequest: const AdRequest(),
        // loadAd() is called automatically inside AdWidget via onPlatformViewCreated —
        // calling it manually before AdWidget is in the tree causes MissingPluginException.
        onAdLoaded: () => debugPrint('🟢 BANNER LOADED'),
        onAdFailedToLoad: (error) =>
            debugPrint('🔴 BANNER FAILED: code=${error.code} desc=${error.description}'),
        onAdClicked: () {},
        onLeftApplication: () {},
        onReturnedToApplication: () {},
        onImpression: (_) {},
      );
    });
  }

  @override
  void dispose() {
    _bannerAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: SizedBox(
        width: double.infinity,
        child: AdWidget(bannerAd: ad),
      ),
    );
  }
}
