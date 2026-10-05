#!/bin/bash
# Builds the Keycloak theme archive (charts/yontrack/files/themes/yontrack.tar.gz).
#
# The archive is embedded in the keycloak-theme ConfigMap, so it must be reproducible:
# the same theme files must always give the same bytes, whatever the checkout time,
# file order, owner or umask. Otherwise the ConfigMap changes on every release.
#
# Usage: build-theme.sh [<output file>]  (run from the repository root)
# THEMES can be set to build from another directory containing the yontrack theme.

set -euo pipefail

THEMES=${THEMES:-charts/yontrack/files/themes}
OUTPUT=$(cd "$(dirname "${1:-$THEMES/yontrack.tar.gz}")" && pwd)/$(basename "${1:-$THEMES/yontrack.tar.gz}")

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

# Staging copy with normalised timestamps and permissions
cp -R "$THEMES/yontrack" "$STAGING/yontrack"
find "$STAGING/yontrack" -exec env TZ=UTC touch -h -t 200001010000 {} +
chmod -R u=rwX,go=rX "$STAGING/yontrack"

# Owner flags differ between GNU tar (CI) and bsdtar (macOS)
if tar --version | grep -q GNU; then
    OWNER=(--owner=0 --group=0 --numeric-owner)
else
    OWNER=(--uid 0 --gid 0 --uname "" --gname "" --no-xattrs --no-mac-metadata)
fi

# Sorted entries, no recursion: the order does not depend on the filesystem.
# gzip -n: no name nor timestamp in the gzip header.
(cd "$STAGING" && find yontrack | LC_ALL=C sort | COPYFILE_DISABLE=1 tar "${OWNER[@]}" --no-recursion -cf - -T -) \
    | gzip -n -9 > "$OUTPUT"
