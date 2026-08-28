import assert from "node:assert/strict";
import test from "node:test";

import worker from "../src/index.js";

function limiter(success) {
  return {
    calls: [],
    async limit(input) {
      this.calls.push(input);
      return { success };
    },
  };
}

function storyRequest() {
  return new Request("https://example.com/", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "CF-Connecting-IP": "203.0.113.10",
    },
    body: JSON.stringify({
      bone: "Wrist",
      location: "Ohio",
      activity: "doing a backflip",
    }),
  });
}

test("returns 429 when the global ceiling is exhausted", async () => {
  const globalLimiter = limiter(false);
  const clientLimiter = limiter(true);

  const response = await worker.fetch(storyRequest(), {
    GLOBAL_RATE_LIMITER: globalLimiter,
    CLIENT_RATE_LIMITER: clientLimiter,
  });

  assert.equal(response.status, 429);
  assert.equal(response.headers.get("Retry-After"), "60");
  assert.equal(globalLimiter.calls.length, 1);
  assert.equal(clientLimiter.calls.length, 0);
});

test("returns 429 when the client limit is exhausted", async () => {
  const globalLimiter = limiter(true);
  const clientLimiter = limiter(false);

  const response = await worker.fetch(storyRequest(), {
    GLOBAL_RATE_LIMITER: globalLimiter,
    CLIENT_RATE_LIMITER: clientLimiter,
  });

  assert.equal(response.status, 429);
  assert.deepEqual(clientLimiter.calls, [
    { key: "story-generation:203.0.113.10" },
  ]);
});

test("allows a request within both limits", async () => {
  const response = await worker.fetch(storyRequest(), {
    GLOBAL_RATE_LIMITER: limiter(true),
    CLIENT_RATE_LIMITER: limiter(true),
  });

  // No model secrets in this test environment means the normal safe fallback.
  assert.equal(response.status, 204);
});

test("fails closed when a rate-limit binding is missing", async () => {
  const response = await worker.fetch(storyRequest(), {});
  assert.equal(response.status, 503);
});

test("serves the public privacy policy without using generation limits", async () => {
  const response = await worker.fetch(
    new Request("https://example.com/privacy"),
    {},
  );
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(response.headers.get("Content-Type"), /^text\/html/);
  assert.match(body, /Groq or Google\s+Gemini/);
  assert.match(body, /Your choices/);
});

test("serves the public support page", async () => {
  const response = await worker.fetch(
    new Request("https://example.com/support"),
    {},
  );
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(body, /Help &amp; Support|Help & Support/);
  assert.match(body, /support@howdyoudothat\.app/);
});
