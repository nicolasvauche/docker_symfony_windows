#!/bin/sh
set -eu
: "${SYMFONY_BRANCH:?Version Symfony manquante}"
: "${EXPECTED_SYMFONY_VERSION:?Version Symfony exacte manquante}"
composer create-project "symfony/skeleton:${SYMFONY_BRANCH}.*" /tmp/symfony --stability=stable --no-interaction --prefer-dist
cd /tmp/symfony
composer config minimum-stability stable
composer config prefer-stable true
composer config extra.symfony.docker false
if [ "${1:-}" = "webapp" ]; then
    composer require webapp --no-interaction
fi
# Never export a project silently resolved to an older compatible Symfony release.
php -r 'require "vendor/autoload.php"; $actual = Composer\InstalledVersions::getPrettyVersion("symfony/framework-bundle"); if (ltrim($actual, "v") !== getenv("EXPECTED_SYMFONY_VERSION")) { fwrite(STDERR, "Version Symfony inattendue : ".$actual."\n"); exit(1); }'
composer check-platform-reqs
# Export only editable files. Dependencies and cache stay on Linux.
tar --exclude='./vendor' --exclude='./var' --exclude='./.git' -cf /tmp/project.tar .
tar -xf /tmp/project.tar -C /export
