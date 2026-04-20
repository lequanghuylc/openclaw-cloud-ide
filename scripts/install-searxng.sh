#!/usr/bin/env bash
# Install SearXNG from source (git + venv) for local metasearch used by the searxng OpenClaw skill.
# See: https://docs.searxng.org/admin/installation-searxng.html
# Port defaults to 8888 to avoid clashing with nginx (8080) in this image.

set -euo pipefail

SEARXNG_HOME="${SEARXNG_HOME:-/opt/searxng}"
SRC="${SEARXNG_HOME}/searxng-src"
VENV="${SEARXNG_HOME}/searx-pyenv"
SETTINGS_DIR="${SEARXNG_SETTINGS_DIR:-/etc/searxng}"
SETTINGS="${SETTINGS_DIR}/settings.yml"
SECRET_FILE="${SETTINGS_DIR}/secret_key"
LIMITER_FILE="${SETTINGS_DIR}/limiter.toml"
SEARXNG_PORT="${SEARXNG_PORT:-8888}"

usage() {
  cat <<EOF
Usage: scripts/install-searxng.sh

Environment (optional):
  SEARXNG_HOME          Install root (default: /opt/searxng)
  SEARXNG_PORT          Listen port (default: 8888; use with SEARXNG_URL in openclaw.json)
  SEARXNG_SETTINGS_DIR  Directory for settings.yml (default: /etc/searxng)

Requires root (apt, /etc, /opt). Idempotent: safe to run on every container start.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "install-searxng.sh: must run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

ensure_apt_deps() {
  if dpkg -s python3-venv git build-essential libxslt1-dev zlib1g-dev &>/dev/null; then
    return 0
  fi
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    python3-dev \
    python3-babel \
    python3-venv \
    python-is-python3 \
    git \
    build-essential \
    libxslt1-dev \
    zlib1g-dev \
    libffi-dev \
    libssl-dev \
    openssl \
    ca-certificates
}

clone_or_update() {
  mkdir -p "$SEARXNG_HOME"
  if [[ ! -d "$SRC/.git" ]]; then
    rm -rf "$SRC"
    git clone --depth 1 "https://github.com/searxng/searxng.git" "$SRC"
  else
    git -C "$SRC" pull --ff-only || true
  fi
}

install_python_deps() {
  local rev
  rev="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo "")"
  if [[ -n "$rev" && -f "$VENV/.searxng-rev" && "$(tr -d '\n\r' <"$VENV/.searxng-rev")" == "$rev" && -f "$VENV/bin/activate" ]]; then
    echo "OK    SearXNG: venv already matches commit ${rev}, skipping pip install"
    ensure_tomllib_compat
    return 0
  fi
  if [[ ! -d "$VENV" ]]; then
    python3 -m venv "$VENV"
  fi
  # shellcheck disable=SC1090
  source "${VENV}/bin/activate"
  pip install -U pip setuptools wheel
  pip install -U pyyaml msgspec typing-extensions pybind11
  (cd "$SRC" && pip install --use-pep517 --no-build-isolation -e .)
  ensure_tomllib_compat
  printf '%s' "$rev" >"$VENV/.searxng-rev"
  deactivate
}

ensure_tomllib_compat() {
  local py="${VENV}/bin/python"
  local pip_bin="${VENV}/bin/pip"
  local site_pkgs
  local shim_path

  if "$py" - <<'PY' >/dev/null 2>&1
import tomllib
PY
  then
    return 0
  fi

  echo "INFO  SearXNG: Python lacks tomllib; installing tomli compatibility shim"
  "$pip_bin" install -U tomli
  site_pkgs="$("$py" - <<'PY'
import site
print(site.getsitepackages()[0])
PY
)"
  shim_path="${site_pkgs}/tomllib.py"
  cat >"$shim_path" <<'PY'
from tomli import TOMLDecodeError, load, loads

__all__ = ["load", "loads", "TOMLDecodeError"]
PY
}

write_settings() {
  mkdir -p "$SETTINGS_DIR"
  local secret
  if [[ -f "$SECRET_FILE" ]]; then
    secret="$(tr -d '\n\r' <"$SECRET_FILE")"
  else
    secret="$(openssl rand -hex 32)"
    umask 077
    printf '%s' "$secret" >"$SECRET_FILE"
    umask 022
  fi
  if [[ -f "$SETTINGS" ]]; then
    local current_port
    current_port="$(grep -E '^[[:space:]]*port:[[:space:]]*[0-9]+' "$SETTINGS" | head -1 | awk '{print $2}' || true)"
    if [[ "${current_port:-}" == "$SEARXNG_PORT" ]]; then
      echo "OK    SearXNG: ${SETTINGS} already uses port ${SEARXNG_PORT}, not rewriting"
      return 0
    fi
  fi
  cat >"$SETTINGS" <<EOF
use_default_settings: true

general:
  debug: false
  instance_name: "SearXNG (OpenClaw)"

server:
  secret_key: "${secret}"
  port: ${SEARXNG_PORT}
  bind_address: "127.0.0.1"
  limiter: false

search:
  formats:
    - html
    - json

# Disable engines that are noisy/unreliable in lightweight local container setups.
engines:
  - name: ahmia
    disabled: true
  - name: torch
    disabled: true
  - name: wikidata
    disabled: true
EOF
  chmod 0644 "$SETTINGS"
}

write_limiter_config() {
  mkdir -p "$SETTINGS_DIR"
  if [[ -f "$LIMITER_FILE" ]]; then
    return 0
  fi
  if [[ -f "${SRC}/searx/limiter.toml" ]]; then
    cp "${SRC}/searx/limiter.toml" "$LIMITER_FILE"
  else
    cat >"$LIMITER_FILE" <<'EOF'
[botdetection]
ipv4_prefix = 32
ipv6_prefix = 48
trusted_proxies = ['127.0.0.0/8', '::1']

[botdetection.ip_limit]
filter_link_local = false
link_token = false

[botdetection.ip_lists]
block_ip = []
pass_ip = []
pass_searxng_org = true
EOF
  fi
  chmod 0644 "$LIMITER_FILE"
}

patch_sqlite_log_level() {
  local sqlitedb="${SRC}/searx/sqlitedb.py"
  if [[ -f "$sqlitedb" ]] && grep -q "logger.error(msg)" "$sqlitedb"; then
    sed -i "s/logger.error(msg)/logger.warning(msg)/g" "$sqlitedb"
  fi
}

ensure_apt_deps
clone_or_update
install_python_deps
write_settings
write_limiter_config
patch_sqlite_log_level

echo "OK    SearXNG: installed under ${SEARXNG_HOME} (settings: ${SETTINGS}, bind 127.0.0.1:${SEARXNG_PORT})"
