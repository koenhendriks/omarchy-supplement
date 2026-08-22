#!/bin/bash

set -e

PHP_INI="/etc/php/php.ini"

pie install phpredis/phpredis

yay -S --noconfirm --needed php-gd
yay -S --noconfirm --needed php-amqp

# PostgreSQL from the repos rather than PIE. PIE can build both of these
# (php/pdo_pgsql, php/pgsql) but it compiles against the current PHP ABI, so a
# php upgrade silently stops the extension loading until it is rebuilt by hand.
# pacman rebuilds php-pgsql in lockstep with php instead. PIE still earns its
# place for phpredis above, which is a genuine PECL extension.
yay -S --noconfirm --needed php-pgsql

if [ ! -f "$PHP_INI" ]; then
    echo "PHP config not found at $PHP_INI"
    echo "Install php first"
    exit 1
fi

# Only made by the first run that actually changes something, so a re-run leaves
# the file byte-identical and the pristine original is never overwritten.
backup_php_ini() {
    if [ ! -f "$PHP_INI.bak" ]; then
        echo "Backing up $PHP_INI to $PHP_INI.bak"
        sudo cp -a "$PHP_INI" "$PHP_INI.bak"
    fi
}

# Uncomment the stock `;extension=` line if php.ini has one, otherwise append.
# Never both: a second `extension=` line for the same module makes PHP warn that
# it is already loaded on every single invocation.
enable_php_extension() {
    local ext="$1"

    # Reads are unprivileged (php.ini is 644), so a run with nothing to change
    # never touches sudo and never stops for a password on its own.
    if grep -Fxq "extension=$ext" "$PHP_INI"; then
        echo "extension=$ext already enabled in $PHP_INI"
        return
    fi

    backup_php_ini

    if grep -Eq "^[[:space:]]*;[[:space:]]*extension=$ext\$" "$PHP_INI"; then
        echo "Enabling extension=$ext in $PHP_INI"
        sudo sed -i -E "s|^[[:space:]]*;[[:space:]]*extension=$ext\$|extension=$ext|" "$PHP_INI"
    else
        echo "Adding extension=$ext to $PHP_INI"
        echo "extension=$ext" | sudo tee -a "$PHP_INI" >/dev/null
    fi
}

enable_php_extension amqp.so
enable_php_extension gd

# php-pgsql ships pdo_pgsql.so and pgsql.so but no conf.d entry of its own, so
# both need enabling here. pdo_pgsql is what Laravel's pgsql driver goes
# through; pgsql is the native pg_* function set. Arch's php.ini carries a
# commented line for each, so these take the uncomment path.
enable_php_extension pdo_pgsql
enable_php_extension pgsql

echo "PHP extensions setup complete!"
