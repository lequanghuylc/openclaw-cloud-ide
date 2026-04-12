// Run under Node 24 + global zx; do not restart when the process exits (one-shot approve helper).
const scriptPath =
  "/root/auto-approve-openclaw/auto-approve-openclaw-device.mjs";

module.exports = {
  apps: [
    {
      name: "openclaw-auto-approve",
      script: "/bin/bash",
      args: [
        "-lc",
        "source /usr/local/nvm/nvm.sh && nvm use 24 >/dev/null && export NODE_PATH=\"$(npm root -g)\" && cd /root/.openclaw && exec zx " +
          JSON.stringify(scriptPath),
      ],
      autorestart: false,
    },
  ],
};
