# OpenClaw with File manager

Docker image based on [c9sdk-pm2-ubuntu](https://github.com/lequanghuylc/c9sdk-pm2-nginx): **OpenClaw** gateway (Node **24** via **nvm** + global `openclaw` CLI), **nginx** reverse proxy on port **8080**, and **c9sdk** (Cloud9-style IDE) on **3399** via **pm2** under **supervisor**.

## Why do we need C9 IDE
- Access to terminal and files, full control of Openclaw config
- Provide a ability to jump in when Openclaw stuck with the tasks
- Do compldex 3rd integrations, even a webserver

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/AgpGNm?referralCode=kmHOLH&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Ports

- **OpenClaw Control UI / API (via nginx)**: `8080` → gateway on `127.0.0.1:18789`
- **OpenClaw gateway (direct)**: `18789` (optional; exposed in Compose)
- **c9sdk (nginx proxy)**: `8081` → `3399`
- **c9sdk (direct)**: `3399`

## Environment variables

- **`TELEGRAM_BOT_TOKEN`**: Telegram bot token from [@BotFather](https://t.me/BotFather)
- **`OPENAI_API_KEY`**: OpenAI API key for the default model (`openai/gpt-5.4` in `openclaw.json.template`). Leave blank when using only a custom provider; the bootstrap script removes the default OpenAI provider config when this is blank.
- **`C9SDK_PASSWORD`**: password for the c9sdk server (`c9sdk:$C9SDK_PASSWORD`)
- **`OPENCLAW_GATEWAY_TOKEN`**: Token to used with Openclaw dashboard gateway
- **`OPENCLAW_ALLOWED_ORIGIN`**: Optional. Extra Control UI CORS origins for the gateway (`gateway.controlUi.allowedOrigins` in generated `openclaw.json`). Use a comma-separated list (e.g. `https://app.example.com,https://other.example.com`). On every container start, `bootstrap-openclaw.mjs` merges these into the defaults from `openclaw.json.template` (localhost / `127.0.0.1`) without duplicating entries.
- **`INITIAL_OPENCLAW_VERSION`**: Optional. npm version to install for OpenClaw on first boot of a fresh `/root/.openclaw` volume. Defaults to `latest` (examples: `latest`, `0.4.7`).
- **`CUSTOM_PROVIDER_*`**: Optional. Adds one OpenAI-compatible custom model provider to generated `openclaw.json` on every container start, so you can use providers such as KRouter without SSH access.

On first start, `/root/bootstrap.sh` installs `openclaw@${INITIAL_OPENCLAW_VERSION:-latest}` once per `/root/.openclaw` volume, then installs bundled [OpenClaw skills](https://docs.openclaw.ai/tools/creating-skills) from `included-skills/` into `/root/.openclaw/workspace/skills` (same layout as `~/.openclaw/workspace/skills/` in the docs). After that, `/root/bootstrap-openclaw.mjs` writes `/root/.openclaw/openclaw.json` from `openclaw.json.template` (Telegram channel + gateway `local` / `lan`), merging `OPENCLAW_ALLOWED_ORIGIN` and `CUSTOM_PROVIDER_*` when set, even when other env vars are not set yet (fresh install writes empty token values), persist `/root/.openclaw` if you want stable pairing and sessions.

These envs `TELEGRAM_BOT_TOKEN` and `OPENAI_API_KEY` are setup for convenient reasons, since ChatGPT and Telegram is mostly used. If you want to use another model provider, keep `OPENAI_API_KEY` blank and set `CUSTOM_PROVIDER_*`. Once you have access to the C9 IDE, check [Openclaw's Offcial Docs](https://docs.openclaw.ai/) to know how to connect different AI models and message channels.

### Custom model provider

Set these variables to add one custom OpenAI-compatible provider without editing `/root/.openclaw/openclaw.json` manually:

```env
CUSTOM_PROVIDER_NAME=krouter
CUSTOM_PROVIDER_API_KEY=your-api-key
CUSTOM_PROVIDER_BASE_URL=https://api.krouter.net/v1
CUSTOM_PROVIDER_MODEL_ID=cx/gpt-5.5
```

Optional variables:

```env
CUSTOM_PROVIDER_AUTH=api-key
CUSTOM_PROVIDER_API=openai-completions
CUSTOM_PROVIDER_MODEL_NAME=cx/gpt-5.5
CUSTOM_PROVIDER_MODEL_API=openai-completions
```

If omitted, `CUSTOM_PROVIDER_AUTH` defaults to `api-key`, `CUSTOM_PROVIDER_API` defaults to `openai-completions`, `CUSTOM_PROVIDER_MODEL_NAME` defaults to `CUSTOM_PROVIDER_MODEL_ID`, and `CUSTOM_PROVIDER_MODEL_API` defaults to `CUSTOM_PROVIDER_API`.

When these variables are set, the generated default model becomes `CUSTOM_PROVIDER_NAME/CUSTOM_PROVIDER_MODEL_ID` (for example, `krouter/cx/gpt-5.5`). If `OPENAI_API_KEY` is blank, the generated config also removes the default OpenAI provider and OpenAI plugin entry.

### Dashboard pairing (auto-approve)

Also for convenient setup, please follow the steps here:
- Make the container up and running (deploy template, run docker image,..etc..)
- Access Dashboard gateway (`http://localhost:18789` or public domain), input password (`OPENCLAW_GATEWAY_TOKEN`). It will fail but it will register the first device
- [A script run in the background and listen the first device trying to pair and automatically approve it]
- Wait for a bit, or check logs in the IDE: `pm2 logs openclaw-auto-approve` (look for `approved successfully, exiting`), or `pm2 logs readme` for a short usage summary
- Login again, now you can access the dashboard

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
