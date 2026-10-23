FROM ghcr.io/duartesantos8/opengym-web:latest

USER root

# Install Node.js and pull the openGym API server
RUN apk add --no-cache nodejs npm git && \
    git clone --depth 1 https://github.com/DuarteSantos8/openGym.git /tmp/opengym && \
    cp -r /tmp/opengym/api /opt/opengym-api && \
    cd /opt/opengym-api && npm ci --omit=dev && \
    rm -rf /tmp/opengym && \
    mkdir -p /data /var/cache/nginx /var/run /run && \
    chmod -R 777 /data /var/cache/nginx /var/run /run /etc/nginx/conf.d

# Configure Nginx to listen on port 10000 (Render's default port)
RUN sed -i 's/listen\s*80;/listen 10000;/g' /etc/nginx/conf.d/default.conf || true && \
    sed -i 's|/var/run/nginx.pid|/tmp/nginx.pid|g' /etc/nginx/nginx.conf

ENV NGINX_PORT=10000 \
    BACKEND=127.0.0.1 \
    PORT=3000 \
    DATA_DIR=/data \
    FIRST_USER_ADMIN=1 \
    PASSWORD_LOGIN=1

# Launch the Node API in the background right before Nginx starts
RUN printf '#!/bin/sh\nnode /opt/opengym-api/server.js &\n' > /docker-entrypoint.d/99-start-api.sh && \
    chmod +x /docker-entrypoint.d/99-start-api.sh

EXPOSE 10000
