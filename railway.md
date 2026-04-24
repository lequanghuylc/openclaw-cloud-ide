# OpenClaw with File manager

This template gives you full control of your Openclaw

## Why do we need C9 IDE
- Access to terminal and files, full control of Openclaw config
- Provide a ability to jump in when Openclaw stuck with the tasks
- Do compldex 3rd integrations, even a webserver

## Environment variables

- **`TELEGRAM_BOT_TOKEN`**: Telegram bot token from [@BotFather](https://t.me/BotFather)
- **`OPENAI_API_KEY`**: OpenAI API key for the default model (`openai/gpt-5.4` in `openclaw.json.template`; change the model there if you prefer another OpenAI id)
- **`INITIAL_OPENCLAW_VERSION`**: Optional. npm version to install for OpenClaw on first boot of a fresh `/root/.openclaw` volume (default: `latest`)

These envs are setup for convenient reasons, since ChatGPT and Telegram is mostly used. If you want to have other setup, just keep those env variables blank. Once you have access to the C9 IDE, check [Openclaw's Offcial Docs](https://docs.openclaw.ai/) to know how to connect different AI models and message channels.

- **`C9SDK_PASSWORD`**: password for the c9sdk server (`c9sdk:$C9SDK_PASSWORD`)
- **`OPENCLAW_GATEWAY_TOKEN`**: Token to used with Openclaw dashboard gateway

### Dashboard pairing (auto-approve)

Also for convenient setup, please follow the steps here:
- Make the container up and running (deploy template, run docker image,..etc..)
- Access Dashboard gateway (`http://localhost:18789` or public domain), input password (`OPENCLAW_GATEWAY_TOKEN`). It will fail but it will register the first device
- [A script run in the background and listen the first device trying to pair and automatically approve it]
- Wait for a bit, or check logs in the IDE: `pm2 logs openclaw-auto-approve` (look for `approved successfully, exiting`), or `pm2 logs readme` for a short usage summary
- Login again, now you can access the dashboard
