# OpenClaw with File manager

Docker image based on [c9sdk-pm2-ubuntu](https://github.com/lequanghuylc/c9sdk-pm2-nginx): **OpenClaw** gateway (Node **24** via **nvm** + global `openclaw` CLI), **nginx** reverse proxy on port **8080**, and **c9sdk** (Cloud9-style IDE) on **3399** via **pm2** under **supervisor**.

## Why do we need C9 IDE
- Access to terminal and files, full control of Openclaw config
- Provide a ability to jump in when Openclaw stuck with the tasks
- Do compldex 3rd integrations, even a webserver

## Ports

- **OpenClaw Control UI / API (via nginx)**: `8080` → gateway on `127.0.0.1:18789`
- **OpenClaw gateway (direct)**: `18789` (optional; exposed in Compose)
- **c9sdk (nginx proxy)**: `8081` → `3399`
- **c9sdk (direct)**: `3399`

## Environment variables

- **`TELEGRAM_BOT_TOKEN`**: Telegram bot token from [@BotFather](https://t.me/BotFather)
- **`OPENAI_API_KEY`**: OpenAI API key for the default model (`openai/gpt-5.4` in `openclaw.json.template`; change the model there if you prefer another OpenAI id)
- **`C9SDK_PASSWORD`**: password for the c9sdk server (`c9sdk:$C9SDK_PASSWORD`)

On first start, `/root/bootstrap-openclaw.mjs` writes `/root/.openclaw/openclaw.json` from `openclaw.json.template` (Telegram channel + gateway `local` / `lan`) even when env vars are not set yet (fresh install writes empty token values), persist `/root/.openclaw` if you want stable pairing and sessions.

These envs are setup for convenient reasons, since ChatGPT and Telegram is mostly used. If you want to have other setup, just keep those env variables blank. Once you have access to the C9 IDE, check [Openclaw's Offcial Docs](https://docs.openclaw.ai/) to know how to connect different AI models and message channels.

### Dashboard pairing (auto-approve)

A one-shot supervisor program **`openclaw-auto-approve`** runs **`/root/auto-approve-openclaw-device.mjs`** with **[google/zx](https://github.com/google/zx)** (`zx` is installed globally under Node 24). It waits until `OPENCLAW_HEALTH_URL` (default `http://127.0.0.1:18789/healthz`) responds, polls **`openclaw devices list --json`** every **`OPENCLAW_AUTO_APPROVE_INTERVAL`** seconds until **pending** is non-empty, parses **`pending[0].requestId`** (or **`id`**), then runs **`openclaw devices approve <requestId>`** (see [devices CLI](https://docs.clawd.bot/cli/devices)) and **exits**. It keeps polling while the gateway is down, the list call fails, or there are no pending requests. Supervisor runs **`nvm use 24`**, sets **`NODE_PATH="$(npm root -g)"`** (so **`import "zx/globals"`** resolves the globally installed **zx** package), then **`exec zx …`**. Optional **`OPENCLAW_GATEWAY_TOKEN`**. **`autorestart=false`** after a successful exit. If you run the script by hand, use the same **`NODE_PATH`** or you will see **`ERR_MODULE_NOT_FOUND`** for **zx**.

## Node / nvm

This has NVM installed. Openclaw is running Nodejs 24, while C9 IDE uses Nodejs 12. In some cases you can not access `openclaw` via cli, try to run `nvm use 24` first.

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
