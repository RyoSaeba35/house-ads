import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// One ad as returned by GET /api/v1/ads.
class HouseAd {
  const HouseAd({
    required this.id,
    required this.name,
    required this.placement,
    required this.imageUrl,
    required this.clickUrl,
    required this.impressionUrl,
    required this.weight,
    required this.label,
    required this.alt,
    required this.aspectRatio,
  });

  final int id;
  final String name;
  final String placement;
  final String imageUrl;
  final String clickUrl;
  final String impressionUrl;
  final int weight;
  final String label;
  final String alt;
  final double aspectRatio;

  factory HouseAd.fromJson(Map<String, dynamic> json) => HouseAd(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        placement: json['placement'] as String? ?? 'banner',
        imageUrl: json['image_url'] as String,
        clickUrl: json['click_url'] as String,
        impressionUrl: json['impression_url'] as String,
        weight: (json['weight'] as num?)?.toInt() ?? 1,
        label: json['label'] as String? ?? 'Publicité',
        alt: json['alt'] as String? ?? '',
        aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 6.0,
      );
}

class _CacheEntry {
  _CacheEntry(this.ads, this.ttl) : fetchedAt = DateTime.now();

  final List<HouseAd> ads;
  final Duration ttl;
  final DateTime fetchedAt;

  bool get isFresh => DateTime.now().difference(fetchedAt) < ttl;
}

/// Singleton client for your House Ads server.
///
/// Call once in main():
///   HouseAds.instance.init(baseUrl: 'https://xxx.up.railway.app', appKey: 'fidele');
class HouseAds {
  HouseAds._();
  static final HouseAds instance = HouseAds._();

  String? _baseUrl;
  String _appKey = 'unknown';
  http.Client _client = http.Client();
  Duration requestTimeout = const Duration(seconds: 8);

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<List<HouseAd>>> _inflight = {};
  final Random _random = Random();

  bool get isConfigured => _baseUrl != null;
  String get appKey => _appKey;

  void init({required String baseUrl, required String appKey, http.Client? client}) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _appKey = appKey;
    if (client != null) _client = client;
  }

  /// Ads for a placement, cached for the TTL sent by the server.
  /// Never throws: returns stale cache or an empty list on error.
  Future<List<HouseAd>> fetch(String placement, {bool forceRefresh = false}) {
    final base = _baseUrl;
    if (base == null) return Future.value(const <HouseAd>[]);

    final cached = _cache[placement];
    if (!forceRefresh && cached != null && cached.isFresh) {
      return Future.value(cached.ads);
    }

    return _inflight[placement] ??=
        _load(base, placement).whenComplete(() => _inflight.remove(placement));
  }

  Future<List<HouseAd>> _load(String base, String placement) async {
    final uri = Uri.parse('$base/api/v1/ads').replace(
      queryParameters: {'placement': placement, 'app': _appKey},
    );
    try {
      final res = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(requestTimeout);
      if (res.statusCode != 200) return _cache[placement]?.ads ?? const <HouseAd>[];

      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final ads = (body['ads'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HouseAd.fromJson)
          .toList(growable: false);
      final ttl = Duration(seconds: (body['ttl'] as num?)?.toInt() ?? 900);

      _cache[placement] = _CacheEntry(ads, ttl);
      return ads;
    } catch (_) {
      return _cache[placement]?.ads ?? const <HouseAd>[];
    }
  }

  /// Weighted random pick. [excludeId] avoids showing the same ad twice in a row.
  Future<HouseAd?> pick(String placement, {int? excludeId}) async {
    var ads = await fetch(placement);
    if (excludeId != null && ads.length > 1) {
      ads = ads.where((ad) => ad.id != excludeId).toList(growable: false);
    }
    if (ads.isEmpty) return null;

    final total = ads.fold<int>(0, (sum, ad) => sum + max(ad.weight, 1));
    var roll = _random.nextInt(total);
    for (final ad in ads) {
      roll -= max(ad.weight, 1);
      if (roll < 0) return ad;
    }
    return ads.last;
  }

  /// Fire and forget.
  void reportImpression(HouseAd ad) {
    unawaited(
      _client
          .post(Uri.parse(ad.impressionUrl))
          .timeout(requestTimeout)
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Opens the tracked click URL (the server counts it and redirects).
  Future<bool> open(HouseAd ad) async {
    try {
      return await launchUrl(Uri.parse(ad.clickUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  void clearCache() => _cache.clear();
}
