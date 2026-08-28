/**
 * How'd You Do That? — story proxy Worker.
 *
 * The iOS app POSTs the story inputs as JSON. We try Groq first (fast +
 * reliable) then fall back to Gemini, both constrained to return structured
 * JSON. On success we return { title, story, oneLiners, source }. If both
 * models fail (or no keys are configured), we return 204 so the app falls back
 * to its on-device template engine.
 *
 * Secrets (set with `wrangler secret put`):
 *   GEMINI_API_KEY  — Google AI Studio key (free tier)
 *   GROQ_API_KEY    — Groq Cloud key (free tier)
 * Optional vars (wrangler.toml [vars]):
 *   GEMINI_MODEL    — default "gemini-2.0-flash"
 *   GROQ_MODEL      — default "llama-3.3-70b-versatile"
 *   ALLOWED_ORIGIN  — CORS allow-origin; default "*"
 */

// Groq is currently the fast, reliable primary (~2s); Gemini's flash tier has
// been intermittently overloaded (503) / slow, so it's the backup with a tight
// budget to keep worst-case latency bounded.
const GROQ_TIMEOUT_MS = 8000;
const GEMINI_TIMEOUT_MS = 6000;
const MAX_REQUEST_BYTES = 8192;
const MAX_OUTPUT = { title: 80, story: 900, oneLiner: 160 };

export default {
  async fetch(request, env) {
    const cors = corsHeaders(env);
    const { pathname } = new URL(request.url);

    if (request.method === "GET") {
      if (pathname === "/privacy") return privacyPage();
      if (pathname === "/support") return supportPage();
      return new Response("Not found", { status: 404 });
    }

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== "POST") {
      return json({ error: "Use POST." }, 405, cors);
    }

    const rateLimitResponse = await enforceRateLimits(request, env, cors);
    if (rateLimitResponse) return rateLimitResponse;

    const declaredLength = Number(request.headers.get("content-length") || 0);
    if (declaredLength > MAX_REQUEST_BYTES) {
      return json({ error: "Request body is too large." }, 413, cors);
    }

    let input;
    try {
      const rawBody = await request.text();
      if (new TextEncoder().encode(rawBody).byteLength > MAX_REQUEST_BYTES) {
        return json({ error: "Request body is too large." }, 413, cors);
      }
      input = normalizeInput(JSON.parse(rawBody));
    } catch {
      return json({ error: "Invalid JSON body." }, 400, cors);
    }
    const inputError = validateInput(input);
    if (inputError) {
      return json({ error: inputError }, 422, cors);
    }

    const prompt = buildPrompt(input);

    // Tier 2a: Groq first (fast + reliable).
    if (env.GROQ_API_KEY) {
      const story = await withTimeout(
        callGroq(env, prompt, input),
        GROQ_TIMEOUT_MS,
      ).catch((e) => {
        console.error("Groq failed:", e?.message || e);
        return null;
      });
      if (story) return json({ ...story, source: "groq" }, 200, cors);
    }

    // Tier 2b: Gemini fallback.
    if (env.GEMINI_API_KEY) {
      const story = await withTimeout(
        callGemini(env, prompt, input),
        GEMINI_TIMEOUT_MS,
      ).catch((e) => {
        console.error("Gemini failed:", e?.message || e);
        return null;
      });
      if (story) return json({ ...story, source: "gemini" }, 200, cors);
    }

    // Nothing worked — tell the app to use its template engine.
    return new Response(null, { status: 204, headers: cors });
  },
};

// MARK: - Prompt

