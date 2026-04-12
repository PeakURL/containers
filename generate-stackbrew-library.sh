#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
VERSIONS_FILE="${1:-$SCRIPT_DIR/versions.json}"

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to generate the stackbrew manifest." >&2
    exit 1
fi

if GIT_COMMIT="$(git -C "$SCRIPT_DIR" rev-parse --verify HEAD 2>/dev/null)"; then
    SCRIPT_REF="$GIT_COMMIT"
    PRELUDE=""
else
    GIT_COMMIT="<create-first-commit>"
    SCRIPT_REF="main"
    PRELUDE=1
fi

if [ "${PRELUDE:-0}" = 1 ]; then
    printf '# NOTE: create the first git commit before using this manifest in docker-library/official-images\n\n'
fi
printf '# this file is generated via https://github.com/PeakURL/containers/blob/%s/generate-stackbrew-library.sh\n\n' "$SCRIPT_REF"
printf 'Maintainers: PeakURL <dev@peakurl.org> (@PeakURL)\n'
printf 'GitRepo: https://github.com/PeakURL/containers.git\n'
printf 'GitFetch: refs/heads/main\n\n'

jq -r --arg gitCommit "$GIT_COMMIT" '
    to_entries[]
    | [
        "Tags: " + (.value.tags | join(", ")),
        "Architectures: " + (.value.architectures | join(", ")),
        "GitCommit: " + $gitCommit,
        "Directory: " + (.value.directory // "."),
        "File: " + (.value.file // "Dockerfile"),
        ""
      ]
    | join("\n")
' "$VERSIONS_FILE"
