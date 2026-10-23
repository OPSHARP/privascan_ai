import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'vip_service.dart';

class AdService {
  static final AdService instance = AdService._();
  AdService._();

  // ── Ad Unit IDs ──────────────────────────────────────────────
  // In debug mode, use Google's official test ad unit IDs.
  // In release mode, use your real production ad unit IDs.
  //
  // IMPORTANT: Replace the production IDs below with your real AdMob ad unit IDs
  // from https://admob.google.com before publishing to the Play Store/App Store.
  // Test IDs will ONLY show test ads in debug mode.

  static String get bannerAdUnitId => Platform.isAndroid
      ? (kDebugMode
          ? 'ca-app-pub-3940256099942544/6300978111' // Test banner
          : 'YOUR_ANDROID_BANNER_AD_UNIT_ID') // Replace with your production banner ID
      : (kDebugMode
          ? 'ca-app-pub-3940256099942544/2934735716' // Test banner
          : 'YOUR_IOS_BANNER_AD_UNIT_ID'); // Replace with your production banner ID

  static String get appOpenAdUnitId => Platform.isAndroid
      ? (kDebugMode
          ? 'ca-app-pub-3940256099942544/9257395921' // Test app open
          : 'YOUR_ANDROID_APP_OPEN_AD_UNIT_ID') // Replace with your production app open ID
      : (kDebugMode
          ? 'ca-app-pub-3940256099942544/5662855259' // Test app open
          : 'YOUR_IOS_APP_OPEN_AD_UNIT_ID'); // Replace with your production app open ID

  static String get interstitialAdUnitId => Platform.isAndroid
      ? (kDebugMode
          ? 'ca-app-pub-3940256099942544/1033173712' // Test interstitial
          : 'YOUR_ANDROID_INTERSTITIAL_AD_UNIT_ID') // Replace with your production interstitial ID
      : (kDebugMode
          ? 'ca-app-pub-3940256099942544/4411468910' // Test interstitial
          : 'YOUR_IOS_INTERSTITIAL_AD_UNIT_ID'); // Replace with your production interstitial ID

  // ── State ───────────────────────────────────────────────────
  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;
  bool _isInitialized = false;
  bool _isAppOpenAdLoading = false;
  bool _isInterstitialAdLoading = false;
  DateTime? _lastAdShownTime;
  int _appOpenRetryCount = 0;
  int _interstitialRetryCount = 0;
  static const int _maxRetries = 3;

