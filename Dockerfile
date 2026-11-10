# syntax=docker/dockerfile:1
ARG FRANKENPHP_IMAGE=dunglas/frankenphp:1.13.5-php8.5.12-trixie
FROM ${FRANKENPHP_IMAGE} AS base

RUN apt-get update && apt-get install -y --no-install-recommends git unzip \
    && rm -rf /var/lib/apt/lists/*
RUN install-php-extensions intl mbstring zip bcmath gd \
    pdo_sqlite sqlite3 pdo_pgsql pgsql mongodb-stable \
    dom simplexml xml xmlreader xmlwriter curl
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY docker/php-dev.ini /usr/local/etc/php/conf.d/99-dev.ini
COPY docker/Caddyfile /etc/caddy/Caddyfile
COPY docker/check-extensions.php /usr/local/lib/check-extensions.php
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_CACHE_DIR=/tmp/composer-cache \
    SYMFONY_DOCKER=0
WORKDIR /app

FROM base AS dev
COPY app/ /app/
RUN --mount=type=cache,target=/tmp/composer-cache \
    composer install --no-interaction --prefer-dist \
    && mkdir -p var/cache var/log var/data
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
