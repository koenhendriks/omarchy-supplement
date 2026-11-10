#!/bin/bash

set -e

# Not `omarchy install dev-env laravel`: since 4.5 that installs a static PHP
# build through mise and makes it the global php, which shadows /usr/bin/php.
# install-php-pie.sh and install-php-extensions.sh configure the pacman php
# (/etc/php/php.ini, php-gd, php-pgsql, php-amqp), and none of that reaches the
# mise build. Node comes from Omarchy's default mise tools either way.
echo "Installing PHP and Composer"
omarchy-pkg-add php composer

if command -v laravel >/dev/null 2>&1; then
    echo "Laravel installer already present at $(command -v laravel)"
else
    echo "Installing the Laravel installer"
    composer global require laravel/installer
fi

echo "Laravel setup complete!"
