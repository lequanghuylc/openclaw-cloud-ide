import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const installerUrl = new URL("../scripts/install-xfce-novnc-cursor.sh", import.meta.url);

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
