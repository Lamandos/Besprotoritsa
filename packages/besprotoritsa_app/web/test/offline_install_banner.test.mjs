import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { JSDOM } from 'jsdom';
import test from 'node:test';

const htmlPath = new URL('../index.html', import.meta.url);
const html = await readFile(fileURLToPath(htmlPath), 'utf8');

function loadPage() {
  let serviceWorkerListeners;
  const serviceWorker = {
    controller: null,
    addEventListener(type, listener) {
      serviceWorkerListeners ??= new Map();
      const listeners = serviceWorkerListeners.get(type) ?? [];
      listeners.push(listener);
      serviceWorkerListeners.set(type, listeners);
    },
    register: async () => ({ active: { postMessage() {} } }),
    dispatch(type, event) {
      for (const listener of serviceWorkerListeners?.get(type) ?? []) {
        listener(event);
      }
    },
  };
  const dom = new JSDOM(html, {
    runScripts: 'dangerously',
    url: 'https://example.test/',
    beforeParse(window) {
      Object.defineProperty(window, 'matchMedia', {
        value: () => ({ matches: false }),
      });
      Object.defineProperty(window.navigator, 'serviceWorker', {
        value: serviceWorker,
      });
    },
  });
  return { dom, serviceWorker };
}

test('dismisses the offline banner and keeps it hidden after status updates', async () => {
  const { dom, serviceWorker } = loadPage();
  const { document, Event } = dom.window;
  const banner = document.querySelector('#offline-status');
  const dismiss = document.querySelector('#offline-dismiss');

  assert.ok(dismiss, 'the offline banner has a dismiss button');
  dismiss.click();
  assert.equal(banner.hidden, true, 'clicking dismiss hides the banner');

  const statusEvent = new Event('message');
  statusEvent.data = { type: 'OFFLINE_STATUS', ready: true };
  serviceWorker.dispatch('message', statusEvent);
  assert.equal(banner.hidden, true, 'a later status update keeps it hidden');

  dom.window.close();
});
