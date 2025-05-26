import 'dart:io';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static bool _isInitialized = false;

  // Ad Unit IDs for Android
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // Return your Android Banner Ad Unit ID here
      return 'ca-app-pub-6088367933724448/9979239822'; 
    } else if (Platform.isIOS) {
      // Return your iOS Banner Ad Unit ID here
      return 'ca-app-pub-6088367933724448/2993376686'; 
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get rewardedInterstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6088367933724448/9558785035'; 
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6088367933724448/8698255232'; 
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get appOpenAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6088367933724448/3637500246'; 
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6088367933724448/3620046736'; 
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Initialize Google Mobile Ads SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;

    await MobileAds.instance.initialize();
    _isInitialized = true;
  }

  // Banner Ads
  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner ad loaded: ${ad.adUnitId}');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    );
  }

  // Rewarded Interstitial Ads
  static Future<RewardedInterstitialAd?> loadRewardedInterstitialAd({
    Function(RewardItem reward)? onUserEarnedReward,
  }) async {
    try {
      final completer = Completer<RewardedInterstitialAd?>();

      await RewardedInterstitialAd.load(
        adUnitId: rewardedInterstitialAdUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            print('Rewarded interstitial ad loaded');
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                print(
                    'Failed to show rewarded interstitial ad: ${error.message}');
                ad.dispose();
              },
            );

            completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            print('Rewarded interstitial ad failed to load: ${error.message}');
            completer.complete(null);
          },
        ),
      );

      return await completer.future;
    } catch (e) {
      print('Error loading rewarded interstitial ad: $e');
      return null;
    }
  }

  // App Open Ads
  static Future<AppOpenAd?> loadAppOpenAd() async {
    try {
      AppOpenAd? myAppOpenAd;

      await AppOpenAd.load(
        adUnitId: appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) {
              myAppOpenAd = ad;
              myAppOpenAd!.show();
            },
            onAdFailedToLoad: (error) {}),
        orientation: AppOpenAd.orientationPortrait,
      );
    } catch (e) {
      print('Error loading app open ad: $e');
      return null;
    }
  }
}

// Utility class for Rewarded Interstitial Ads
class RewardedInterstitialAdManager {
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isAdLoaded = false;

  bool get isAdLoaded => _isAdLoaded;

  void loadAd({Function(RewardItem reward)? onUserEarnedReward}) async {
    await AdHelper.initialize();
    _rewardedInterstitialAd = await AdHelper.loadRewardedInterstitialAd();
    _isAdLoaded = _rewardedInterstitialAd != null;
  }

  void showAd({Function(RewardItem reward)? onUserEarnedReward}) {
    if (_isAdLoaded && _rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          if (onUserEarnedReward != null) {
            onUserEarnedReward(reward);
          }
        },
      );
      _isAdLoaded = false;
      _rewardedInterstitialAd = null;
      // Pre-load the next ad
      loadAd(onUserEarnedReward: onUserEarnedReward);
    }
  }

  void dispose() {
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
  }
}

// Utility class for App Open Ads
class AppOpenAdManager {
  AppOpenAd? _appOpenAd;
  bool _isAdLoaded = false;
  bool _isShowingAd = false;

  bool get isAdLoaded => _isAdLoaded;

  void loadAd() async {
    await AdHelper.initialize();
    _appOpenAd = await AdHelper.loadAppOpenAd();
    _isAdLoaded = _appOpenAd != null;
  }

  void showAdIfAvailable() {
    if (!_isShowingAd && _isAdLoaded && _appOpenAd != null) {
      _isShowingAd = true;
      _appOpenAd!.show();
    }
  }

  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}
