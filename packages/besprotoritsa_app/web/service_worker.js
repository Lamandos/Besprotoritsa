/*
 * Offline-first worker for the production bundle.
 *
 * The Flutter-generated bootstrap, engine and app targets are precached on
 * installation. Additional graphics and fonts loaded during play use the
 * cache-first fetch handler, so the game continues to launch and render when
 * the network is unavailable.
 */
const CACHE_PREFIX = 'besprotoritsa-web';
const CACHE_VERSION = 'v3';
const CACHE_NAME = `${CACHE_PREFIX}-${CACHE_VERSION}`;
const APP_SHELL = [
  './',
  './index.html',
  './flutter_bootstrap.js',
  './flutter.js',
  './main.dart.js',
  './main.dart.mjs',
  './main.dart.wasm',
  './version.json',
  './manifest.json',
  './favicon.png',
  './assets/AssetManifest.bin',
  './assets/AssetManifest.bin.json',
  './assets/FontManifest.json',
  './assets/NOTICES',
  './assets/shaders/ink_sparkle.frag',
  './assets/shaders/stretch_effect.frag',
  './canvaskit/canvaskit.js',
  './canvaskit/canvaskit.wasm',
  './canvaskit/skwasm.js',
  './canvaskit/skwasm.wasm',
  './canvaskit/skwasm_heavy.js',
  './canvaskit/skwasm_heavy.wasm',
  './canvaskit/wimp.js',
  './canvaskit/wimp.wasm',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
];
const ASSET_PATH = /(?:^|\/)(?:assets\/|canvaskit\/|skwasm\/)/;
const CACHEABLE_EXTENSION =
  /\.(?:avif|bmp|gif|ico|jpe?g|json|mjs|js|otf|png|svg|ttf|wasm|webp|woff2?)$/;

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

function isSameOrigin(request) {
  return new URL(request.url).origin === self.location.origin;
}

function isGameAsset(request) {
  const { pathname } = new URL(request.url);
  return ASSET_PATH.test(pathname) || CACHEABLE_EXTENSION.test(pathname);
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);
  if (cached) return cached;

  const response = await fetch(request);
  if (response.ok) await cache.put(request, response.clone());
  return response;
}

async function navigationResponse(request) {
  try {
    const response = await fetch(request);
    const cache = await caches.open(CACHE_NAME);
    if (response.ok) await cache.put('./index.html', response.clone());
    return response;
  } catch (_) {
    return (await caches.match('./index.html')) || (await caches.match('./'));
  }
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET' || !isSameOrigin(request)) return;

  if (request.mode === 'navigate') {
    event.respondWith(navigationResponse(request));
  } else if (isGameAsset(request)) {
    event.respondWith(cacheFirst(request));
  }
});
