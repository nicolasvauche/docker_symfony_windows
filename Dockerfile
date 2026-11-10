# syntax=docker/dockerfile:1
ARG FRANKENPHP_IMAGE
FROM ${FRANKENPHP_IMAGE} AS base
ARG COMPOSER_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends git unzip curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN install-php-extensions intl mbstring zip bcmath gd \
    pdo_sqlite sqlite3 pdo_pgsql pgsql mongodb-stable \
    dom simplexml xml xmlreader xmlwriter curl
RUN test -n "$COMPOSER_VERSION" \
    && curl -fsSL "https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar" -o /tmp/composer.phar \
    && curl -fsSL "https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar.sha256sum" -o /tmp/composer.sha256sum \
    && cd /tmp && sha256sum -c composer.sha256sum \
    && mv composer.phar /usr/local/bin/composer && chmod +x /usr/local/bin/composer \
    && rm composer.sha256sum
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
COPY docker/php-dev.ini /usr/local/etc/php/conf.d/99-dev.ini
COPY docker/Caddyfile /etc/caddy/Caddyfile
COPY docker/check-extensions.php /usr/local/lib/check-extensions.php
COPY docker/check-versions.php /usr/local/lib/check-versions.php
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
