import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await MobileAds.instance.initialize();
  runApp(const PuzzleApp());
}

class PuzzleApp extends StatelessWidget {
  const PuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameWebViewScreen(),
    );
  }
}

class GameWebViewScreen extends StatefulWidget {
  const GameWebViewScreen({super.key});

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  late final WebViewController _controller;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  // Test kimlikleri: Yayin oncesi gercek AdMob birim kimliklerinizle degistirin.
  static const String _testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadInterstitialAd();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0E0A07))
      ..addJavaScriptChannel(
        'AdBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJsMessage(message.message);
        },
      )
      ..loadFlutterAsset('assets/index.html');
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _testRewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _testInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _sendToJs(String eventName, Map<String, dynamic> payload) {
    final jsonPayload = jsonEncode(payload);
    _controller.runJavaScript(
      "window.onFlutterAdEvent && window.onFlutterAdEvent('$eventName', $jsonPayload);",
    );
  }

  void _handleJsMessage(String rawMessage) {
    try {
      final data = jsonDecode(rawMessage) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      if (type == 'showRewarded') {
        final purpose = data['purpose'] as String? ?? 'extra_moves';
        if (_rewardedAd != null) {
          final ad = _rewardedAd!;
          _rewardedAd = null;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedAd();
              _sendToJs('ad_failed', {'purpose': purpose});
            },
          );
          ad.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              _sendToJs('reward_earned', {'purpose': purpose});
            },
          );
        } else {
          _loadRewardedAd();
          _sendToJs('ad_not_ready', {'purpose': purpose});
        }
      } else if (type == 'showInterstitial') {
        if (_interstitialAd != null) {
          final ad = _interstitialAd!;
          _interstitialAd = null;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
              _sendToJs('interstitial_closed', {});
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
              _sendToJs('interstitial_closed', {});
            },
          );
          ad.show();
        } else {
          _loadInterstitialAd();
          _sendToJs('interstitial_closed', {});
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0A07),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
