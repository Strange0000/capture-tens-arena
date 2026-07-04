'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "21d3551a91735db63524896edac1ff54",
"assets/AssetManifest.bin.json": "e9910e73801c46a31efd81c13e8f5af0",
"assets/AssetManifest.json": "53d19178b37e4963e57400cca87d68a4",
"assets/assets/images/app_icon.png": "ff665db61e8d8d5c328588ed8d4e4c65",
"assets/assets/images/capture_tens_bg.png": "d59672108760975de617b59ca32ce98d",
"assets/assets/images/game_bg.png": "2af22ede7533610787c4cc5f9b67ee60",
"assets/assets/images/game_table_bg.png": "e48f329d1cc10c748785c1c218baabb7",
"assets/assets/images/lobby_bg.png": "e831bcccfc30cbad9482de37e43c1f91",
"assets/assets/images/lobby_hero_logo.png": "913cf1c7cc2986d64d508557bcf446c6",
"assets/assets/images/login_bg.png": "4fd5e6a6fca6213c5ae8d923b67a7924",
"assets/assets/images/matchmaking_bg.png": "5cf91947caf391eb0f864863558fff8a",
"assets/assets/images/profile_banner.png": "5b3d01d3cda6ec45e32a5f92c9b887e7",
"assets/assets/images/profile_bg.png": "49d72356f0404a60cd2d41f810b24c76",
"assets/assets/images/rank_bronze.png": "232132b60f633b135159531e6b16a8bc",
"assets/assets/images/rank_diamond.png": "2fc8349c22fdc1ce3291da834f4b236e",
"assets/assets/images/rank_gold.png": "21f0c5562fcf746d7699196343178aca",
"assets/assets/images/rank_grandmaster.png": "4e0df896cd3bcbc5c84fd3b5cee66263",
"assets/assets/images/rank_iron.png": "1f68b2ca1e41f1ad02f33eafc0f7b016",
"assets/assets/images/rank_master.png": "837fc2210be53ce100883e1499969780",
"assets/assets/images/rank_platinum.png": "07d4b7b47bbe480d3ed5d05d130e51ed",
"assets/assets/images/rank_silver.png": "eb04e8a947ab143b02eb2ae9b388c39f",
"assets/assets/images/replay_bg.png": "88eb483e9d2ae59d897bbdb5cfecf4d5",
"assets/assets/images/splash_logo.png": "277c2c830599ff2a02c31cf225bd6005",
"assets/assets/images/suit_clubs.png": "445eddbfae4ba4ac06c882df2fa81147",
"assets/assets/images/suit_diamonds.png": "121442fc2951379591d2b62a03897d36",
"assets/assets/images/suit_hearts.png": "bcf9e975cd0267d940a7171d15312a97",
"assets/assets/images/suit_spades.png": "1527ace256c12cf1d962d0be50d69db7",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "9334a87ad93ff47acb1af5f864dd377a",
"assets/NOTICES": "951302a24b6197003a391efbacccd311",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"backend_config.js": "814d657c2c0a13760d62a6128ec6c850",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"flutter_bootstrap.js": "f92b585e0d23a28768578e4933f614fa",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "a736f0864869547e5b26fbf951b9a2fd",
"/": "a736f0864869547e5b26fbf951b9a2fd",
"main.dart.js": "e303919364737aed6bc5fcc1df3d6e0a",
"manifest.json": "776f968c49ed42f86a779216de188b2f",
"version.json": "0f3bb3f113ed2cadb7bbc0cc7b8b9542"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
