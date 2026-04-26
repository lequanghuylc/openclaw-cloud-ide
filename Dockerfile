FROM lequanghuylc/c9sdk-pm2-ubuntu:latest

WORKDIR /var/www/html

ENV NVM_DIR=/usr/local/nvm

# OpenClaw needs Node 24; c9sdk/pm2 stays on the image’s Node 12. Install 24, install
# openclaw there, then set nvm default back to 12 so login shells and supervisord PATH match 12.
RUN bash -c 'source "$NVM_DIR/nvm.sh" \
    && nvm install 24 \
    && nvm use 24 \
    && npm install -g openclaw@latest zx@latest \
    && nvm alias default 12'

# Preinstall agent-browser + browser dependencies at build-time so container
# startup is not blocked by large runtime downloads.
RUN bash -c 'source "$NVM_DIR/nvm.sh" \
    && nvm use 24 \
    && npm install -g agent-browser \
    && agent-browser install --with-deps'

# Runtime deps + uv (https://docs.astral.sh/uv/) for skills that use `uv run` (e.g. searxng).
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        cron \
        curl \
        supervisor \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv \
    && uv --version \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html

COPY README.md /var/www/html/README.md
COPY ide-readme /var/www/html/ide-readme
RUN chmod +x /var/www/html/ide-readme/print-instructions.mjs

COPY nginx-conf/openclaw.conf /etc/nginx/sites-enabled/
COPY nginx-conf/project.conf /etc/nginx/sites-enabled/

COPY bootstrap-openclaw.mjs /root/bootstrap-openclaw.mjs
RUN chmod +x /root/bootstrap-openclaw.mjs
COPY bootstrap-openclaw-config.mjs /root/bootstrap-openclaw-config.mjs

COPY bootstrap.sh /root/bootstrap.sh
RUN chmod +x /root/bootstrap.sh

COPY scripts/install-included-skills.sh /var/www/html/scripts/install-included-skills.sh
RUN chmod +x /var/www/html/scripts/install-included-skills.sh

COPY scripts/install-searxng.sh /var/www/html/scripts/install-searxng.sh
RUN chmod +x /var/www/html/scripts/install-searxng.sh

COPY scripts/install-xfce-novnc-cursor.sh /var/www/html/scripts/install-xfce-novnc-cursor.sh
RUN chmod +x /var/www/html/scripts/install-xfce-novnc-cursor.sh

COPY included-skills /var/www/html/included-skills

RUN /var/www/html/scripts/install-searxng.sh

RUN /var/www/html/scripts/install-xfce-novnc-cursor.sh

COPY openclaw.json.template /root/openclaw.json.template

COPY auto-approve-openclaw /root/auto-approve-openclaw
RUN chmod +x /root/auto-approve-openclaw/auto-approve-openclaw-device.mjs

COPY supervisord.conf.template /etc/supervisor/conf.d/supervisord.conf

COPY .nvmrc /.nvmrc

RUN mkdir -p /root/.c9
COPY .c9/user.settings /root/.c9/user.settings

CMD ["/bin/bash", "-lc", "set -euo pipefail; source /usr/local/nvm/nvm.sh && nvm use 24 >/dev/null && export NODE_PATH=\"$(npm root -g)\" && /root/bootstrap.sh"]

EXPOSE 8080 8081 3399 18789 6080
