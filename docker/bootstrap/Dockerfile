FROM ghcr.io/openclaw/openclaw:2026.3.8

USER root
RUN apt-get update && apt-get install -y --no-install-recommends bash curl ca-certificates jq gettext-base \
  && rm -rf /var/lib/apt/lists/*

COPY scripts/entrypoint-init.sh /opt/openclaw/entrypoint-init.sh
COPY openclaw.defaults.json.tmpl /opt/openclaw/openclaw.defaults.json.tmpl
COPY seed/ /opt/openclaw/seed/
RUN chmod +x /opt/openclaw/entrypoint-init.sh

USER node
WORKDIR /home/node

ENTRYPOINT ["/opt/openclaw/entrypoint-init.sh"]