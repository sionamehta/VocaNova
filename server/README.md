# Voca Nova coach server

The AI coach (chat, reading sheet music, Hey Voca's smart answers) uses Claude. Inside the Claude app that works on its own. On GitHub Pages, the app needs this small server, which keeps your Claude API key secret and passes the coach's messages to the Claude API.

It runs as a free Cloudflare Worker. `worker.js` has no dependencies, so you can paste it into Cloudflare's website without installing anything.

## Set it up in the browser

**1. Get a Claude API key**
1. Go to [console.anthropic.com](https://console.anthropic.com) and sign up or log in.
2. Open **Billing** and add a small amount of credit (for example $5).
3. Open **API Keys**, click **Create Key**, name it `vocanova`, and copy the key. Keep it private: don't paste it into chats, emails or code.

**2. Create the server**
1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) and sign up or log in.
2. In the left menu, open **Compute (Workers)** → **Workers & Pages**, then click **Create** → **Start with Hello World**.
3. Name it `vocanova-coach` and click **Deploy**.
4. Click **Edit code**. Delete everything in the editor, paste in all of [`worker.js`](worker.js), and click **Deploy**.

**3. Give the server your key**
1. Go back to the worker's page and open **Settings** → **Variables and Secrets** → **Add**.
2. Choose type **Secret**, name `ANTHROPIC_API_KEY`, paste your Claude API key as the value, and click **Deploy**.

**4. Connect the app**
1. On the worker's page, copy its address. It looks like `https://vocanova-coach.<your-name>.workers.dev`. Opening it should say "Voca Nova coach server is running."
2. In `index.html`, find `const COACH_URL='';` and put the address plus `/api/coach` between the quotes:
   ```js
   const COACH_URL='https://vocanova-coach.<your-name>.workers.dev/api/coach';
   ```

Open the site and the Coach should say "AI coach ready".

## Set it up from the command line

If you prefer the terminal, in this folder run `npm install`, `npx wrangler login`, `npx wrangler secret put ANTHROPIC_API_KEY` and `npx wrangler deploy`.

## Good to know

- Only the sites in `DEFAULT_ORIGINS` (in `worker.js`) or the `ALLOWED_ORIGINS` variable can use the server, so other people can't spend your credit.
- The model is set in `worker.js` (`MODEL`), along with how hard it thinks for quick answers, chat and reading sheet music (`EFFORT`).
- Set a monthly spending limit in the Claude Console so a busy week can't surprise you.
- The browser still runs the app's tools (playing notes, writing solfège). The server only talks to Claude.
