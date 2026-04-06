FROM lequanghuylc/c9sdk-pm2-ubuntu:latest

WORKDIR /var/www/html

ENV NVM_DIR=/usr/local/nvm

# OpenClaw needs Node 22; c9sdk/pm2 stays on the image’s Node 12. Install 22, install
# openclaw there, then set nvm default back to 12 so login shells and supervisord PATH match 12.
RUN bash -c 'source "$NVM_DIR/nvm.sh" \
    && nvm install 22 \
    && nvm use 22 \
    && npm install -g openclaw@latest zx@latest \
    && nvm alias default 12'

# Runtime deps; php-fpm remains installed so the stock supervisor php-fpm program keeps working.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        cron \
        curl \
        gettext-base \
        php8.1-fpm \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html

COPY nginx-conf/openclaw.conf /etc/nginx/sites-enabled/
COPY nginx-conf/project.conf /etc/nginx/sites-enabled/

COPY bootstrap-openclaw.sh /root/bootstrap-openclaw.sh
RUN chmod +x /root/bootstrap-openclaw.sh

COPY openclaw.json.template /root/openclaw.json.template

COPY auto-approve-openclaw-device.mjs /root/auto-approve-openclaw-device.mjs
RUN chmod +x /root/auto-approve-openclaw-device.mjs

COPY supervisord.conf.template /etc/supervisor/conf.d/supervisord.conf

CMD ["/bin/bash", "-lc", "set -euo pipefail; /root/bootstrap-openclaw.sh; exec supervisord -c /etc/supervisor/conf.d/supervisord.conf"]

EXPOSE 8080 8081 3399 18789
