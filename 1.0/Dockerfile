FROM php:8.4-apache-bookworm

ARG PEAKURL_VERSION=1.0.13
ARG PEAKURL_RELEASE_URL=https://releases.peakurl.org/package/peakurl-1.0.13.zip
ARG PEAKURL_RELEASE_SHA256=31408e71d1e6afab1256869140a76c81b13bbf9d35ce5eea17e9e0a3b695b194

LABEL org.opencontainers.image.title="PeakURL"
LABEL org.opencontainers.image.description="Official PeakURL container image built from the public release package."
LABEL org.opencontainers.image.url="https://peakurl.org"
LABEL org.opencontainers.image.documentation="https://github.com/PeakURL/containers"
LABEL org.opencontainers.image.source="https://github.com/PeakURL/containers"
LABEL org.opencontainers.image.version="${PEAKURL_VERSION}"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="PeakURL"

WORKDIR /var/www/html

RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip libicu-dev libzip-dev; \
    docker-php-ext-install intl pdo_mysql zip; \
    a2enmod rewrite headers expires; \
    curl -fsSL "$PEAKURL_RELEASE_URL" -o /tmp/peakurl.zip; \
    echo "$PEAKURL_RELEASE_SHA256  /tmp/peakurl.zip" | sha256sum -c -; \
    rm -rf /var/www/html/*; \
    mkdir -p /usr/src/peakurl; \
    unzip -q /tmp/peakurl.zip -d /usr/src/peakurl; \
    rm -f /tmp/peakurl.zip; \
    chown -R www-data:www-data /usr/src/peakurl /var/www/html; \
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
    apt-mark manual libzip4; \
    find /usr/local/lib/php/extensions/ -type f -name '*.so' -exec ldd '{}' ';' \
      | awk '/=>/ { print $(NF-1) }' \
      | sort -u \
      | xargs -r realpath \
      | xargs -r dpkg-query --search \
      | cut -d: -f1 \
      | sort -u \
      | xargs -r apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/peakurl-entrypoint
COPY php.ini /usr/local/etc/php/conf.d/peakurl.ini

ENTRYPOINT ["peakurl-entrypoint"]
CMD ["apache2-foreground"]
