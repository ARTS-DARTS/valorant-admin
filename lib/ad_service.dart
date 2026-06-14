import 'package:yandex_mobileads/mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'badge_service.dart';

/// Сервис рекламы — Яндекс РСЯ (yandex_mobileads ^7.18.0)
///
///   R-M-19299423-1 → Баннер
///   R-M-19299423-2 → Межстраничная
///   R-M-19299423-3 → Rewarded (разблокировка видео)
class AdService {
  AdService._();

  static const _bannerUnitId       = 'R-M-19299423-1';
  static const _interstitialUnitId = 'R-M-19299423-2';
  static const _rewardedUnitId     = 'R-M-19299423-3';

  static bool _initialized = false;
  static bool _isSponsor = false;

  static Future<void> setSponsorStatus(bool isSponsor) async {
    _isSponsor = isSponsor;
  }

  static bool get isSponsor => _isSponsor;

  // Межстраничная
  static InterstitialAd? _interstitialAd;
  static Future<InterstitialAdLoader>? _interstitialLoaderFuture;

  // Rewarded
  static RewardedAd? _rewardedAd;
  static Future<RewardedAdLoader>? _rewardedLoaderFuture;

  // ─── Инициализация ────────────────────────────────────────────────────────

  static void _logAdEvent(String type) {
    final uid = AuthService.userId;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('ad_events').add({
      'type': type,
      'uid': uid,
      'ts': FieldValue.serverTimestamp(),
    }).ignore();
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.initialize();
    _initialized = true;
    BadgeService.currentUserIsSponsor().then((v) => _isSponsor = v);
    _loadInterstitial();
    _loadRewarded();
  }

  // ─── Баннер ───────────────────────────────────────────────────────────────
  // Создаётся в AdBannerWidget — коллбэки передаются прямо в конструктор BannerAd

  static String get bannerUnitId => _bannerUnitId;

  // ─── Межстраничная ────────────────────────────────────────────────────────

  static void _loadInterstitial() {
    _interstitialLoaderFuture = InterstitialAdLoader.create(
      onAdLoaded: (InterstitialAd ad) {
        _interstitialAd = ad;
      },
      onAdFailedToLoad: (error) {
        _interstitialLoaderFuture = null;
        Future.delayed(const Duration(seconds: 30), _loadInterstitial);
      },
    );

    _interstitialLoaderFuture!.then((loader) {
      loader.loadAd(
        adRequestConfiguration: AdRequestConfiguration(
          adUnitId: _interstitialUnitId,
        ),
      );
    });
  }

  static void showInterstitial({void Function()? onDismissed}) {
    if (_isSponsor) { onDismissed?.call(); return; }
    final ad = _interstitialAd;
    if (ad == null) {
      onDismissed?.call();
      return;
    }
    _interstitialAd = null;

    ad.setAdEventListener(
      eventListener: InterstitialAdEventListener(
        onAdShown: () { _logAdEvent('interstitial_shown'); },
        onAdFailedToShow: (_) {
          ad.destroy();
          _loadInterstitial();
          onDismissed?.call();
        },
        onAdDismissed: () {
          ad.destroy();
          _loadInterstitial();
          onDismissed?.call();
        },
        onAdClicked: () {},
        onAdImpression: (_) {},
      ),
    );
    ad.show();
  }

  // ─── Rewarded ─────────────────────────────────────────────────────────────

  static bool get isRewardedReady => _rewardedAd != null;

  static void _loadRewarded() {
    _rewardedLoaderFuture = RewardedAdLoader.create(
      onAdLoaded: (RewardedAd ad) {
        _rewardedAd = ad;
      },
      onAdFailedToLoad: (error) {
        _rewardedLoaderFuture = null;
        Future.delayed(const Duration(seconds: 30), _loadRewarded);
      },
    );

    _rewardedLoaderFuture!.then((loader) {
      loader.loadAd(
        adRequestConfiguration: AdRequestConfiguration(
          adUnitId: _rewardedUnitId,
        ),
      );
    });
  }

  /// Показать rewarded рекламу.
  /// [onRewarded]  — досмотрел → даём награду.
  /// [onDismissed] — закрыл раньше → без награды.
  /// [onNotReady]  — реклама не загружена.
  static void showRewarded({
    required void Function() onRewarded,
    void Function()? onDismissed,
    void Function()? onNotReady,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      onNotReady?.call();
      _loadRewarded();
      return;
    }
    _rewardedAd = null;

    bool rewarded = false;
    bool adShown = false;

    ad.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown: () { adShown = true; _logAdEvent('rewarded_shown'); },
        onAdFailedToShow: (_) {
          ad.destroy();
          _loadRewarded();
          onDismissed?.call();
        },
        onAdDismissed: () {
          ad.destroy();
          _loadRewarded();
          // Require both ad was shown AND reward was earned to prevent
          // SDK quirks that fire onRewarded without displaying the ad.
          if (rewarded && adShown) {
            onRewarded();
          } else {
            _logAdEvent('rewarded_skipped');
            onDismissed?.call();
          }
        },
        onAdClicked: () {},
        onAdImpression: (_) {},
        onRewarded: (_) {
          rewarded = true;
          _logAdEvent('rewarded_completed');
        },
      ),
    );
    ad.show();
  }
}
