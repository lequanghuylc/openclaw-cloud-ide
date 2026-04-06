# OpenClaw with file manager

Docker image based on [c9sdk-pm2-ubuntu](https://github.com/lequanghuylc/c9sdk-pm2-nginx): **OpenClaw** gateway (Node **22** via **nvm** + global `openclaw` CLI), **nginx** reverse proxy on port **8080**, and **c9sdk** (Cloud9-style IDE) on **3399** via **pm2** under **supervisor**.

## Ports

- **OpenClaw Control UI / API (via nginx)**: `8080` → gateway on `127.0.0.1:18789`
- **OpenClaw gateway (direct)**: `18789` (optional; exposed in Compose)
- **c9sdk (nginx proxy)**: `8081` → `3399`
- **c9sdk (direct)**: `3399`

## Required environment variables

- **`TELEGRAM_BOT_TOKEN`**: Telegram bot token from [@BotFather](https://t.me/BotFather)
- **`OPENAI_API_KEY`**: OpenAI API key for the default model (`openai/gpt-5.4` in `openclaw.json.template`; change the model there if you prefer another OpenAI id)
- **`C9SDK_PASSWORD`**: password for the c9sdk server (`c9sdk:$C9SDK_PASSWORD`)

On first start, `/root/bootstrap-openclaw.sh` writes `/root/.openclaw/openclaw.json` from `openclaw.json.template` (Telegram channel + gateway `local` / `lan`), and writes **`/root/.openclaw/.nvmrc`** with `22` so shells that `cd ~/.openclaw` can pick Node 22 via your nvm + `.nvmrc` setup. Persist `/root/.openclaw` if you want stable pairing and sessions.

### Dashboard pairing (auto-approve)

A one-shot supervisor program **`openclaw-auto-approve`** runs **`/root/auto-approve-openclaw-device.mjs`** with **[google/zx](https://github.com/google/zx)** (`zx` is installed globally under Node 22). It waits until `OPENCLAW_HEALTH_URL` (default `http://127.0.0.1:18789/healthz`) responds, polls **`openclaw devices list --json`** every **`OPENCLAW_AUTO_APPROVE_INTERVAL`** seconds until **pending** is non-empty, parses **`pending[0].requestId`** (or **`id`**), then runs **`openclaw devices approve <requestId>`** (see [devices CLI](https://docs.clawd.bot/cli/devices)) and **exits**. It keeps polling while the gateway is down, the list call fails, or there are no pending requests. Supervisor runs **`nvm use 22`**, sets **`NODE_PATH="$(npm root -g)"`** (so **`import "zx/globals"`** resolves the globally installed **zx** package), then **`exec zx …`**. Optional **`OPENCLAW_GATEWAY_TOKEN`**. **`autorestart=false`** after a successful exit. If you run the script by hand, use the same **`NODE_PATH`** or you will see **`ERR_MODULE_NOT_FOUND`** for **zx**.

## Node / nvm

`NVM_DIR=/usr/local/nvm`. This image installs **Node 22**, runs **`npm install -g openclaw@latest`** under Node 22, then runs **`nvm alias default 12`** so the image default stays **Node 12**. Supervisor starts **c9sdk** with **`nvm use 12`** before **`pm2`**, and starts **OpenClaw** with **`nvm use 22`** before **`openclaw gateway`**, so each stack uses the intended Node version even if `PATH` would otherwise pick the wrong one.

## Build & run (Compose)

```bash
cp .env.example .env
# set TELEGRAM_BOT_TOKEN and OPENAI_API_KEY
docker compose up -d --build
```

- OpenClaw UI (proxied): `http://localhost:8080/`
- c9sdk: `http://localhost:3399/` (or `8081` through nginx)

## Build & run (docker)

```bash
docker build -t openclaw-with-file-manager .

docker run --rm \
  -p 8080:8080 -p 8081:8081 -p 3399:3399 -p 18789:18789 \
  -e TELEGRAM_BOT_TOKEN="your-token" \
  -e OPENAI_API_KEY="your-key" \
  -e C9SDK_PASSWORD=changeme \
  openclaw-with-file-manager
```
