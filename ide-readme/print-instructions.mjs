#!/usr/bin/env node

const lines = [
  "",
  "========== OpenClaw IDE quick reference ==========",
  "",
  "1) Dashboard pairing (auto-approve)",
  '   The PM2 app "openclaw-auto-approve" waits for the gateway, then approves the first pending device once and exits.',
  "   Full steps and context: open README.md in this workspace (section \"Dashboard pairing (auto-approve)\").",
  '   Live output from the helper: pm2 logs openclaw-auto-approve',
  "",
  "2) Restart the OpenClaw gateway",
  "   pm2 restart openclaw-gateway",
  "",
  "3) Edit OpenClaw configuration",
  "   Edit /root/.openclaw/openclaw.json",
  "",
  "Show this message again: pm2 logs readme",
  "",
];

for (const line of lines) {
  console.log(line);
}
