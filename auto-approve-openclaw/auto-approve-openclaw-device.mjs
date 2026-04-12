#!/usr/bin/env zx

$.verbose = false;

const INTERVAL_MS = Number(process.env.OPENCLAW_AUTO_APPROVE_INTERVAL ?? 3) * 1000;
const HEALTH_URL = process.env.OPENCLAW_HEALTH_URL ?? "http://127.0.0.1:18789/healthz";
const GATEWAY_TOKEN = process.env.OPENCLAW_GATEWAY_TOKEN;

cd("/root/.openclaw");

const log = (...args) => console.log("[openclaw-auto-approve]", ...args);

log(
  "starting",
  `cwd=${process.cwd()}`,
  `intervalMs=${INTERVAL_MS}`,
  `health=${HEALTH_URL}`,
  `tokenConfigured=${Boolean(GATEWAY_TOKEN)}`,
);

function pendingList(list) {
  if (Array.isArray(list?.pending)) return list.pending;
  if (Array.isArray(list?.pendingRequests)) return list.pendingRequests;
  return [];
}

while (true) {
  try {
    const res = await fetch(HEALTH_URL, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) throw new Error(`health ${res.status}`);
  } catch (err) {
    log(
      "gateway not ready, sleeping",
      String(err?.message ?? err),
      `retryInMs=${INTERVAL_MS}`,
    );
    await new Promise((r) => setTimeout(r, INTERVAL_MS));
    continue;
  }

  let list;
  try {
    const out = await $`openclaw devices list --json`;
    list = JSON.parse(out.stdout);
  } catch (err) {
    log(
      "openclaw devices list --json failed, sleeping",
      String(err?.message ?? err),
      `retryInMs=${INTERVAL_MS}`,
    );
    await new Promise((r) => setTimeout(r, INTERVAL_MS));
    continue;
  }

  const pending = pendingList(list);
  if (pending.length === 0) {
    log("no pending device requests, sleeping", `retryInMs=${INTERVAL_MS}`);
    await new Promise((r) => setTimeout(r, INTERVAL_MS));
    continue;
  }

  const requestId = pending[0]?.requestId ?? pending[0]?.id;
  if (!requestId) {
    log(
      "pending entry missing requestId/id, sleeping",
      JSON.stringify(pending[0]),
      `retryInMs=${INTERVAL_MS}`,
    );
    await new Promise((r) => setTimeout(r, INTERVAL_MS));
    continue;
  }

  try {
    log("approving pending request", requestId);
    // CLI: https://docs.clawd.bot/cli/devices — subcommand is `devices approve`, not `pairing approve`
    await $`openclaw devices approve ${requestId}`;
    log("approved successfully, exiting");
    process.exit(0);
  } catch (err) {
    log(
      "devices approve failed, sleeping",
      requestId,
      String(err?.message ?? err),
      `retryInMs=${INTERVAL_MS}`,
    );
    await new Promise((r) => setTimeout(r, INTERVAL_MS));
  }
}
