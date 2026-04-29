#!/usr/bin/env bash
# Install XFCE + x11vnc + noVNC (websockify) and Cursor (AppImage) so the
# container exposes a graphical desktop over the browser. After the container
# starts and you log into noVNC, the XFCE desktop has a Cursor launcher ready
# to use.
#
# Web client is served by websockify (noVNC) on $NOVNC_PORT (default 6080).
# x11vnc binds to 127.0.0.1:$VNC_PORT (default 5901) over an Xvfb display.

set -euo pipefail

NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_PORT="${VNC_PORT:-5901}"
VNC_DISPLAY="${VNC_DISPLAY:-:1}"
NOVNC_HOME="${NOVNC_HOME:-/opt/novnc}"
NOVNC_VERSION="${NOVNC_VERSION:-1.5.0}"
WEBSOCKIFY_VERSION="${WEBSOCKIFY_VERSION:-0.12.0}"
CURSOR_HOME="${CURSOR_HOME:-/opt/cursor}"
CURSOR_APPIMAGE_URL="${CURSOR_APPIMAGE_URL:-https://cursor.com/api/download?platform=linux-x64&releaseTrack=stable}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "install-xfce-novnc-cursor.sh: must run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

install_apt_deps() {
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    gnupg \
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    dbus-x11 \
    xvfb \
    x11vnc \
    xauth \
    novnc \
    websockify \
    python3 \
    python3-numpy \
    fonts-dejavu \
    fonts-liberation \
    libnss3 \
    libgbm1 \
    libxss1 \
    libasound2 \
    libsecret-1-0 \
    libgtk-3-0 \
    libnotify4 \
    libxtst6 \
    libdrm2 \
    libxkbfile1 \
    libfuse2 \
    fuse \
    file \
    wget \
    xdg-utils \
    sqlite3 \
    curl \
    ca-certificates
  rm -rf /var/lib/apt/lists/*
}

install_firefox_from_mozilla_apt() {
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
    -o /etc/apt/keyrings/packages.mozilla.org.asc

  cat >/etc/apt/sources.list.d/mozilla.list <<'MOZILLA'
deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main
MOZILLA

  cat >/etc/apt/preferences.d/mozilla <<'PIN'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
PIN

  apt-get update -qq
  apt-get install -y --no-install-recommends firefox
  rm -rf /var/lib/apt/lists/*
}

install_novnc_static() {
  # Pin a known-good noVNC release so the web client is stable across image
  # rebuilds even if the apt package changes.
  mkdir -p "$NOVNC_HOME"
  if [[ ! -f "$NOVNC_HOME/.version" ]] || [[ "$(cat "$NOVNC_HOME/.version" 2>/dev/null || true)" != "${NOVNC_VERSION}" ]]; then
    rm -rf "$NOVNC_HOME"/*
    curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" \
      | tar -xz --strip-components=1 -C "$NOVNC_HOME"
    # vnc.html is the full client; symlink to index.html for "/" entry.
    ln -sf vnc.html "$NOVNC_HOME/index.html"
    printf '%s' "$NOVNC_VERSION" >"$NOVNC_HOME/.version"
  fi
}

resolve_cursor_appimage_url() {
  local url="$1"

  if [[ "$url" != *"/api/download"* ]]; then
    printf '%s\n' "$url"
    return
  fi

  curl -fsSL -A 'Mozilla/5.0' "$url" \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["downloadUrl"])'
}

install_cursor() {
  mkdir -p "$CURSOR_HOME"
  local appimage="${CURSOR_HOME}/cursor.AppImage"
  if [[ ! -f "$appimage" ]]; then
    local download_url
    download_url="$(resolve_cursor_appimage_url "$CURSOR_APPIMAGE_URL")"

    echo "Downloading Cursor AppImage from ${download_url}"
    curl -fL --retry 3 --retry-delay 2 -o "$appimage" "$download_url"
    chmod +x "$appimage"
  fi

  # FUSE is unreliable in containers; extract once so we can run AppRun directly.
  if [[ ! -d "${CURSOR_HOME}/squashfs-root" ]]; then
    (cd "$CURSOR_HOME" && "$appimage" --appimage-extract >/dev/null)
  fi

  # Launcher flags:
  #   --no-sandbox                Electron's setuid sandbox is unavailable when
  #                               running as root inside the container.
  #   --disable-gpu
  #   --disable-software-rasterizer
  #                               noVNC/Xvfb sessions can crash Electron's
  #                               shared process during GPU initialization.
  #   --disable-dev-shm-usage     /dev/shm is often small in containers; this
  #                               avoids renderer crashes caused by SHM limits.
  #   --password-store=basic      Force Electron's safeStorage onto a local
  #                               file-backed store instead of libsecret /
  #                               gnome-keyring, so Cursor auth persists.
  cat >/usr/local/bin/cursor <<'LAUNCHER'
#!/usr/bin/env bash
export BROWSER="${BROWSER:-/usr/local/bin/default-browser}"
exec /opt/cursor/squashfs-root/AppRun \
  --no-sandbox \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-dev-shm-usage \
  --password-store=basic \
  "$@"
LAUNCHER
  chmod +x /usr/local/bin/cursor

  # Desktop entry so XFCE's app finder / panel / desktop shortcut can launch it.
  mkdir -p /usr/share/applications
  cat >/usr/share/applications/cursor.desktop <<'DESKTOP'
[Desktop Entry]
Name=Cursor
Comment=AI-first code editor
Exec=/usr/local/bin/cursor %F
Icon=/opt/cursor/squashfs-root/co.anysphere.cursor.png
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Cursor
DESKTOP

  # Best-effort icon: AppImages name the icon differently across releases.
  if [[ ! -f /opt/cursor/squashfs-root/co.anysphere.cursor.png ]]; then
    local fallback_icon
    fallback_icon="$(find /opt/cursor/squashfs-root -maxdepth 2 -name '*.png' | head -n1 || true)"
    if [[ -n "$fallback_icon" ]]; then
      sed -i "s|^Icon=.*|Icon=${fallback_icon}|" /usr/share/applications/cursor.desktop
    fi
  fi
}

configure_default_browser() {
  local firefox_bin=""
  if command -v firefox >/dev/null 2>&1; then
    firefox_bin="$(command -v firefox)"
  fi

  local chrome_bin=""
  if command -v google-chrome >/dev/null 2>&1; then
    chrome_bin="$(command -v google-chrome)"
  elif command -v google-chrome-stable >/dev/null 2>&1; then
    chrome_bin="$(command -v google-chrome-stable)"
  fi

  if [[ -z "$firefox_bin" && -z "$chrome_bin" ]]; then
    echo "WARN  No supported browser found; web links may not open automatically" >&2
    return
  fi

  # Prefer Firefox (primary desktop browser). Fall back to Chrome when needed.
  if [[ -n "$firefox_bin" ]]; then
    cat >/usr/local/bin/default-browser <<BROWSER
#!/usr/bin/env bash
exec "$firefox_bin" "\$@"
BROWSER
  else
    cat >/usr/local/bin/default-browser <<BROWSER
#!/usr/bin/env bash
exec "$chrome_bin" --no-sandbox "\$@"
BROWSER
  fi
  chmod +x /usr/local/bin/default-browser

  cat >/usr/share/applications/default-browser.desktop <<'DESKTOP'
[Desktop Entry]
Name=Default Browser
Comment=Open web links in Chrome
Exec=/usr/local/bin/default-browser %U
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
DESKTOP

  mkdir -p /root/.config
  cat >/root/.config/mimeapps.list <<'MIMEAPPS'
[Default Applications]
text/html=default-browser.desktop
text/xml=default-browser.desktop
application/xhtml+xml=default-browser.desktop
x-scheme-handler/http=default-browser.desktop
x-scheme-handler/https=default-browser.desktop
MIMEAPPS

  mkdir -p /root/.config/xfce4
  cat >/root/.config/xfce4/helpers.rc <<'HELPERS'
WebBrowser=debian-sensible-browser
HELPERS
}

write_cursor_auth_exporter() {
  mkdir -p /root/.config/Cursor

  cat >/root/.config/Cursor/export-cursor-auth.mjs <<'EXPORTER'
#!/usr/bin/env zx
import { chmod, readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { $ } from "zx";

const CURSOR_CONFIG_DIR = "/root/.config/Cursor";
const GLOBAL_STORAGE_DIR = `${CURSOR_CONFIG_DIR}/User/globalStorage`;
const STATE_DB = `${GLOBAL_STORAGE_DIR}/state.vscdb`;
const STORAGE_JSON = `${GLOBAL_STORAGE_DIR}/storage.json`;
const OUTPUT_FILE = "/root/.config/Cursor/cursor-auth.json";

async function ensureSqlite3() {
  try {
    await $`command -v sqlite3`;
  } catch {
    await $`apt-get update`;
    await $`apt-get install -y sqlite3`;
  }
}

async function readSqliteValue(key) {
  const sql = `select value from ItemTable where key='${key.replaceAll("'", "''")}';`;
  const result = await $`sqlite3 ${STATE_DB} ${sql}`;
  return result.stdout.trimEnd();
}

async function readMachineId() {
  const storage = JSON.parse(await readFile(STORAGE_JSON, "utf8"));
  return storage["telemetry.machineId"] ?? "";
}

function assertExists(file, description) {
  if (!existsSync(file)) {
    throw new Error(`${description} not found at ${file}. Log in to Cursor first, then rerun this script.`);
  }
}

async function main() {
  await ensureSqlite3();
  assertExists(STATE_DB, "Cursor auth database");
  assertExists(STORAGE_JSON, "Cursor storage file");

  const auth = {
    accessToken: await readSqliteValue("cursorAuth/accessToken"),
    refreshToken: await readSqliteValue("cursorAuth/refreshToken"),
    cachedEmail: await readSqliteValue("cursorAuth/cachedEmail"),
    machineId: await readMachineId(),
  };

  await writeFile(OUTPUT_FILE, `${JSON.stringify(auth, null, 2)}\n`, "utf8");
  await chmod(OUTPUT_FILE, 0o600);

  console.log(`Wrote Cursor auth info to ${OUTPUT_FILE}`);
}

await main();
EXPORTER

  chmod +x /root/.config/Cursor/export-cursor-auth.mjs
}

write_x11vnc_startup() {
  cat >/usr/local/bin/start-x11vnc.sh <<'VNCSTART'
#!/usr/bin/env bash
set -euo pipefail

base_args=(
  -display "${DISPLAY:-:1}"
  -forever
  -shared
  -rfbport "${VNC_PORT:-5901}"
  -localhost
  -xkb
)

if [[ -n "${VNC_PASSWORD:-}" ]]; then
  passwd_file="/root/.vnc/passwd"
  mkdir -p "$(dirname "$passwd_file")"
  x11vnc -storepasswd "$VNC_PASSWORD" "$passwd_file" >/dev/null
  chmod 600 "$passwd_file"
  exec /usr/bin/x11vnc "${base_args[@]}" -rfbauth "$passwd_file"
fi

exec /usr/bin/x11vnc "${base_args[@]}" -nopw
VNCSTART

  chmod +x /usr/local/bin/start-x11vnc.sh
}

write_desktop_shortcut() {
  # Drop a Cursor launcher on the XFCE Desktop for the root user (the user that
  # noVNC logs in as) so it is one click away after first login.
  local desktop_dir="/root/Desktop"
  mkdir -p "$desktop_dir"
  cp /usr/share/applications/cursor.desktop "$desktop_dir/cursor.desktop"
  chmod +x "$desktop_dir/cursor.desktop"
}

write_xstartup() {
  # Used by supervisord to launch the XFCE session against Xvfb.
  cat >/usr/local/bin/start-xfce-session.sh <<'XSTART'
#!/usr/bin/env bash
set -euo pipefail
export DISPLAY="${DISPLAY:-:1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
export BROWSER="${BROWSER:-/usr/local/bin/default-browser}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
# Disable screensaver/lock so the noVNC session never gets a black screen.
xset -dpms 2>/dev/null || true
xset s off 2>/dev/null || true
exec dbus-launch --exit-with-session startxfce4
XSTART
  chmod +x /usr/local/bin/start-xfce-session.sh
}

install_apt_deps
install_firefox_from_mozilla_apt
install_novnc_static
install_cursor
configure_default_browser
write_cursor_auth_exporter
write_x11vnc_startup
write_desktop_shortcut
write_xstartup

echo "OK    XFCE + noVNC + Cursor + Firefox installed (noVNC port: ${NOVNC_PORT}, VNC port: ${VNC_PORT}, display: ${VNC_DISPLAY})"
