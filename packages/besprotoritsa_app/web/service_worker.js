/*
 * Offline-first worker for the production bundle.
 *
 * The Flutter-generated bootstrap, engine, app targets and all current game
 * illustrations are precached on installation. Fonts and any assets added to
 * the app later use the cache-first fetch handler when they are requested.
 */
const CACHE_PREFIX = 'besprotoritsa-web';
const CACHE_VERSION = 'v9';
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
  './assets/assets/images/cabin_noise_scene.png',
  './assets/assets/images/card-icons/monsters-02-01.webp',
  './assets/assets/images/card-icons/monsters-02-02.webp',
  './assets/assets/images/card-icons/monsters-02-03.webp',
  './assets/assets/images/card-icons/monsters-02-04.webp',
  './assets/assets/images/card-icons/monsters-02-05.webp',
  './assets/assets/images/card-icons/monsters-02-06.webp',
  './assets/assets/images/card-icons/monsters-02-07.webp',
  './assets/assets/images/card-icons/monsters-02-08.webp',
  './assets/assets/images/card-icons/monsters-03-01.webp',
  './assets/assets/images/card-icons/monsters-03-02.webp',
  './assets/assets/images/card-icons/monsters-03-03.webp',
  './assets/assets/images/card-icons/monsters-03-04.webp',
  './assets/assets/images/card-icons/monsters-03-05.webp',
  './assets/assets/images/card-icons/monsters-03-06.webp',
  './assets/assets/images/card-icons/monsters-03-07.webp',
  './assets/assets/images/card-icons/monsters-03-08.webp',
