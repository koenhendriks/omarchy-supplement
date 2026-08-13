#!/bin/bash

set -e

pie install phpredis/phpredis
yay -S --noconfirm --needed php-gd

