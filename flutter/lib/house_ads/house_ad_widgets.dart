import 'dart:async';

import 'package:flutter/material.dart';

import 'house_ads.dart';

/// Banner or square ad. Renders nothing until an ad is available.
///
///   HouseAdBanner()                                  // banner
///   HouseAdBanner(placement: 'square')               // square
///   HouseAdBanner(rotateEvery: Duration(seconds: 45))
class HouseAdBanner extends StatefulWidget {
  const HouseAdBanner({
    super.key,
    this.placement = 'banner',
    this.rotateEvery,
    this.borderRadius = 8,
    this.showLabel = true,
    this.placeholder,
    this.onLoaded,
    this.onNoAd,
  });

  final String placement;
  final Duration? rotateEvery;
  final double borderRadius;
  final bool showLabel;
  final Widget? placeholder;
  final ValueChanged<HouseAd>? onLoaded;
  final VoidCallback? onNoAd;

  @override
  State<HouseAdBanner> createState() => _HouseAdBannerState();
}

class _HouseAdBannerState extends State<HouseAdBanner> {
  HouseAd? _ad;
  bool _impressionSent = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    final every = widget.rotateEvery;
    if (every != null) {
      _timer = Timer.periodic(every, (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final ad = await HouseAds.instance.pick(widget.placement, excludeId: _ad?.id);
    if (!mounted) return;
    if (ad == null) {
      if (_ad == null) widget.onNoAd?.call();
      return;
    }
    if (ad.id == _ad?.id) return;
    setState(() {
      _ad = ad;
      _impressionSent = false;
    });
  }

  void _onImageShown(HouseAd ad) {
    if (_impressionSent || !mounted || _ad?.id != ad.id) return;
    _impressionSent = true;
    HouseAds.instance.reportImpression(ad);
    widget.onLoaded?.call(ad);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return widget.placeholder ?? const SizedBox.shrink();

    return Semantics(
      button: true,
      label: ad.alt,
      child: AspectRatio(
        aspectRatio: ad.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: GestureDetector(
            onTap: () => HouseAds.instance.open(ad),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  ad.imageUrl,
                  key: ValueKey(ad.id),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (frame != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _onImageShown(ad));
                    }
                    return child;
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
                if (widget.showLabel)
                  Positioned(top: 4, left: 4, child: HouseAdLabel(ad.label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small "Publicité" chip (French law requires ads to be identified).
class HouseAdLabel extends StatelessWidget {
  const HouseAdLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Full-screen interstitial. Returns false if no ad was available.
///
///   final shown = await showHouseInterstitial(context);
Future<bool> showHouseInterstitial(
  BuildContext context, {
  String placement = 'interstitial',
  Duration closeDelay = const Duration(seconds: 3),
}) async {
  final ad = await HouseAds.instance.pick(placement);
  if (ad == null || !context.mounted) return false;

  // Download the image first so the dialog never opens blank.
  var imageOk = true;
  await precacheImage(NetworkImage(ad.imageUrl), context, onError: (_, __) => imageOk = false);
  if (!imageOk || !context.mounted) return false;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    pageBuilder: (dialogContext, _, __) => _HouseInterstitial(ad: ad, closeDelay: closeDelay),
  );
  return true;
}

class _HouseInterstitial extends StatefulWidget {
  const _HouseInterstitial({required this.ad, required this.closeDelay});

  final HouseAd ad;
  final Duration closeDelay;

  @override
  State<_HouseInterstitial> createState() => _HouseInterstitialState();
}

class _HouseInterstitialState extends State<_HouseInterstitial> {
  late int _secondsLeft = widget.closeDelay.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HouseAds.instance.reportImpression(widget.ad);
    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final canClose = _secondsLeft <= 0;

    return PopScope(
      canPop: canClose,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: ad.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () => HouseAds.instance.open(ad),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(ad.imageUrl, fit: BoxFit.cover),
                            Positioned(top: 8, left: 8, child: HouseAdLabel(ad.label)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: canClose
                    ? IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Text(
                          '$_secondsLeft',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
