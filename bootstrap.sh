#!/usr/bin/env bash

set -euo pipefail

OPENCLAW_STATE_DIR="/root/.openclaw"
BOOTSTRAP_STATE_DIR="/var/lib/openclaw-bootstrap"
OPENCLAW_VERSION_MARKER="${BOOTSTRAP_STATE_DIR}/.initial_openclaw_version"
REQUESTED_OPENCLAW_VERSION="${INITIAL_OPENCLAW_VERSION:-latest}"
RUN_SEARXNG_INSTALL_ON_START="${RUN_SEARXNG_INSTALL_ON_START:-0}"

mkdir -p "${OPENCLAW_STATE_DIR}"
mkdir -p "${BOOTSTRAP_STATE_DIR}"

if [[ ! -f "${OPENCLAW_VERSION_MARKER}" || "$(tr -d '\n\r' <"${OPENCLAW_VERSION_MARKER}")" != "${REQUESTED_OPENCLAW_VERSION}" ]]; then
  echo "Installing initial OpenClaw version: ${REQUESTED_OPENCLAW_VERSION}"
  npm install -g "openclaw@${REQUESTED_OPENCLAW_VERSION}"
  printf "%s\n" "${REQUESTED_OPENCLAW_VERSION}" > "${OPENCLAW_VERSION_MARKER}"
else
  echo "Initial OpenClaw version already set ($(tr -d '\n\r' <"${OPENCLAW_VERSION_MARKER}")), skipping install."
fi

if [[ "${RUN_SEARXNG_INSTALL_ON_START}" == "1" ]] && [[ -x "/var/www/html/scripts/install-searxng.sh" ]]; then
  /var/www/html/scripts/install-searxng.sh
elif [[ "${RUN_SEARXNG_INSTALL_ON_START}" != "1" ]]; then
  echo "Skipping SearXNG reinstall on startup (set RUN_SEARXNG_INSTALL_ON_START=1 to enable)."
else
  echo "SearXNG installer script not found, skipping SearXNG install."
fi

if [[ -f "/root/bootstrap-openclaw.mjs" ]]; then
  zx /root/bootstrap-openclaw.mjs
fi

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
