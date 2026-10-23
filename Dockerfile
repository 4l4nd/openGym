FROM ghcr.io/duartesantos8/opengym-web:latest

USER root

# Install Node.js, npm, git, and clone the API code
RUN apk add --no-cache nodejs npm git && \
    git clone --depth 1 https://github.com/DuarteSantos8/openGym.git /tmp/opengym && \
    cp -r /tmp/opengym/api /opt/opengym-api && \
    cd /opt/opengym-api && npm ci --omit=dev && \
    rm -rf /tmp/opengym

# Clean out all default templates and entrypoint scripts so Nginx cannot overwrite our config
RUN rm -rf /etc/nginx/templates /docker-entrypoint.d/* /etc/nginx/conf.d/*

# Write a clean, standalone Nginx configuration for Render on port 10000
RUN printf 'server {\n\
    listen 10000 default_server;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    client_max_body_size 50M;\n\
\n\
    location /api/ {\n\
        proxy_pass http://127.0.0.1:3000/api/;\n\
        proxy_http_version 1.1;\n\
        proxy_set_header Host $host;\n\
        proxy_set_header X-Real-IP $remote_addr;\n\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n\
        proxy_set_header X-Forwarded-Proto $scheme;\n\
    }\n\
\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

# Create the startup script to run both Node API and Nginx
RUN printf '#!/bin/sh\n\
export PORT=3000\n\
node /opt/opengym-api/server.js &\n\
exec nginx -g "daemon off;"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

ENV PORT=10000 \
    DATA_DIR=/data \
    FIRST_USER_ADMIN=1 \
    PASSWORD_LOGIN=1

EXPOSE 10000

ENTRYPOINT ["/entrypoint.sh"]
