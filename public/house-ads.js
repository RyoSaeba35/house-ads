/*
 * House Ads web snippet.
 * Usage:
 *   <div data-house-ad data-placement="banner" data-app="portfolio"></div>
 *   <script src="https://YOUR-APP.up.railway.app/house-ads.js" defer></script>
 */
(function () {
  var script = document.currentScript;
  var BASE = (script && script.dataset.base) || (script ? new URL(script.src).origin : "");
  var cache = {};

  function pick(ads) {
    if (!ads.length) return null;
    var total = ads.reduce(function (sum, ad) { return sum + Math.max(ad.weight || 1, 1); }, 0);
    var r = Math.random() * total;
    for (var i = 0; i < ads.length; i++) {
      r -= Math.max(ads[i].weight || 1, 1);
      if (r < 0) return ads[i];
    }
    return ads[ads.length - 1];
  }

  function sendImpression(ad) {
    if (navigator.sendBeacon) {
      navigator.sendBeacon(ad.impression_url);
    } else {
      fetch(ad.impression_url, { method: "POST", mode: "no-cors", keepalive: true }).catch(function () {});
    }
  }

  function observe(el, ad) {
    var sent = false;
    function send() { if (!sent) { sent = true; sendImpression(ad); } }
    if (!("IntersectionObserver" in window)) return send();
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { send(); io.disconnect(); }
      });
    }, { threshold: 0.5 });
    io.observe(el);
  }

  function render(el, ad) {
    var link = document.createElement("a");
    link.href = ad.click_url;
    link.target = "_blank";
    link.rel = "sponsored noopener";
    link.style.cssText = "display:block;position:relative;line-height:0";

    var img = document.createElement("img");
    img.src = ad.image_url;
    img.alt = ad.alt || "";
    img.loading = "lazy";
    img.style.cssText = "display:block;width:100%;height:auto;aspect-ratio:" + ad.aspect_ratio + ";object-fit:cover;border-radius:8px";

    var label = document.createElement("span");
    label.textContent = ad.label;
    label.style.cssText = "position:absolute;top:4px;left:4px;font:11px/1.5 system-ui,sans-serif;color:#fff;background:rgba(0,0,0,.55);padding:0 6px;border-radius:4px";

    link.appendChild(img);
    link.appendChild(label);
    el.innerHTML = "";
    el.appendChild(link);
    observe(el, ad);
  }

  function load(el) {
    var placement = el.dataset.placement || "banner";
    var app = el.dataset.app || location.hostname;
    var key = placement + "|" + app;
    if (!cache[key]) {
      var url = BASE + "/api/v1/ads?placement=" + encodeURIComponent(placement) + "&app=" + encodeURIComponent(app);
      cache[key] = fetch(url)
        .then(function (res) { return res.ok ? res.json() : { ads: [] }; })
        .catch(function () { return { ads: [] }; });
    }
    cache[key].then(function (data) {
      var ad = pick(data.ads || []);
      if (ad) render(el, ad);
    });
  }

  function init() {
    document.querySelectorAll("[data-house-ad]").forEach(load);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
  window.HouseAds = { refresh: init };
})();