function buildPrompt(i) {
  const lines = [
    `Tell the story of how I broke my ${i.bone.toLowerCase()}, the way I'd actually say it out loud to a friend.`,
    `Where it happened: ${i.location}.`,
    `What I was actually doing: ${i.activity}.`,
    `Flavor to lean into: ${i.tone} — ${i.toneDirection}. Keep it a flavor on how you talk, not a performance.`,
    `Cheekiness: ${spiceGuidance(i.spiceLevel)}.`,
  ];
  if (i.audience) lines.push(`Tell it to impress: ${i.audience}.`);
  if (i.embellish) lines.push(`Work in one absurd celebrity or animal cameo.`);
  lines.push(
    `How it should sound:`,
    `- Start in the middle, the way people really do: "So I'm at the park, right, and…" — never with a title-drop, a "Picture it," or any scene-setting.`,
    `- Real talk: contractions, filler ("honestly," "I'm not gonna lie," "so," "anyway"), and the odd half-finished thought. It's fine to trail off or double back.`,
    `- The humor is in the shrug — how casually you drop the ridiculous part — not in clever wording.`,
    `- Let it ramble a little; a perfectly structured beginning-middle-end sounds written.`,
    `Hard rules:`,
    `- First person, casual, 3–4 short sentences — about the length of a quick story you'd tell at a bar.`,
    `- The tone is a FLAVOR on how you talk, not a costume: lean into that attitude, but you're still a person telling a friend what happened — never narrator, announcer, or podcast-host voice.`,
    `- No literary or blog-style writing: no scene-setting openers, no metaphors or similes, no dramatic narration. If it reads like a short story, make it plainer.`,
    `- Funny and specific, but understated. PG-13.`,
    `- Never invent a different bone, place, or activity than the ones given.`,
    `The vibe to aim for (don't reuse this text): "Okay so I'm barely off the couch, right, and my ankle just — went. Didn't trip, didn't fall, nothing. One second I'm walking to the kitchen, next thing I know I'm on the floor googling whether you can hear your own bone break. Turns out: yeah."`,
    `Also give exactly 3 one-line versions I could text a friend (each under 20 words, sounding like something I'd actually type).`,
  );
  return lines.join("\n");
}

function spiceGuidance(level) {
  switch (level) {
    case "clean": return "squeaky clean and wholesome";
    case "wild": return "maximally cheeky and over-the-top, still PG-13";
    default: return "cheeky and playful, but still tame";
  }
}

// MARK: - Gemini

async function callGemini(env, prompt, input) {
  const model = env.GEMINI_MODEL || "gemini-2.0-flash";
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
    `?key=${env.GEMINI_API_KEY}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 1.0,
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            title: { type: "STRING" },
            story: { type: "STRING" },
            oneLiners: { type: "ARRAY", items: { type: "STRING" } },
          },
          required: ["title", "story", "oneLiners"],
        },
      },
    }),
  });
  if (!res.ok) throw new Error(`Gemini ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  return validateStory(JSON.parse(text), input);
}

// MARK: - Groq (OpenAI-compatible)

async function callGroq(env, prompt, input) {
  const model = env.GROQ_MODEL || "llama-3.3-70b-versatile";
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.GROQ_API_KEY}`,
    },
    body: JSON.stringify({
      model,
      temperature: 1.0,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            "You help people tell a story the way they'd actually say it out loud " +
            "to a friend — like a quick voice memo, casual and spoken, starting " +
            "mid-thought and rambling a little. Never written blog prose, and never " +
            "an announcer, narrator, or podcast-host voice. Reply " +
            'ONLY with a JSON object of the form {"title": string, "story": string, ' +
            '"oneLiners": string[]}.',
        },
        { role: "user", content: prompt },
      ],
    }),
  });
  if (!res.ok) throw new Error(`Groq ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const text = data?.choices?.[0]?.message?.content;
  return validateStory(JSON.parse(text), input);
}

// MARK: - Helpers

function validateStory(obj, input) {
  const title = String(obj?.title ?? "").trim();
  const story = String(obj?.story ?? "").trim();
  const oneLiners = Array.isArray(obj?.oneLiners)
    ? obj.oneLiners.map((s) => String(s).trim()).filter(Boolean)
    : [];

  if (
    !title ||
    !story ||
    [...title].length > MAX_OUTPUT.title ||
    [...story].length > MAX_OUTPUT.story ||
    oneLiners.length !== 3 ||
    oneLiners.some((line) => [...line].length > MAX_OUTPUT.oneLiner) ||
    new Set(oneLiners.map((line) => line.toLowerCase())).size !== 3 ||
    containsStructuralMarker(title) ||
    containsStructuralMarker(story) ||
    !isGrounded(`${title} ${story}`, input)
  ) {
    throw new Error("Story failed output validation.");
  }
  return { title, story, oneLiners };
}

