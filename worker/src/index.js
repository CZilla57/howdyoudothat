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

export default {
  async fetch(request, env) {
    const cors = corsHeaders(env);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== "POST") {
      return json({ error: "Use POST." }, 405, cors);
    }

    let input;
    try {
      input = normalizeInput(await request.json());
    } catch {
      return json({ error: "Invalid JSON body." }, 400, cors);
    }
    if (!input.bone || !input.location || !input.activity) {
      return json({ error: "Missing bone, location, or activity." }, 422, cors);
    }

    const prompt = buildPrompt(input);

    // Tier 2a: Groq first (fast + reliable).
    if (env.GROQ_API_KEY) {
      const story = await withTimeout(
        callGroq(env, prompt),
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
        callGemini(env, prompt),
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

async function callGemini(env, prompt) {
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
  return validateStory(JSON.parse(text));
}

// MARK: - Groq (OpenAI-compatible)

async function callGroq(env, prompt) {
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
  return validateStory(JSON.parse(text));
}

// MARK: - Helpers

function validateStory(obj) {
  const title = String(obj?.title ?? "").trim();
  const story = String(obj?.story ?? "").trim();
  if (!title || !story) throw new Error("Empty story fields.");
  const oneLiners = Array.isArray(obj?.oneLiners)
    ? obj.oneLiners.map((s) => String(s).trim()).filter(Boolean).slice(0, 3)
    : [];
  return { title, story, oneLiners };
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

function withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error("timeout")), ms),
    ),
  ]);
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