  // ── Init ────────────────────────────────────────────────────
  Future<void> init() async {
    if (_isInitialized) return;

    debugPrint('[AdService] Requesting UMP Consent...');
    
    final completer = Completer<void>();

    final params = ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
      ),
    );

    ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
      debugPrint('[AdService] Consent info updated.');
      
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        ConsentForm.loadAndShowConsentFormIfRequired((error) async {
          if (error != null) {
            debugPrint('[AdService] Consent form error: ${error.message}');
          }
          await _initializeAds();
          if (!completer.isCompleted) completer.complete();
        });
      } else {
        debugPrint('[AdService] Consent form not available.');
        await _initializeAds();
        if (!completer.isCompleted) completer.complete();
      }
    }, (FormError error) async {
      debugPrint('[AdService] Consent update error: ${error.message}');
      await _initializeAds(); // fallback
      if (!completer.isCompleted) completer.complete();
    });

    return completer.future;
  }

  Future<void> _initializeAds() async {
    if (_isInitialized) return;
    debugPrint('[AdService] Initializing MobileAds SDK...');

    final initStatus = await MobileAds.instance.initialize();
    _isInitialized = true;

    debugPrint('[AdService] MobileAds SDK initialized.');
    initStatus.adapterStatuses.forEach((adapter, status) {
      debugPrint(
        '[AdService]   Adapter: $adapter - '
        'state=${status.state}, '
        'description=${status.description}',
      );
    });

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: [],
      ),
    );
    debugPrint('[AdService] Test device IDs configured.');

    _checkAdBlocker();
  }

  Future<void> _checkAdBlocker() async {
    try {
      // First verify general internet connectivity to avoid false positives when offline
      final connectivityCheck = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));
      if (connectivityCheck.isEmpty || connectivityCheck[0].rawAddress.isEmpty) {
        return; // Device is offline, do not show ad-blocker warning
      }

      final result = await InternetAddress.lookup(
        'googleads.g.doubleclick.net',
      ).timeout(const Duration(seconds: 3));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        _showAdBlockToast();
      }
    } catch (_) {
      // If general connectivity lookup fails or times out, user is offline.
      // Do not accuse the user of running an ad-blocker.
    }
  }

  void _showAdBlockToast() {
    debugPrint('[AdService] ⚠️ Ad blocker / DNS filter detected.');
    Fluttertoast.showToast(
      msg: "Please disable ad blocker or DNS filter to use this app",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.redAccent,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // ── App Open Ad ─────────────────────────────────────────────
  /// Loads an App Open ad and returns true when the ad is ready.
  /// Returns false if the ad fails to load.
  ///
  /// NOTE: AppOpenAd.load() returns its Future immediately, BEFORE the ad
  /// is actually loaded. The onAdLoaded/onAdFailedToLoad callbacks fire
  /// asynchronously. We use a Completer to bridge this into a proper Future.
  Future<bool> loadAppOpenAd() async {
    if (VipService.instance.isVip) return false;
    if (_appOpenAd != null) return true; // Already loaded
    if (_isAppOpenAdLoading) return false; // Already in progress

    _isAppOpenAdLoading = true;
    debugPrint('[AdService] Loading App Open ad (unit: $appOpenAdUnitId)...');

    final completer = Completer<bool>();

    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] ✅ App Open ad loaded successfully.');
          _isAppOpenAdLoading = false;
          _appOpenRetryCount = 0;
          _appOpenAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint('[AdService] App Open ad is showing.');
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('[AdService] App Open ad dismissed.');
              ad.dispose();
              _appOpenAd = null;
              _lastAdShownTime = DateTime.now();
              loadAppOpenAd(); // Pre-load the next one
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint(
                  '[AdService] App Open ad failed to show: ${error.message}');
              ad.dispose();
              _appOpenAd = null;
            },
          );
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoading = false;
          debugPrint(
            '[AdService] ❌ App Open ad failed to load: '
            'code=${error.code}, domain=${error.domain}, '
            'message=${error.message}',
          );
          if (!completer.isCompleted) completer.complete(false);

          // Retry with exponential backoff
          _appOpenRetryCount++;
          if (_appOpenRetryCount <= _maxRetries) {
            final delay = Duration(seconds: 10 * _appOpenRetryCount);
            debugPrint(
              '[AdService] Retrying App Open ad load in ${delay.inSeconds}s '
              '(attempt $_appOpenRetryCount/$_maxRetries)...',
            );
            Future.delayed(delay, () {
              if (_appOpenAd == null) loadAppOpenAd();
            });
          } else {
            debugPrint(
              '[AdService] App Open ad max retries ($_maxRetries) reached. '
              'Giving up until next explicit load call.',
            );
          }
        },
      ),
    );

    return completer.future;
  }

  Future<bool> showAppOpenAd() async {
    if (VipService.instance.isVip) {
      debugPrint('[AdService] VIP active — App Open ad suppressed (100% ad-free).');
      return false;
    }
    if (_appOpenAd == null) {
      debugPrint('[AdService] No App Open ad ready, attempting to load...');
      final loaded = await loadAppOpenAd();
      if (!loaded) {
        debugPrint('[AdService] App Open ad could not be loaded, skipping.');
        return false;
      }
    }
    if (_appOpenAd != null) {
      debugPrint('[AdService] Showing App Open ad...');
      _appOpenAd!.show();
      return true;
    }
    return false;
  }

  // ── Interstitial Ad ─────────────────────────────────────────
  /// Loads an Interstitial ad and returns true when ready.
  /// Uses Completer to properly await the callback-based load API.
  Future<bool> loadInterstitialAd() async {
    if (VipService.instance.isVip) return false;
    if (_interstitialAd != null) return true;
    if (_isInterstitialAdLoading) return false;

    _isInterstitialAdLoading = true;
    debugPrint(
        '[AdService] Loading Interstitial ad (unit: $interstitialAdUnitId)...');

    final completer = Completer<bool>();

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] ✅ Interstitial ad loaded successfully.');
          _isInterstitialAdLoading = false;
          _interstitialRetryCount = 0;
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint('[AdService] Interstitial ad is showing.');
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('[AdService] Interstitial ad dismissed.');
              ad.dispose();
              _interstitialAd = null;
              _lastAdShownTime = DateTime.now();
              loadInterstitialAd(); // Pre-load the next one
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint(
                  '[AdService] Interstitial ad failed to show: ${error.message}');
              ad.dispose();
              _interstitialAd = null;
            },
          );
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoading = false;
          debugPrint(
            '[AdService] ❌ Interstitial ad failed to load: '
            'code=${error.code}, domain=${error.domain}, '
            'message=${error.message}',
          );
          if (!completer.isCompleted) completer.complete(false);

          // Retry with exponential backoff
          _interstitialRetryCount++;
          if (_interstitialRetryCount <= _maxRetries) {
            final delay = Duration(seconds: 10 * _interstitialRetryCount);
            debugPrint(
              '[AdService] Retrying Interstitial ad load in ${delay.inSeconds}s '
              '(attempt $_interstitialRetryCount/$_maxRetries)...',
            );
            Future.delayed(delay, () {
              if (_interstitialAd == null) loadInterstitialAd();
            });
          } else {
            debugPrint(
              '[AdService] Interstitial ad max retries ($_maxRetries) reached. '
              'Giving up until next explicit load call.',
            );
          }
        },
      ),
    );

    return completer.future;
  }

  Future<bool> showInterstitialAd() async {
    if (VipService.instance.isVip) {
      debugPrint('[AdService] VIP active — Interstitial ad suppressed (100% ad-free).');
      return false;
    }
    if (_lastAdShownTime != null) {
      final difference = DateTime.now().difference(_lastAdShownTime!);
      if (difference.inSeconds < 30) {
        debugPrint(
          '[AdService] Interstitial skipped — cooldown '
          '(${30 - difference.inSeconds}s remaining).',
        );
        return false;
      }
    }

    if (_interstitialAd == null) {
      debugPrint('[AdService] No Interstitial ad ready, attempting to load...');
      final loaded = await loadInterstitialAd();
      if (!loaded) {
        debugPrint(
            '[AdService] Interstitial ad could not be loaded, skipping.');
        return false;
      }
    }
    if (_interstitialAd != null) {
      debugPrint('[AdService] Showing Interstitial ad...');
      _interstitialAd!.show();
      return true;
    }
    return false;
  }

  // ── Cleanup ─────────────────────────────────────────────────
  void dispose() {
    _appOpenAd?.dispose();
    _interstitialAd?.dispose();
  }
}

