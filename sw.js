// Tiene l'app disponibile anche senza internet. Cambia VERSION a ogni aggiornamento.
const VERSION = "quote-v15";
const FILES = ["./", "./index.html", "./manifest.webmanifest", "./icons/apple-touch-icon.png", "./icons/icon-192.png", "./icons/icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
// Prima prova la rete (così arrivano gli aggiornamenti), senza rete usa la copia salvata.
self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET" || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(
    fetch(e.request, { cache: "no-cache" }).then((r) => { const copy = r.clone(); caches.open(VERSION).then((c) => c.put(e.request, copy)); return r; })
      .catch(() => caches.match(e.request).then((r) => r || caches.match("./index.html")))
  );
});
