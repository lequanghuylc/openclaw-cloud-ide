#!/usr/bin/env bash

set -euo pipefail

if [[ -x "/var/www/html/scripts/install-included-skills.sh" ]]; then
  /var/www/html/scripts/install-included-skills.sh
else
  echo "Skill installer script not found, skipping bundled skills install."
fi

if [[ -x "/var/www/html/scripts/install-searxng.sh" ]]; then
  /var/www/html/scripts/install-searxng.sh
else
  echo "SearXNG installer script not found, skipping SearXNG install."
fi

if [[ -f "/root/bootstrap-openclaw.mjs" ]]; then
  zx /root/bootstrap-openclaw.mjs
fi

exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