/// A self-contained banner ad widget that manages its own lifecycle.
/// Uses adaptive banner sizing for better fill rates on all screen sizes.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (VipService.instance.isVip) return;
    if (_bannerAd == null) {
      _loadBanner();
    }
  }

  void _loadBanner() async {
    if (VipService.instance.isVip) return;
    final width = MediaQuery.of(context).size.width.truncate();
    // Use standard anchored adaptive banner. Falls back to 320x50 if adaptive fails.
    AdSize? adSize;
    try {
      adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    } catch (_) {
      adSize = AdSize.banner;
    }
    adSize ??= AdSize.banner; // fallback to standard 320x50

    if (!mounted) return;

    debugPrint(
      '[AdService] Loading Banner ad (unit: ${AdService.bannerAdUnitId}, '
      'size: ${adSize.width}x${adSize.height})...',
    );
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdService] ✅ Banner ad loaded successfully.');
          _retryCount = 0;
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[AdService] ❌ Banner ad failed to load: '
            'code=${error.code}, domain=${error.domain}, '
            'message=${error.message}',
          );
          ad.dispose();
          _bannerAd = null;
          // Retry with exponential backoff, up to max retries
          _retryCount++;
          if (_retryCount <= _maxRetries) {
            final delay = Duration(seconds: 15 * _retryCount);
            debugPrint(
              '[AdService] Retrying Banner ad load in ${delay.inSeconds}s '
              '(attempt $_retryCount/$_maxRetries)...',
            );
            Future.delayed(delay, () {
              if (mounted && _bannerAd == null && !VipService.instance.isVip) {
                _loadBanner();
              }
            });
          } else {
            debugPrint(
              '[AdService] Banner ad max retries ($_maxRetries) reached.',
            );
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VipService.instance.vipStatusNotifier,
      builder: (context, isVip, _) {
        if (isVip) {
          return const SizedBox.shrink();
        }

        if (!_isLoaded || _bannerAd == null) {
          return SafeArea(
            bottom: true,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: 50, // Standard minimum banner height placeholder
            ),
          );
        }
        return SafeArea(
          bottom: true,
          child: SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        );
      },
    );
  }
}