+  './assets/assets/images/card-art/condition-adrenaline.webp',
  './assets/assets/images/card-art/condition-concussion.webp',
  './assets/assets/images/card-art/condition-fracture.webp',
  './assets/assets/images/card-art/condition-malaise.webp',
  './assets/assets/images/card-art/condition-nausea.webp',
  './assets/assets/images/card-art/condition-shortness-of-breath.webp',
  './assets/assets/images/card-art/item-alarm-bot.webp',
  './assets/assets/images/card-art/item-armor-vest.webp',
  './assets/assets/images/card-art/item-c6-car-courier.webp',
  './assets/assets/images/card-art/item-camouflage.webp',
  './assets/assets/images/card-art/item-circular-saw.webp',
  './assets/assets/images/card-art/item-coveralls.webp',
  './assets/assets/images/card-art/item-engineer-coveralls.webp',
  './assets/assets/images/card-art/item-exo-gloves.webp',
  './assets/assets/images/card-art/item-f1t-b07.webp',
  './assets/assets/images/card-art/item-flamethrower.webp',
  './assets/assets/images/card-art/item-frying-pan.webp',
  './assets/assets/images/card-art/item-ghb-dtn.webp',
  './assets/assets/images/card-art/item-gtu-b1c4.webp',
  './assets/assets/images/card-art/item-guard-suit.webp',
  './assets/assets/images/card-art/item-h3-al.webp',
  './assets/assets/images/card-art/item-hauler-uniform.webp',
  './assets/assets/images/card-art/item-implant-agility.webp',
  './assets/assets/images/card-art/item-implant-endurance.webp',
  './assets/assets/images/card-art/item-implant-repair.webp',
  './assets/assets/images/card-art/item-implant-science.webp',
  './assets/assets/images/card-art/item-implant-strength.webp',
  './assets/assets/images/card-art/item-knife.webp',
  './assets/assets/images/card-art/item-lab-coat.webp',
  './assets/assets/images/card-art/item-laboratory-suit.webp',
  './assets/assets/images/card-art/item-laser-cutter.webp',
  './assets/assets/images/card-art/item-laser-scalpel.webp',
  './assets/assets/images/card-art/item-last-chance.webp',
  './assets/assets/images/card-art/item-load-bearing-vest.webp',
  './assets/assets/images/card-art/item-nailgun.webp',
  './assets/assets/images/card-art/item-pipe-wrench.webp',
  './assets/assets/images/card-art/item-pneumo-cannon.webp',
  './assets/assets/images/card-art/item-prot2-ct.webp',
  './assets/assets/images/card-art/item-prot3-ct.webp',
  './assets/assets/images/card-art/item-r69-nic3.webp',
  './assets/assets/images/card-art/item-sc0-u7.webp',
  './assets/assets/images/card-art/item-sc13-nc3.webp',
  './assets/assets/images/card-art/item-shirt.webp',
  './assets/assets/images/card-art/item-shooter-helmet.webp',
  './assets/assets/images/card-art/item-spacesuit.webp',
  './assets/assets/images/card-art/item-t-shirt.webp',
  './assets/assets/images/card-art/item-tank-top.webp',
  './assets/assets/images/card-art/item-ultrasonic-hammer.webp',
  './assets/assets/images/card-art/monster-boil.webp',
  './assets/assets/images/card-art/monster-drekovac.webp',
  './assets/assets/images/card-art/monster-ghoul.webp',
  './assets/assets/images/card-art/monster-leshy.webp',
  './assets/assets/images/card-art/monster-likho.webp',
  './assets/assets/images/card-art/monster-mother.webp',
  './assets/assets/images/card-art/monster-nest.webp',
  './assets/assets/images/card-art/monster-pack.webp',
  './assets/assets/images/card-art/monster-plagued.webp',
  './assets/assets/images/card-art/monster-restless.webp',
  './assets/assets/images/card-art/monster-seeker.webp',
  './assets/assets/images/card-art/monster-swarm.webp',
  './assets/assets/images/card-art/monster-viy.webp',
  './assets/assets/images/card-art/monster-volot.webp',
  './assets/assets/images/card-art/monster-vurdalak.webp',
  './assets/assets/images/card-art/monster-werewolf.webp',
  './assets/assets/images/card-art/special-assault-rifle.webp',
  './assets/assets/images/card-art/special-drg-4u.webp',
  './assets/assets/images/card-art/special-exoskeleton.webp',
  './assets/assets/images/card-art/special-old-cloak.webp',
  './assets/assets/images/card-art/special-plague-doctor-mask.webp',
  './assets/assets/images/card-art/special-shotgun.webp',
  './assets/assets/images/card-art/special-swiss-army-knife.webp',
  './assets/assets/images/card-art/supply-adrenaline-supply.webp',
  './assets/assets/images/card-art/supply-adrenaline-x.webp',
  './assets/assets/images/card-art/supply-agility-stimulant.webp',
  './assets/assets/images/card-art/supply-air-canister.webp',
  './assets/assets/images/card-art/supply-credits.webp',
  './assets/assets/images/card-art/supply-defibrillator.webp',
  './assets/assets/images/card-art/supply-door-remote.webp',
  './assets/assets/images/card-art/supply-dry-rations.webp',
  './assets/assets/images/card-art/supply-endurance-stimulant.webp',
  './assets/assets/images/card-art/supply-gas-cylinder.webp',
  './assets/assets/images/card-art/supply-nanobots.webp',
  './assets/assets/images/card-art/supply-power-cell.webp',
  './assets/assets/images/card-art/supply-proton-shield.webp',
  './assets/assets/images/card-art/supply-repair-stimulant.webp',
  './assets/assets/images/card-art/supply-science-stimulant.webp',
  './assets/assets/images/card-art/supply-stash.webp',
  './assets/assets/images/card-art/supply-strength-stimulant.webp',
  './assets/assets/images/card-art/supply-tripwire.webp',
  './assets/assets/images/card-art/supply-water.webp',
