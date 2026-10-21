const FEED = "https://jordan-cod.github.io/pullo/appcast.xml";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/appcast.xml") return feed();
    return env.ASSETS.fetch(request);
  },
};

async function feed() {
  const upstream = await fetch(FEED, { cf: { cacheTtl: 120, cacheEverything: true } });
  if (!upstream.ok) return new Response("Feed unavailable", { status: 502 });
  return new Response(upstream.body, {
    headers: {
      "content-type": "application/xml; charset=utf-8",
      "cache-control": "public, max-age=120",
    },
  });
}
