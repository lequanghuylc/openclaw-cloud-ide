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
CURSOR_APPIMAGE_URL="${CURSOR_APPIMAGE_URL:-https://downloader.cursor.sh/linux/appImage/x64}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "install-xfce-novnc-cursor.sh: must run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

install_apt_deps() {
  apt-get update -qq
  apt-get install -y --no-install-recommends \
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
    curl \
    ca-certificates
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

install_cursor() {
  mkdir -p "$CURSOR_HOME"
  local appimage="${CURSOR_HOME}/cursor.AppImage"
  if [[ ! -f "$appimage" ]]; then
    echo "Downloading Cursor AppImage from ${CURSOR_APPIMAGE_URL}"
    curl -fL --retry 3 --retry-delay 2 -o "$appimage" "$CURSOR_APPIMAGE_URL"
    chmod +x "$appimage"
  fi

  # FUSE is unreliable in containers; extract once so we can run AppRun directly.
  if [[ ! -d "${CURSOR_HOME}/squashfs-root" ]]; then
    (cd "$CURSOR_HOME" && "$appimage" --appimage-extract >/dev/null)
  fi

  # Launcher: AppImages and Electron run as root require --no-sandbox.
  cat >/usr/local/bin/cursor <<'LAUNCHER'
#!/usr/bin/env bash
exec /opt/cursor/squashfs-root/AppRun --no-sandbox "$@"
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
install_novnc_static
install_cursor
write_desktop_shortcut
write_xstartup

echo "OK    XFCE + noVNC + Cursor installed (noVNC port: ${NOVNC_PORT}, VNC port: ${VNC_PORT}, display: ${VNC_DISPLAY})"