function containsStructuralMarker(text) {
  return /\bone[\s-]?liners?\s*:|\bshort versions?\s*:|```/i.test(text);
}

function isGrounded(output, input) {
  const outputTokens = new Set(tokens(output));
  return overlaps(outputTokens, input.bone, true) &&
    overlaps(outputTokens, input.location) &&
    overlaps(outputTokens, input.activity);
}

function overlaps(outputTokens, input, requireAll = false) {
  const ignored = new Set([
    "a", "an", "and", "at", "in", "of", "on", "the", "to", "was", "were",
    "doing", "trying", "actually", "some", "something",
  ]);
  const candidates = tokens(input).filter(
    (token) => token.length >= 3 && !ignored.has(token),
  );
  if (!candidates.length) return true;
  return requireAll
    ? candidates.every((token) => outputTokens.has(token))
    : candidates.some((token) => outputTokens.has(token));
}

function tokens(text) {
  return String(text).toLowerCase().match(/[\p{L}\p{N}]+/gu) || [];
}

function normalizeInput(body) {
  return {
    bone: String(body?.bone ?? "").trim(),
    location: String(body?.location ?? "").trim(),
    activity: String(body?.activity ?? "").trim(),
    tone: String(body?.tone ?? "Absurd").trim(),
    toneDirection: String(body?.toneDirection ?? "").trim(),
    spiciness: Number(body?.spiciness ?? 0.5),
    spiceLevel: String(body?.spiceLevel ?? "cheeky").trim(),
    audience: String(body?.audience ?? "").trim(),
    embellish: Boolean(body?.embellish ?? false),
  };
}

function validateInput(input) {
  if (!input.bone || !input.location || !input.activity) {
    return "Missing bone, location, or activity.";
  }
  const limits = {
    bone: 120,
    location: 200,
    activity: 300,
    tone: 40,
    toneDirection: 240,
    audience: 160,
  };
  for (const [field, limit] of Object.entries(limits)) {
    if ([...input[field]].length > limit) return `${field} is too long.`;
  }
  if (!Number.isFinite(input.spiciness) || input.spiciness < 0 || input.spiciness > 1) {
    return "Invalid spiciness value.";
  }
  return null;
}

function withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error("timeout")), ms),
    ),
  ]);
}

async function enforceRateLimits(request, env, cors) {
  try {
    // A per-location ceiling limits total upstream model spend during a burst.
    const globalResult = await env.GLOBAL_RATE_LIMITER.limit({
      key: "story-generation",
    });
    if (!globalResult.success) return rateLimited(cors);

    // There is deliberately no account or persistent device identifier in the
    // app. Cloudflare's connection address is the best available short-lived
    // actor key; 10 generations/minute leaves room for shared mobile networks.
    const clientAddress = request.headers.get("CF-Connecting-IP") || "unknown";
    const clientResult = await env.CLIENT_RATE_LIMITER.limit({
      key: `story-generation:${clientAddress}`,
    });
    if (!clientResult.success) return rateLimited(cors);
  } catch (error) {
    // Fail closed: a binding/configuration failure must not expose paid model
    // calls without the protection this Worker expects.
    console.error("Rate limiter unavailable:", error?.message || error);
    return json(
      { error: "Story service is temporarily unavailable." },
      503,
      cors,
    );
  }
  return null;
}

function rateLimited(cors) {
  return new Response(
    JSON.stringify({ error: "Too many stories. Try again in a minute." }),
    {
      status: 429,
      headers: {
        "Content-Type": "application/json",
        "Retry-After": "60",
        ...cors,
      },
    },
  );
}

function corsHeaders(env) {
  return {
    "Access-Control-Allow-Origin": env.ALLOWED_ORIGIN || "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}

function json(obj, status, cors) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

function privacyPage() {
  return htmlPage("Privacy Policy", `
    <p class="updated">Last updated: August 28, 2026</p>
    <p>How'd You Do That? is designed to collect as little as possible. This
    policy explains what happens to the story details you enter.</p>

    <h2>What you enter</h2>
    <p>You may enter an injury, location, activity, desired audience, and story
    style. These details are used only to generate your story.</p>

    <h2>On-device generation</h2>
    <p>When Apple Intelligence is available, stories are generated on your
    device. In this mode, your story details do not leave your device.</p>

    <h2>Optional cloud fallback</h2>
    <p>The app asks for permission before cloud fallback is enabled. If you
    allow it and on-device generation is unavailable or slow, story details are
    sent over HTTPS to our service on Cloudflare and then to Groq or Google
    Gemini solely to generate and return the story.</p>
    <p>We do not store story-generation requests, link them to an account, or
    use them for advertising or tracking. Cloudflare uses the connection's
    network address as a short-lived abuse-prevention key; it is not included
    in the AI prompt or sent to Groq or Google. Our providers are required to
    protect this data consistently with this policy and applicable law.</p>

    <h2 id="choices">Your choices</h2>
    <p>You can turn off <strong>Allow cloud AI fallback</strong> from the final
    story setup step or the app's About screen. When it is off, story details
    remain on your device and the classic offline generator is used when Apple
    Intelligence is unavailable.</p>

    <h2>Saved stories and deletion</h2>
    <p>Stories you save are stored only on your device. Delete an individual
    story from the Saved screen, or delete the app to remove all saved stories.</p>

    <h2>Reports and support</h2>
    <p>If you email a report or support request, your email provider sends the
    information you choose to include. Report emails include the generated
    story so we can investigate. We retain support correspondence only as long
    as needed to respond, address safety issues, and meet legal obligations.
    You may request deletion by emailing
    <a href="mailto:support@howdyoudothat.app">support@howdyoudothat.app</a>.</p>

    <h2>What we do not collect</h2>
    <p>No account, advertising, analytics, contacts, photos, precise location,
    or persistent device identifier. The app is not directed to children under
    13 and does not knowingly collect their personal information.</p>

    <h2>Contact</h2>
    <p>Questions or privacy requests:
    <a href="mailto:support@howdyoudothat.app">support@howdyoudothat.app</a>.</p>
  `);
}

function supportPage() {
  return htmlPage("Help & Support", `
    <p>How'd You Do That? turns the boring facts of a broken bone into a short,
    funny story you can save or share.</p>

    <h2>Generation options</h2>
    <p>Apple Intelligence is used on supported devices. If cloud fallback is
    allowed, the app may use Groq or Google Gemini when on-device generation is
    unavailable or slow. Turn cloud fallback off from the final setup step or
    the About screen to keep story details on your device.</p>

    <h2>Troubleshooting</h2>
    <ul>
      <li>If generation takes too long, go back and try again.</li>
      <li>If cloud AI is unavailable, the app automatically creates a classic offline story.</li>
      <li>Saved stories live only on your device and cannot be recovered after deletion.</li>
      <li>If Mail cannot open for a report, contact the address below directly.</li>
    </ul>

    <h2>Contact</h2>
    <p>Email <a href="mailto:support@howdyoudothat.app">support@howdyoudothat.app</a>
    for support, privacy requests, or content-safety concerns.</p>
    <p><a class="button" href="mailto:support@howdyoudothat.app?subject=How%27d%20You%20Do%20That%3F%20Support">Email support</a></p>
    <p><a href="/privacy">Read the Privacy Policy</a></p>
  `);
}

function htmlPage(title, content) {
  const html = `<!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title} — How'd You Do That?</title>
    <style>
      :root { color-scheme: light dark; font-family: ui-rounded, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
      body { margin: 0; background: #ff5b42; color: #1d1d1f; }
      main { box-sizing: border-box; width: min(760px, calc(100% - 32px)); margin: 32px auto; padding: clamp(24px, 6vw, 56px); background: #fffaf7; border-radius: 28px; box-shadow: 0 18px 50px #7a1e1233; }
      .mark { font-size: 48px; margin: 0 0 8px; }
      h1 { margin: 0 0 12px; font-size: clamp(34px, 8vw, 54px); line-height: .98; }
      h2 { margin: 32px 0 8px; font-size: 21px; }
      p, li { line-height: 1.6; }
      a { color: #d83b27; font-weight: 650; }
      .updated { color: #6e6e73; font-size: 14px; }
      .button { display: inline-block; padding: 12px 18px; color: white; background: #ff5b42; border-radius: 999px; text-decoration: none; }
      @media (prefers-color-scheme: dark) { body { background: #6d2117; } main { background: #191513; color: #fffaf7; } a { color: #ff8978; } }
    </style>
  </head>
  <body><main><div class="mark">🦴</div><h1>${title}</h1>${content}</main></body>
  </html>`;

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=UTF-8",
      "Cache-Control": "public, max-age=300",
      "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'self' mailto:",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
    },
  });
}
