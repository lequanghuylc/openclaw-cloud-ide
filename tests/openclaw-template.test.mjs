import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("disables Bonjour discovery by default for container deployments", async () => {
  const template = await readFile(new URL("../openclaw.json.template", import.meta.url), "utf8");
  const cfg = JSON.parse(template.replaceAll("${TELEGRAM_BOT_TOKEN}", ""));

  assert.equal(cfg.plugins.entries.bonjour.enabled, false);
});
