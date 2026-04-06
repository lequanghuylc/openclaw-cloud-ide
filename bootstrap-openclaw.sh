#!/bin/bash
set -euo pipefail

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is required}"
: "${OPENAI_API_KEY:?OPENAI_API_KEY is required}"

export TELEGRAM_BOT_TOKEN
mkdir -p /root/.openclaw/workspace
# Pin Node 22 for shells that `cd` here (nvm + .nvmrc integration).
printf '%s\n' '22' > /root/.openclaw/.nvmrc
umask 077
envsubst '${TELEGRAM_BOT_TOKEN}' < /root/openclaw.json.template > /root/.openclaw/openclaw.json
chmod 600 /root/.openclaw/openclaw.json 2>/dev/null || true
