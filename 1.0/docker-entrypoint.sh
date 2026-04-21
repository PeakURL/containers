#!/bin/sh
set -eu

APP_ROOT="/var/www/html"
SOURCE_ROOT="/usr/src/peakurl"

mkdir -p "$APP_ROOT"
app_root=0

if [ ! -e "$APP_ROOT/install.php" ]; then
    tar -C "$SOURCE_ROOT" -cf - . | tar -C "$APP_ROOT" -xf -
    app_root=1
fi

if [ "$app_root" -eq 1 ]; then
    chown -R www-data:www-data "$APP_ROOT"
fi

if [ -n "${APACHE_SERVER_NAME:-}" ]; then
    printf 'ServerName %s\n' "$APACHE_SERVER_NAME" > /etc/apache2/conf-available/zzz-server-name.conf
    a2enconf zzz-server-name >/dev/null 2>&1 || true
fi

export PEAKURL_INSTALL_DB_HOST_DEFAULT="${PEAKURL_INSTALL_DB_HOST_DEFAULT:-${PEAKURL_DB_HOST:-db}}"
export PEAKURL_INSTALL_DB_PORT_DEFAULT="${PEAKURL_INSTALL_DB_PORT_DEFAULT:-${PEAKURL_DB_PORT:-3306}}"
export PEAKURL_INSTALL_DB_NAME_DEFAULT="${PEAKURL_INSTALL_DB_NAME_DEFAULT:-${PEAKURL_DB_NAME:-peakurl}}"
export PEAKURL_INSTALL_DB_USER_DEFAULT="${PEAKURL_INSTALL_DB_USER_DEFAULT:-${PEAKURL_DB_USER:-peakurl}}"
export PEAKURL_INSTALL_DB_PASSWORD_DEFAULT="${PEAKURL_INSTALL_DB_PASSWORD_DEFAULT:-${PEAKURL_DB_PASSWORD:-}}"
export PEAKURL_INSTALL_DB_PREFIX_DEFAULT="${PEAKURL_INSTALL_DB_PREFIX_DEFAULT:-peakurl_}"

exec "$@"
