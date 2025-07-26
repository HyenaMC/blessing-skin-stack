# =================================================================
# Construct Janus
# =================================================================
FROM node:22-slim as builder

WORKDIR /opt/janus

RUN git clone https://github.com/bs-community/janus.git .

RUN npm install

RUN cp .env.example .env
RUN cp prisma/schema.prisma.example prisma/schema.prisma

RUN npx prisma generate

RUN npm run build

# =================================================================
# Main Container
# =================================================================

FROM php:8.1-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    supervisor \
    git \
    curl \
    gnupg \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    NODE_MAJOR=22 && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions && \
  install-php-extensions gd zip pdo_mysql redis
  
# Set up Janus
WORKDIR /opt/janus
COPY --from=builder /opt/janus/dist ./dist
COPY --from=builder /opt/janus/node_modules ./node_modules
COPY --from=builder /opt/janus/package.json .
COPY --from=builder /opt/janus/package-lock.json .
COPY --from=builder /opt/janus/prisma ./prisma

# Set up Apache
WORKDIR /app
ENV APACHE_DOCUMENT_ROOT /app/public
RUN chown -R www-data:www-data . && \
  sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
  sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf && \
  a2enmod rewrite headers proxy proxy_http

# Configure supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME /app
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]