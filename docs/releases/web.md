# Web release

## Production bundle

Build from the Flutter application directory:

```sh
cd packages/besprotoritsa_app
flutter build web --release --pwa-strategy=offline-first --base-href="/" --wasm
```

The distributable directory is `packages/besprotoritsa_app/build/web`. Do not
publish its parent `build` directory.

`--wasm` produces an SKWasm/WASM target (`main.dart.wasm` and `main.dart.mjs`)
with an optimized CanvasKit JavaScript fallback for browsers without WasmGC.
The supplied `--pwa-strategy=offline-first` flag is accepted by Flutter 3.47
but deprecated by Flutter; the production offline behavior is intentionally
owned by `web/service_worker.js`, not Flutter's retiring generated worker.
When a future Flutter removes that flag, omit only
`--pwa-strategy=offline-first`; keep the remaining command and the custom
worker.

The custom bootstrap deliberately does not load `flutter_service_worker.js`.
It registers `service_worker.js`, which precaches the app shell, local
CanvasKit/SKWasm, JavaScript, and WASM and uses a cache-first policy for images
and fonts loaded during play.
After the first successful launch, the game reopens and renders offline.
Increase `CACHE_VERSION` in `web/service_worker.js` whenever a release changes
cached asset behavior, so clients discard an incompatible old cache.

## Save persistence verification

Browser saves are origin-scoped IndexedDB records in the `besprotoritsa`
database, `game_saves` object store. Older LocalStorage saves are migrated on
their first read. Browser refreshes do not clear IndexedDB.

Run the automated browser check:

```sh
cd packages/besprotoritsa_app
flutter test --platform chrome test/web_indexed_db_storage_test.dart
```

For a release smoke test, deploy or serve `build/web` from an HTTP origin,
start a game, create a manual save, press F5, and open that slot again. In
Chrome DevTools, **Application → Storage → IndexedDB → besprotoritsa →
game_saves** should contain both `save.*` and, for a named manual slot,
`name.*` records.

To exercise offline play: complete one online launch, wait until DevTools shows
`service_worker.js` as activated, enable **Offline** in the Network panel, and
reload. The shell, sprites and fonts should load from the Cache Storage entry
whose name starts with `besprotoritsa-web-`.

## Static hosting

### Cloudflare Pages

Set the Pages build output directory to
`packages/besprotoritsa_app/build/web` and deploy its contents. The copied
`web/_headers` file supplies COOP, COEP, CORP, `nosniff`, referrer and permissions
headers; its `/*.wasm` rule declares `application/wasm`. Confirm in the Pages
deployment preview that `main.dart.wasm` has `Content-Type: application/wasm`
and every response has `Cross-Origin-Opener-Policy: same-origin`.

### GitHub Pages

Publish the contents of `build/web` (not the directory itself) to the Pages
artifact or `gh-pages` branch. GitHub Pages serves `.wasm` with the appropriate
MIME type, but it cannot attach a custom COOP header through a repository file.
Use Cloudflare Pages, an Nginx reverse proxy, or another header-capable CDN for
the production SKWasm configuration. If hosting under a project subpath,
rebuild with a matching slash-delimited `--base-href`, for example
`--base-href="/Besprotoritsa/"`.

This repository publishes automatically using
[`deploy-web.yml`](../../.github/workflows/deploy-web.yml): every push to `main`
builds the Flutter web app and deploys it to GitHub Pages at
`https://lamandos.github.io/Besprotoritsa/`. Before its first run, open the
repository's **Settings → Pages** and set **Build and deployment → Source** to
**GitHub Actions**. The workflow can also be started manually from the
repository's **Actions** tab.

### Nginx

Use [besprotoritsa-web.conf](../../deploy/nginx/besprotoritsa-web.conf) inside
the relevant `server` block after changing its `root`. The WASM-specific
location explicitly maps the MIME type to `application/wasm`; all app and WASM
responses receive `Cross-Origin-Opener-Policy: same-origin` and companion
security headers. Do not cache `service_worker.js` at the edge.

## Release checks

```sh
cd packages/besprotoritsa_app
flutter analyze
flutter test
flutter test --platform chrome test/web_indexed_db_storage_test.dart
flutter build web --release --pwa-strategy=offline-first --base-href="/" --wasm
find build/web -maxdepth 1 -type f | sort
```

The final listing must include `main.dart.wasm`, `main.dart.mjs`,
`main.dart.js`, `service_worker.js`, and `_headers`.
