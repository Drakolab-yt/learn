#!/bin/sh
set -e

chmod -R 777 var/ public/

exec docker-php-entrypoint "$@"
