// One-shot banner; logs stay in PM2 so users can run: pm2 logs readme
module.exports = {
  apps: [
    {
      name: "readme",
      script: "/var/www/html/ide-readme/print-instructions.mjs",
      autorestart: false,
    },
  ],
};
