// Replaces the old web app's offline worker at this address. Once a browser fetches it, it deletes
// what the old app kept for offline use and removes itself, so the page underneath, which points to
// arcvert.pages.dev, can show.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const name of await caches.keys()) await caches.delete(name);
      await self.registration.unregister();
      for (const page of await self.clients.matchAll({ type: 'window' })) page.navigate(page.url);
    })(),
  );
});
