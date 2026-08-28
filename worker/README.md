# Story proxy Worker

Tier 2 of the app's engine fallback chain (Apple on-device → **this proxy** →
template). It tries **Groq** first, then falls back to **Gemini**, both
constrained to return structured JSON, and hands the app back a finished story.
If both fail it returns `204 No Content` so the app uses its offline template
engine. (Order is set in `src/index.js` — Groq currently leads because it's the
faster, more reliable of the two free tiers.)

## Contract

**Request** — `POST /` with JSON:

```json
{
  "bone": "Wrist",
  "location": "a trampoline park in Ohio",
  "activity": "attempting a backflip",
  "tone": "Absurd",
  "toneDirection": "gloriously ridiculous and over-the-top",
  "spiciness": 0.5,
  "spiceLevel": "cheeky",
  "audience": "",
  "embellish": false
}
```

**Response** — `200` with:

```json
{
  "title": "…",
  "story": "…",
  "oneLiners": ["…", "…", "…"],
  "source": "gemini"
}
```

`204` means "no story — use the template." `4xx` means a bad request.

## Deploy

```bash
cd worker
npm install
npx wrangler login
npx wrangler secret put GEMINI_API_KEY   # from https://aistudio.google.com/apikey
npx wrangler secret put GROQ_API_KEY     # from https://console.groq.com/keys
npx wrangler deploy
```

`deploy` prints the Worker URL (e.g.
`https://howdyoudothat-story-proxy.<subdomain>.workers.dev`).

## Wire it into the app

Put that URL in the app's `StoryProxyEndpoint` Info.plist key and rebuild. The
app reads it in `AppConfig.proxyEndpoint`; a valid `https` URL makes the proxy
tier available when the user permits cloud fallback.

The Worker rejects request bodies over 8 KB, caps individual field lengths,
and rejects malformed or ungrounded model output. Native Cloudflare bindings
also enforce two generation limits:

- 10 requests per minute for one connecting client address.
- 120 requests per minute per Cloudflare location across all clients.

Rate-limit checks fail closed with `503` if their bindings are unavailable.
Exceeded limits return `429` with `Retry-After: 60`. The counters are
eventually consistent and local to each Cloudflare location, so they are abuse
guards rather than exact usage accounting.

## Local test

```bash
npx wrangler dev
curl -X POST http://localhost:8787 \
  -H 'Content-Type: application/json' \
  -d '{"bone":"Wrist","location":"a trampoline park in Ohio","activity":"attempting a backflip","tone":"Absurd","toneDirection":"gloriously ridiculous","spiciness":0.5,"spiceLevel":"cheeky","audience":"","embellish":false}'
```
