FROM ghcr.io/duartesantos8/opengym-web:latest

USER root

# Install Node.js and pull the openGym API server
RUN apk add --no-cache nodejs npm git && \
    git clone --depth 1 https://github.com/DuarteSantos8/openGym.git /tmp/opengym && \
    cp -r /tmp/opengym/api /opt/opengym-api && \
    cd /opt/opengym-api && npm ci --omit=dev && \
    rm -rf /tmp/opengym

# Write a direct Nginx config to serve the frontend and proxy the API
RUN printf 'server {\n\
    listen 10000;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    client_max_body_size 50M;\n\
    location / {\n\
        try_files $uri /index.html;\n\
    }\n\
    location /api {\n\
        proxy_pass http://127.0.0.1:3000;\n\
        proxy_http_version 1.1;\n\
        proxy_set_header Host $host;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

# Prevent Nginx from overwriting our config on startup
RUN rm -rf /etc/nginx/templates/*

# Tell Render to route public internet traffic to Nginx (10000)
ENV PORT=10000 \
    DATA_DIR=/data \
    FIRST_USER_ADMIN=1 \
    PASSWORD_LOGIN=1

# Force the backend API to run on port 3000 internally
RUN printf '#!/bin/sh\nexport PORT=3000\nnode /opt/opengym-api/server.js &\n' > /docker-entrypoint.d/99-start-api.sh && \
    chmod +x /docker-entrypoint.d/99-start-api.sh

EXPOSE 10000
