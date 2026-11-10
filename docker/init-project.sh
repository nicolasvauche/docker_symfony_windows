#!/bin/sh
set -eu
composer create-project symfony/skeleton:"8.1.*" /tmp/symfony --no-interaction --prefer-dist
cd /tmp/symfony
composer config extra.symfony.docker false
if [ "${1:-}" = "webapp" ]; then
    composer require webapp --no-interaction
fi
# Export only editable files. Dependencies and cache stay on Linux.
tar --exclude='./vendor' --exclude='./var' --exclude='./.git' -cf /tmp/project.tar .
tar -xf /tmp/project.tar -C /export
