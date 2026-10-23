FROM ghcr.io/duartesantos8/opengym-web:latest

USER root

# Install Node.js and git, then clone openGym api
RUN apk add --no-cache nodejs npm git && \
    git clone --depth 1 https://github.com/DuarteSantos8/openGym.git /tmp/opengym && \
    cp -r /tmp/opengym/api /opt/opengym-api && \
    cd /opt/opengym-api && npm ci --omit=dev && \
    rm -rf /tmp/opengym && \
    mkdir -p /data /var/cache/nginx /var/run /run && \
    chmod -R 777 /data /var/cache/nginx /var/run /run /etc/nginx/conf.d

# Write a direct Nginx config optimized for Render
# Note the rewrite rule inside location /api/ that strips the prefix
RUN printf 'server {\n\
    listen 10000;\n\
    server_name _;\n\
    root /usr/share/nginx/html;\n\
    index index.html index.htm;\n\
    client_max_body_size 50M;\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
    location /api/ {\n\
        rewrite ^/api/(.*) /$1 break;\n\
        proxy_pass http://127.0.0.1:3000;\n\
        proxy_http_version 1.1;\n\
        proxy_set_header Upgrade $http_upgrade;\n\
        proxy_set_header Connection '\''upgrade'\'';\n\
        proxy_set_header Host $host;\n\
        proxy_cache_bypass $http_upgrade;\n\
        proxy_set_header X-Real-IP $remote_addr;\n\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n\
        proxy_set_header X-Forwarded-Proto $scheme;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

# Disable template rewriting so our config takes effect
RUN rm -rf /etc/nginx/templates/*

ENV PORT=3000 \
    DATA_DIR=/data \
    FIRST_USER_ADMIN=1 \
    PASSWORD_LOGIN=1

# Launch the Node API in the background right before Nginx starts
RUN printf '#!/bin/sh\nnode /opt/opengym-api/server.js &\n' > /docker-entrypoint.d/99-start-api.sh && \
    chmod +x /docker-entrypoint.d/99-start-api.sh

EXPOSE 10000
