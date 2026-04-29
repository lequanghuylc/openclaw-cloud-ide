import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const installerUrl = new URL("../scripts/install-xfce-novnc-cursor.sh", import.meta.url);
const supervisordUrl = new URL("../supervisord.conf.template", import.meta.url);
const composeUrl = new URL("../docker-compose.yml", import.meta.url);

test("installs a post-login Cursor auth export helper", async () => {
  const installer = await readFile(installerUrl, "utf8");

  assert.match(installer, /apt-get install[\s\S]*\bsqlite3\b/);
  assert.match(installer, /\/root\/\.config\/Cursor\/export-cursor-auth\.mjs/);
  assert.match(installer, /cursorAuth\/accessToken/);
  assert.match(installer, /cursorAuth\/refreshToken/);
  assert.match(installer, /telemetry\.machineId/);
  assert.match(installer, /\/root\/\.config\/Cursor\/cursor-auth\.json/);
  assert.match(installer, /chmod\(OUTPUT_FILE, 0o600\)/);
});

test("supports optional VNC_PASSWORD for noVNC connections", async () => {
  const installer = await readFile(installerUrl, "utf8");
  const supervisord = await readFile(supervisordUrl, "utf8");
  const compose = await readFile(composeUrl, "utf8");

  assert.match(installer, /\/usr\/local\/bin\/start-x11vnc\.sh/);
  assert.match(installer, /VNC_PASSWORD/);
  assert.match(installer, /x11vnc -storepasswd "\$VNC_PASSWORD" "\$passwd_file"/);
  assert.match(installer, /-rfbauth "\$passwd_file"/);
  assert.match(installer, /-nopw/);

  assert.match(supervisord, /command=\/usr\/local\/bin\/start-x11vnc\.sh/);
  assert.match(supervisord, /VNC_PASSWORD="%\(ENV_VNC_PASSWORD\)s"/);

  assert.match(compose, /VNC_PASSWORD: \$\{VNC_PASSWORD:-\}/);
});
