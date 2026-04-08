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

# Runtime deps
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        cron \
        curl \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html

COPY nginx-conf/openclaw.conf /etc/nginx/sites-enabled/
COPY nginx-conf/project.conf /etc/nginx/sites-enabled/

COPY bootstrap-openclaw.mjs /root/bootstrap-openclaw.mjs
RUN chmod +x /root/bootstrap-openclaw.mjs

COPY openclaw.json.template /root/openclaw.json.template

COPY auto-approve-openclaw-device.mjs /root/auto-approve-openclaw-device.mjs
RUN chmod +x /root/auto-approve-openclaw-device.mjs

COPY supervisord.conf.template /etc/supervisor/conf.d/supervisord.conf

COPY .nvmrc /.nvmrc

CMD ["/bin/bash", "-lc", "set -euo pipefail; source /usr/local/nvm/nvm.sh && nvm use 24 >/dev/null && export NODE_PATH=\"$(npm root -g)\" && zx /root/bootstrap-openclaw.mjs; exec supervisord -c /etc/supervisor/conf.d/supervisord.conf"]

EXPOSE 8080 8081 3399 18789
