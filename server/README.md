# Voca Nova coach server

The AI coach (chat, reading sheet music, Hey Voca's smart answers) uses Claude. Inside the Claude app that works on its own. On GitHub Pages or your computer, the app needs this small server, which keeps your Claude API key secret and passes the coach's messages to the Claude API.

It runs as a free Cloudflare Worker.

## Set it up

1. Get a Claude API key at [console.anthropic.com](https://console.anthropic.com) and add some credit.
2. Make a free account at [cloudflare.com](https://dash.cloudflare.com/sign-up).
3. In this `server` folder, run:
   ```bash
   npm install
   npx wrangler login
   npx wrangler secret put ANTHROPIC_API_KEY   # paste your key when asked
   npx wrangler deploy
   ```
   The last command prints your server's address, like `https://vocanova-coach.<you>.workers.dev`.
4. In `wrangler.toml`, set `ALLOWED_ORIGINS` to the address of your site (for GitHub Pages, `https://<your-username>.github.io`), then run `npx wrangler deploy` again. Requests from any other site are refused, so other people can't spend your credit.
5. In `index.html`, find `const COACH_URL='';` and put your server's address plus `/api/coach` between the quotes:
   ```js
   const COACH_URL='https://vocanova-coach.<you>.workers.dev/api/coach';
   ```

Open the site and the Coach should say "AI coach ready".

## Good to know

- The model is set in `worker.js` (`MODEL`), along with how hard it thinks for quick answers, chat and reading sheet music (`EFFORT`).
- Set a monthly spending limit in the Claude Console so a busy week can't surprise you.
- The browser still runs the app's tools (playing notes, writing solfège). The server only talks to Claude.
