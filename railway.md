# OpenClaw with file manager (Railway template)

This template runs **OpenClaw** with a Cloud9-style file manager:

- OpenClaw gateway (Node **22** via **nvm**), Telegram channel from env
- File manager via **c9sdk** and **pm2**
- **nginx** on **8080** proxying the gateway; **8081** proxying c9sdk

## Deployments and domains

Point your public domain at port **8080** for the OpenClaw Control UI (proxied to the gateway). Use **8081** (or Railway’s extra domain) for the IDE if you expose it.

## Required variables

Set **`TELEGRAM_BOT_TOKEN`**, **`OPENAI_API_KEY`**, and **`C9SDK_PASSWORD`** in Railway (or your host) before the service starts.

Persist **`/root/.openclaw`** if you need stable sessions and pairing across deploys.