+  './assets/assets/images/card-art/item-backpack.webp',
  './assets/assets/images/card-art/item-brass-knuckles.webp',
  './assets/assets/images/card-art/item-cleaver.webp',
  './assets/assets/images/card-art/item-gu4-rd.webp',
  './assets/assets/images/card-art/item-hard-hat.webp',
  './assets/assets/images/card-art/item-helmet.webp',
  './assets/assets/images/card-art/item-lucky-socks.webp',
  './assets/assets/images/card-art/item-makeshift-armor.webp',
  './assets/assets/images/card-art/item-medic-bag.webp',
  './assets/assets/images/card-art/item-pipe.webp',
  './assets/assets/images/card-art/item-pistol.webp',
  './assets/assets/images/card-art/item-smuggler-mark.webp',
  './assets/assets/images/card-art/item-spacesuit-mk2.webp',
  './assets/assets/images/card-art/item-welding-mask.webp',
  './assets/assets/images/card-art/supply-flashlight.webp',
  './assets/assets/images/card-art/supply-medkit.webp',
  './assets/assets/images/card-art/supply-ration.webp',
  './assets/assets/images/crew_guard.png',
+  './assets/assets/images/card-art/event-alcohol-crate.webp',
  './assets/assets/images/card-art/event-asteroid-alert.webp',
  './assets/assets/images/card-art/event-blood-trail.webp',
  './assets/assets/images/card-art/event-bloody-suitcase.webp',
  './assets/assets/images/card-art/event-body-pile.webp',
  './assets/assets/images/card-art/event-broken-drone.webp',
  './assets/assets/images/card-art/event-cabin-noise.webp',
  './assets/assets/images/card-art/event-cache-symbols.webp',
  './assets/assets/images/card-art/event-child-cry.webp',
  './assets/assets/images/card-art/event-cigarette-machine.webp',
  './assets/assets/images/card-art/event-collapsed-panel.webp',
  './assets/assets/images/card-art/event-contraband-cache.webp',
  './assets/assets/images/card-art/event-corpse.webp',
  './assets/assets/images/card-art/event-countdown-trap.webp',
  './assets/assets/images/card-art/event-exoskeleton-terminal.webp',
  './assets/assets/images/card-art/event-exposed-wires.webp',
  './assets/assets/images/card-art/event-falling-beam.webp',
  './assets/assets/images/card-art/event-falling-monster.webp',
  './assets/assets/images/card-art/event-female-whisper.webp',
  './assets/assets/images/card-art/event-fire.webp',
  './assets/assets/images/card-art/event-gas-cabin.webp',
  './assets/assets/images/card-art/event-gas-pipe.webp',
  './assets/assets/images/card-art/event-hatch-monster.webp',
  './assets/assets/images/card-art/event-hatch-scrape.webp',
  './assets/assets/images/card-art/event-horde-carry.webp',
  './assets/assets/images/card-art/event-huge-crate.webp',
  './assets/assets/images/card-art/event-invasion-armory-14.webp',
  './assets/assets/images/card-art/event-invasion-armory-2.webp',
  './assets/assets/images/card-art/event-invasion-crew-quarters-17.webp',
  './assets/assets/images/card-art/event-invasion-crew-quarters-5.webp',
  './assets/assets/images/card-art/event-invasion-dining-hall-10.webp',
  './assets/assets/images/card-art/event-invasion-dining-hall-22.webp',
  './assets/assets/images/card-art/event-invasion-engineering-control-post-20.webp',
  './assets/assets/images/card-art/event-invasion-engineering-control-post-8.webp',
  './assets/assets/images/card-art/event-invasion-escape-pods-1.webp',
  './assets/assets/images/card-art/event-invasion-escape-pods-13.webp',
  './assets/assets/images/card-art/event-invasion-flight-control-11.webp',
  './assets/assets/images/card-art/event-invasion-flight-control-23.webp',
  './assets/assets/images/card-art/event-invasion-laboratory-18.webp',
  './assets/assets/images/card-art/event-invasion-laboratory-6.webp',
  './assets/assets/images/card-art/event-invasion-main-computer-21.webp',
  './assets/assets/images/card-art/event-invasion-main-computer-9.webp',
  './assets/assets/images/card-art/event-invasion-medical-bay-16.webp',
  './assets/assets/images/card-art/event-invasion-medical-bay-4.webp',
  './assets/assets/images/card-art/event-invasion-morgue-12.webp',
  './assets/assets/images/card-art/event-invasion-morgue-24.webp',
  './assets/assets/images/card-art/event-invasion-open-0.webp',
  './assets/assets/images/card-art/event-invasion-open-1.webp',
  './assets/assets/images/card-art/event-invasion-reactor-15.webp',
  './assets/assets/images/card-art/event-invasion-reactor-3.webp',
  './assets/assets/images/card-art/event-invasion-storage-19.webp',
  './assets/assets/images/card-art/event-invasion-storage-7.webp',
  './assets/assets/images/card-art/event-inventory-notes.webp',
  './assets/assets/images/card-art/event-junk-credits.webp',
  './assets/assets/images/card-art/event-junk-guitar.webp',
  './assets/assets/images/card-art/event-junk-medical.webp',
  './assets/assets/images/card-art/event-lights-out.webp',
  './assets/assets/images/card-art/event-lockers.webp',
  './assets/assets/images/card-art/event-meteor-stream.webp',
  './assets/assets/images/card-art/event-monster-corpse.webp',
  './assets/assets/images/card-art/event-monster-horde.webp',
  './assets/assets/images/card-art/event-monster-nest.webp',
  './assets/assets/images/card-art/event-monster-pack.webp',
  './assets/assets/images/card-art/event-needle-box.webp',
  './assets/assets/images/card-art/event-nest-room.webp',
  './assets/assets/images/card-art/event-oxygen-alarm.webp',
  './assets/assets/images/card-art/event-pack-sighting.webp',
  './assets/assets/images/card-art/event-pile-of-things.webp',
  './assets/assets/images/card-art/event-radio-transmitter.webp',
  './assets/assets/images/card-art/event-repair-cleaner.webp',
  './assets/assets/images/card-art/event-rope-hatch.webp',
  './assets/assets/images/card-art/event-rubble.webp',
  './assets/assets/images/card-art/event-scientist-case.webp',
  './assets/assets/images/card-art/event-scientist-report.webp',
  './assets/assets/images/card-art/event-security-console.webp',
  './assets/assets/images/card-art/event-security-room.webp',
  './assets/assets/images/card-art/event-shelf-equipment.webp',
  './assets/assets/images/card-art/event-ship-map.webp',
  './assets/assets/images/card-art/event-suitcases.webp',
  './assets/assets/images/card-art/event-supply-terminal.webp',
  './assets/assets/images/card-art/event-survivor-scream.webp',
  './assets/assets/images/card-art/event-toolbox.webp',
  './assets/assets/images/card-art/event-trade-bot.webp',
  './assets/assets/images/card-art/event-two-crates.webp',
  './assets/assets/images/card-art/event-vending-machine.webp',
  './assets/assets/images/card-art/event-vent-monster.webp',
  './assets/assets/images/card-art/event-ventilation-failure.webp',
  './assets/assets/images/card-art/event-weapon-monster.webp',
  './assets/assets/images/card-art/monster-token-boil.webp',
  './assets/assets/images/card-art/monster-token-drekovac.webp',
  './assets/assets/images/card-art/monster-token-ghoul.webp',
  './assets/assets/images/card-art/monster-token-leshy.webp',
  './assets/assets/images/card-art/monster-token-likho.webp',
  './assets/assets/images/card-art/monster-token-mother.webp',
  './assets/assets/images/card-art/monster-token-nest.webp',
  './assets/assets/images/card-art/monster-token-pack.webp',
  './assets/assets/images/card-art/monster-token-plagued.webp',
  './assets/assets/images/card-art/monster-token-restless.webp',
  './assets/assets/images/card-art/monster-token-seeker.webp',
  './assets/assets/images/card-art/monster-token-swarm.webp',
  './assets/assets/images/card-art/monster-token-viy.webp',
  './assets/assets/images/card-art/monster-token-volot.webp',
  './assets/assets/images/card-art/monster-token-vurdalak.webp',
  './assets/assets/images/card-art/monster-token-werewolf.webp',
  './assets/assets/images/card-art/quest-quest-01.webp',
  './assets/assets/images/card-art/quest-quest-02.webp',
  './assets/assets/images/card-art/quest-quest-03.webp',
  './assets/assets/images/card-art/quest-quest-04.webp',
  './assets/assets/images/card-art/quest-quest-05.webp',
  './assets/assets/images/card-art/quest-quest-06.webp',
  './assets/assets/images/card-art/quest-quest-07.webp',
  './assets/assets/images/card-art/quest-quest-08.webp',
  './assets/assets/images/card-art/quest-quest-09.webp',
  './assets/assets/images/card-art/quest-quest-10.webp',
  './assets/assets/images/card-art/quest-quest-11.webp',
  './assets/assets/images/card-art/quest-quest-12.webp',
  './assets/assets/images/card-art/quest-quest-13.webp',
  './assets/assets/images/card-art/quest-quest-14.webp',
  './assets/assets/images/card-art/quest-quest-15.webp',
  './assets/assets/images/card-art/quest-quest-16.webp',
  './assets/assets/images/card-art/quest-quest-17.webp',
  './assets/assets/images/card-art/quest-quest-18.webp',
  './assets/assets/images/card-art/quest-quest-19.webp',
  './assets/assets/images/card-art/quest-quest-20.webp',
  './assets/assets/images/card-art/quest-quest-21.webp',
  './assets/assets/images/card-art/quest-quest-22.webp',
  './assets/assets/images/card-art/quest-quest-23.webp',
  './assets/assets/images/card-art/quest-quest-24.webp',
  './assets/assets/images/card-art/quest-quest-25.webp',
  './assets/assets/images/card-art/quest-quest-26.webp',
  './assets/assets/images/card-art/quest-quest-27.webp',
  './assets/assets/images/card-art/quest-quest-28.webp',
  './assets/assets/images/card-art/quest-quest-29.webp',
  './assets/assets/images/card-art/task-abscessive.webp',
  './assets/assets/images/card-art/task-agile.webp',
  './assets/assets/images/card-art/task-cripple.webp',
  './assets/assets/images/card-art/task-exterminator.webp',
  './assets/assets/images/card-art/task-fashionable.webp',
  './assets/assets/images/card-art/task-hunter.webp',
  './assets/assets/images/card-art/task-lively.webp',
  './assets/assets/images/card-art/task-lucky.webp',
  './assets/assets/images/card-art/task-merchant.webp',
  './assets/assets/images/card-art/task-modernizer.webp',
  './assets/assets/images/card-art/task-quartermaster.webp',
  './assets/assets/images/card-art/task-researcher.webp',
  './assets/assets/images/card-art/task-robot-owner.webp',
  './assets/assets/images/card-art/task-special.webp',
  './assets/assets/images/card-art/task-strongman.webp',
  './assets/assets/images/card-art/task-wealthy.webp',
  './assets/assets/images/crew_healer.png',
  './assets/assets/images/crew_mechanic.png',
  './assets/assets/images/crew_scientist.png',
  './assets/assets/images/ship_bark_backdrop.png',
  './assets/assets/images/sleeping_black_cat_dark_room/cat_darkroom_04_burgundy_blanket.png',
  './assets/fonts/MaterialIcons-Regular.otf',
];
const ASSET_PATH = /(?:^|\/)(?:assets\/|canvaskit\/|skwasm\/)/;
const CACHEABLE_EXTENSION =
  /\.(?:avif|bmp|gif|ico|jpe?g|json|mjs|js|otf|png|svg|ttf|wasm|webp|woff2?)$/;

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)),
  );
  event.waitUntil(self.skipWaiting());
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

self.addEventListener('message', (event) => {
  if (event.data?.type !== 'GET_OFFLINE_STATUS') return;
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cachedShell = await Promise.all(
        APP_SHELL.map((path) => cache.match(path)),
      );
      event.source?.postMessage({
        type: 'OFFLINE_STATUS',
        ready: cachedShell.every(Boolean),
        version: CACHE_VERSION,
      });
    }),
  );
});
