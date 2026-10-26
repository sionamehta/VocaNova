// Voca Nova coach server: a Cloudflare Worker that forwards the app's AI coach
// requests to the Claude API, so the API key never reaches the browser.
//
// POST /api/coach  {messages, tools?, tier?}  ->  {content, stop_reason}
// The app runs tools itself and sends the results back in the next request.
//
// This file has no dependencies, so it can be pasted straight into the
// Cloudflare dashboard's code editor (see README.md).

const MODEL = "claude-opus-5-5";
// The app asks for "quick" (Hey Voca), default (chat) or "complex" (reading sheet music).
const EFFORT = { quick: "low", default: "medium", complex: "high" };
// Sites allowed to use this server. Override with the ALLOWED_ORIGINS variable (comma-separated).
const DEFAULT_ORIGINS = "https://sionamehta.github.io";
const MAX_BODY_BYTES = 20 * 1024 * 1024;
const MAX_TOOLS = 16;

function cors(origin, env) {
  const allowed = (env.ALLOWED_ORIGINS || DEFAULT_ORIGINS).split(",").map((s) => s.trim()).filter(Boolean);
  if (!origin || !allowed.includes(origin)) return null;
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

const json = (body, status, headers) =>
  new Response(JSON.stringify(body), { status, headers: { ...headers, "Content-Type": "application/json" } });

function validTools(tools) {
  if (tools == null) return [];
  if (!Array.isArray(tools) || tools.length > MAX_TOOLS) return null;
  for (const t of tools) {
    if (!t || typeof t.name !== "string" || typeof t.input_schema !== "object") return null;
  }
  return tools.map((t) => ({ name: t.name, description: String(t.description || ""), input_schema: t.input_schema }));
}

// Maps a Claude API error status to the error names the app shows messages for.
const API_ERRORS = { 401: ["server_key", 500], 403: ["server_key", 500], 413: ["prompt_too_large", 413], 429: ["rate_limited", 429] };

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/") return new Response("Voca Nova coach server is running.");
    const headers = cors(request.headers.get("Origin"), env);
    if (!headers) return new Response("Forbidden", { status: 403 });
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (request.method !== "POST" || url.pathname !== "/api/coach") return json({ error: "not_found" }, 404, headers);
    if (!env.ANTHROPIC_API_KEY) return json({ error: "server_key" }, 500, headers);
    if (+request.headers.get("Content-Length") > MAX_BODY_BYTES) return json({ error: "prompt_too_large" }, 413, headers);

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "bad_request" }, 400, headers);
    }
    const tools = validTools(body.tools);
    if (!Array.isArray(body.messages) || !body.messages.length || !tools) return json({ error: "bad_request" }, 400, headers);

    let response;
    try {
      response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
          // If a safety classifier declines, retry on Anthropic's recommended fallback model.
          "anthropic-beta": "server-side-fallback-2026-07-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: MODEL,
          max_tokens: 16000,
          messages: body.messages,
          ...(tools.length ? { tools } : {}),
          output_config: { effort: EFFORT[body.tier] || EFFORT.default },
          fallbacks: "default",
        }),
      });
    } catch {
      return json({ error: "upstream" }, 502, headers);
    }
    if (!response.ok) {
      const [error, status] = API_ERRORS[response.status] || [response.status === 400 ? "bad_request" : "upstream", response.status === 400 ? 400 : 502];
      return json({ error }, status, headers);
    }
    const data = await response.json();
    return json({ content: data.content, stop_reason: data.stop_reason }, 200, headers);
  },
};
