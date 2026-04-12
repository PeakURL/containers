#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
VERSIONS_FILE="$SCRIPT_DIR/versions.json"
ROOT_DOCKERFILE="$SCRIPT_DIR/docker/peakurl/Dockerfile"
ROOT_ENTRYPOINT="$SCRIPT_DIR/docker/peakurl/entrypoint.sh"
ROOT_PHP_INI="$SCRIPT_DIR/docker/peakurl/php.ini"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <version> [release-url]" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required." >&2
    exit 1
fi

VERSION="$1"
RELEASE_URL="${2:-https://releases.peakurl.org/package/peakurl-${VERSION}.zip}"

case "$VERSION" in
    *.*.*) ;;
    *)
        echo "Version must be semver, for example 1.0.13." >&2
        exit 1
        ;;
esac

MAJOR="$(printf '%s' "$VERSION" | cut -d. -f1)"
MINOR="$(printf '%s' "$VERSION" | cut -d. -f2)"
SERIES="${MAJOR}.${MINOR}"
DIRECTORY="$SERIES"

TMP_ARCHIVE="$(mktemp)"
TMP_JSON="$(mktemp)"
TMP_DOCKERFILE="$(mktemp)"
cleanup() {
    rm -f "$TMP_ARCHIVE" "$TMP_JSON" "$TMP_DOCKERFILE"
}
trap cleanup EXIT

curl --fail --silent --show-error --location "$RELEASE_URL" --output "$TMP_ARCHIVE"
SHA256="$(sha256sum "$TMP_ARCHIVE" | awk '{print $1}')"

jq \
    --arg series "$SERIES" \
    --arg version "$VERSION" \
    --arg releaseUrl "$RELEASE_URL" \
    --arg releaseSha256 "$SHA256" \
    --arg directory "$DIRECTORY" \
    '
    .[$series] = (
      .[$series] // {}
      | .version = $version
      | .releaseUrl = $releaseUrl
      | .releaseSha256 = $releaseSha256
      | .tags = [$version, $series, ($version | split(".")[0]), "latest"]
      | .architectures = (.architectures // ["amd64", "arm64v8"])
      | .directory = $directory
      | del(.gitTag)
      | del(.file)
    )
    ' "$VERSIONS_FILE" > "$TMP_JSON"

mv "$TMP_JSON" "$VERSIONS_FILE"

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

DOI_DIR="$SCRIPT_DIR/$DIRECTORY"
mkdir -p "$DOI_DIR"
cp "$ROOT_ENTRYPOINT" "$DOI_DIR/docker-entrypoint.sh"
cp "$ROOT_PHP_INI" "$DOI_DIR/php.ini"

VERSION_ESCAPED="$(escape_sed_replacement "$VERSION")"
RELEASE_URL_ESCAPED="$(escape_sed_replacement "$RELEASE_URL")"
SHA256_ESCAPED="$(escape_sed_replacement "$SHA256")"

sed \
    -e "s|^ARG PEAKURL_VERSION=.*$|ARG PEAKURL_VERSION=$VERSION_ESCAPED|" \
    -e "s|^ARG PEAKURL_RELEASE_URL=.*$|ARG PEAKURL_RELEASE_URL=$RELEASE_URL_ESCAPED|" \
    -e "s|^ARG PEAKURL_RELEASE_SHA256=.*$|ARG PEAKURL_RELEASE_SHA256=$SHA256_ESCAPED|" \
    -e 's|^COPY docker/peakurl/entrypoint\.sh |COPY docker-entrypoint.sh |' \
    -e 's|^COPY docker/peakurl/php\.ini |COPY php.ini |' \
    "$ROOT_DOCKERFILE" > "$TMP_DOCKERFILE"

mv "$TMP_DOCKERFILE" "$DOI_DIR/Dockerfile"

printf 'Updated %s for %s\n' "$VERSIONS_FILE" "$VERSION"
printf 'releaseUrl=%s\n' "$RELEASE_URL"
printf 'releaseSha256=%s\n' "$SHA256"
printf 'doiDirectory=%s\n' "$DIRECTORY"
