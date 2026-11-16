// Pianomaps service worker: makes the site installable and keeps the app shell available offline.
const V="pianomaps-v1";
const SHELL=["./","index.html","config.js","manifest.webmanifest","assets/logo-light.png","assets/logo-dark.png","assets/mark-light.png","assets/mark-dark.png","icons/icon-192.png","icons/icon-512.png"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(V).then(c=>Promise.all(SHELL.map(u=>c.add(u).catch(()=>{})))).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
// own files: network first (always fresh), cache as fallback. Maps, Supabase and photos are never cached here.
self.addEventListener("fetch",e=>{
  const r=e.request;
  if(r.method!=="GET"||new URL(r.url).origin!==location.origin)return;
  e.respondWith(fetch(r).then(res=>{if(res.ok){const cp=res.clone();caches.open(V).then(c=>c.put(r,cp))}return res})
    .catch(()=>caches.match(r).then(m=>m||caches.match("index.html"))));
});
