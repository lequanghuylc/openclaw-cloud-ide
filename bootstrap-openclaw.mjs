#!/usr/bin/env zx
import { mkdir, readFile, writeFile, chmod } from "node:fs/promises";

const OPENCLAW_DIR = "/root/.openclaw";
const WORKSPACE_DIR = `${OPENCLAW_DIR}/workspace`;
const NVMRC_PATH = `${OPENCLAW_DIR}/.nvmrc`;
const TEMPLATE_PATH = "/root/openclaw.json.template";
const OUTPUT_PATH = `${OPENCLAW_DIR}/openclaw.json`;

const telegramBotToken = process.env.TELEGRAM_BOT_TOKEN ?? "";

await mkdir(WORKSPACE_DIR, { recursive: true });

// Pin Node 24 for shells that `cd` here (nvm + .nvmrc integration).
await writeFile(NVMRC_PATH, "24\n", "utf8");

const template = await readFile(TEMPLATE_PATH, "utf8");
const openclawJson = template.replaceAll("${TELEGRAM_BOT_TOKEN}", telegramBotToken);

await writeFile(OUTPUT_PATH, openclawJson, {
  encoding: "utf8",
  mode: 0o600,
});

try {
  await chmod(OUTPUT_PATH, 0o600);
} catch {
  // Ignore chmod failures on environments that do not support changing mode.
}
