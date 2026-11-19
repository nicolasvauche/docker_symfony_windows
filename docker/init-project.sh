#!/bin/sh
set -eu
: "${SYMFONY_BRANCH:?Version Symfony manquante}"
: "${EXPECTED_SYMFONY_VERSION:?Version Symfony exacte manquante}"
composer create-project "symfony/skeleton:${SYMFONY_BRANCH}.*" /tmp/symfony --stability=stable --no-interaction --prefer-dist --no-install --no-scripts
cd /tmp/symfony
php /usr/local/lib/prepare-symfony.php
composer config minimum-stability stable
composer config prefer-stable true
composer config extra.symfony.docker false
composer install --no-interaction --prefer-dist
if [ "${1:-}" = "webapp" ]; then
    composer require webapp --no-interaction
fi
# Keep the default in Symfony dotenv so .env.local can override it normally.
# Apply after Flex recipes, which may otherwise select PostgreSQL by default.
sed -i '/^DATABASE_URL=/d' .env
printf '\n# Default database for the Docker development environment.\nDATABASE_URL="sqlite:////app/var/data/app.db"\n' >> .env
# Never export a project silently resolved to an older compatible Symfony release.
php -r 'require "vendor/autoload.php"; $actual = Composer\InstalledVersions::getPrettyVersion("symfony/framework-bundle"); if (ltrim($actual, "v") !== getenv("EXPECTED_SYMFONY_VERSION")) { fwrite(STDERR, "Version Symfony inattendue : ".$actual."\n"); exit(1); }'
composer check-platform-reqs
# Export only editable files. Dependencies and cache stay on Linux.
tar --exclude='./vendor' --exclude='./var' --exclude='./.git' -cf /tmp/project.tar .
tar -xf /tmp/project.tar -C /export
