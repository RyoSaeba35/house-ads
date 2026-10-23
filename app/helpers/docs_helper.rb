module DocsHelper
  def code_block(code, lang: nil)
    tag.div(class: "code") do
      safe_join([
        tag.div(class: "code-head") do
          safe_join([tag.span(lang.to_s, class: "code-lang"),
                     tag.button("Copy", type: "button", class: "copy-btn", data: { copy: true })])
        end,
        tag.pre(tag.code(code.strip))
      ])
    end
  end

  def doc_snippets(base)
    {
      pubspec: <<~BASH,
        flutter pub add http url_launcher
      BASH

      manifest: <<~XML,
        <!-- android/app/src/main/AndroidManifest.xml, inside <manifest> -->
        <queries>
          <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
          </intent>
        </queries>
      XML

      init: <<~DART,
        import 'package:flutter/material.dart';
        import 'house_ads/house_ads.dart';

        void main() {
          WidgetsFlutterBinding.ensureInitialized();
          HouseAds.instance.init(
            baseUrl: '#{base}',
            appKey: 'fidele', // one key per app, used in your stats
          );
          runApp(const MyApp());
        }
      DART

      widgets: <<~DART,
        import 'house_ads/house_ad_widgets.dart';

        // Banner (full width, height from the image ratio)
        const HouseAdBanner()

        // Square, rotating every 45 s
        HouseAdBanner(placement: 'square', rotateEvery: const Duration(seconds: 45))

        // Fixed height banner (image is cropped to fit)
        const SizedBox(height: 60, child: HouseAdBanner())

        // Full screen interstitial, close button after 3 s
        final shown = await showHouseInterstitial(context);
      DART

      fallback: <<~DART,
        bool _levelPlayFailed = false;

        // LevelPlay banner listener
        onAdLoadFailed: (error) => setState(() => _levelPlayFailed = true),

        // build()
        _levelPlayFailed ? const HouseAdBanner() : levelPlayBannerWidget,

        // Interstitial: house ad when the network one isn't ready
        // (use your LevelPlay "ad ready" check here)
        if (!levelPlayInterstitialReady) {
          await showHouseInterstitial(context);
        }
      DART

      web: <<~HTML,
        <div data-house-ad data-placement="banner" data-app="portfolio"></div>
        <script src="#{base}/house-ads.js" defer></script>
      HTML

      web_fetch: <<~JS,
        const res = await fetch('#{base}/api/v1/ads?placement=banner&app=portfolio');
        const { ads } = await res.json();
        const ad = ads[Math.floor(Math.random() * ads.length)]; // or weighted by ad.weight

        // render <a href={ad.click_url}><img src={ad.image_url} alt={ad.alt}></a>
        // then once visible:
        navigator.sendBeacon(ad.impression_url);
      JS

      list: <<~BASH,
        curl "#{base}/api/v1/ads?placement=banner&app=fidele"
      BASH

      impression: <<~BASH,
        curl -X POST "#{base}/api/v1/ads/1/impression?app=fidele&placement=banner"
      BASH

      response: <<~JSON
        {
          "ads": [
            {
              "id": 1,
              "name": "Sideby",
              "placement": "banner",
              "weight": 10,
              "label": "Publicité",
              "alt": "Sideby",
              "aspect_ratio": 6.0,
              "image_url": "#{base}/rails/active_storage/blobs/proxy/...",
              "click_url": "#{base}/r/1?app=fidele&placement=banner",
              "impression_url": "#{base}/api/v1/ads/1/impression?app=fidele&placement=banner"
            }
          ],
          "ttl": 900
        }
      JSON
    }
  end
end
