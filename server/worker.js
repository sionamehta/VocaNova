// Voca Nova coach server: a Cloudflare Worker that forwards the app's AI coach
// requests to the Claude API, so the API key never reaches the browser.
//
// POST /api/coach  {messages, tools?, tier?}  ->  {content, stop_reason}
// The app runs tools itself and sends the results back in the next request.
import Anthropic from "@anthropic-ai/sdk";

const MODEL = "claude-opus-5-5";
// The app asks for "quick" (Hey Voca), default (chat) or "complex" (reading sheet music).
const EFFORT = { quick: "low", default: "medium", complex: "high" };
const MAX_BODY_BYTES = 20 * 1024 * 1024;
const MAX_TOOLS = 16;

function cors(origin, env) {
  const allowed = (env.ALLOWED_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
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

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const headers = cors(request.headers.get("Origin"), env);
    if (!headers) return new Response("Forbidden", { status: 403 });
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (request.method !== "POST" || url.pathname !== "/api/coach") return json({ error: "not_found" }, 404, headers);
    if (+request.headers.get("Content-Length") > MAX_BODY_BYTES) return json({ error: "prompt_too_large" }, 413, headers);

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "bad_request" }, 400, headers);
    }
    const tools = validTools(body.tools);
    if (!Array.isArray(body.messages) || !body.messages.length || !tools) return json({ error: "bad_request" }, 400, headers);

    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });
    try {
      const response = await client.beta.messages.create({
        model: MODEL,
        max_tokens: 16000,
        system: typeof body.system === "string" ? body.system : undefined,
        messages: body.messages,
        ...(tools.length ? { tools } : {}),
        output_config: { effort: EFFORT[body.tier] || EFFORT.default },
        // If a safety classifier declines, retry on Anthropic's recommended fallback model.
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
      });
      return json({ content: response.content, stop_reason: response.stop_reason }, 200, headers);
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) return json({ error: "rate_limited" }, 429, headers);
      if (error instanceof Anthropic.AuthenticationError) return json({ error: "server_key" }, 500, headers);
      if (error instanceof Anthropic.BadRequestError) return json({ error: "bad_request" }, 400, headers);
      if (error instanceof Anthropic.APIError && error.status === 413) return json({ error: "prompt_too_large" }, 413, headers);
      return json({ error: "upstream" }, 502, headers);
    }
  },
};
