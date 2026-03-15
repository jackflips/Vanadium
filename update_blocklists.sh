#!/bin/bash
#
# Update blocklists from upstream repos and generate blocked_domains.txt.
# Also copies the domain list to the Chromium source tree if CHROMIUM_SRC is set.
#
# Usage:
#   ./update_blocklists.sh
#   CHROMIUM_SRC=/path/to/chromium/src ./update_blocklists.sh
#

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Updating StevenBlack/hosts..."
cd "$SCRIPT_DIR/blocklists/StevenBlack-hosts"
git pull --ff-only
cd "$SCRIPT_DIR"

echo "Updating polarhive/arceo..."
cd "$SCRIPT_DIR/blocklists/arceo"
git pull --ff-only
cd "$SCRIPT_DIR"

echo "Generating merged blocklist..."
python3 "$SCRIPT_DIR/blocklists/generate_blocklist.py"

count=$(wc -l < "$SCRIPT_DIR/blocked_domains.txt")
echo "Total blocked domains: $count"

if [[ -n "${CHROMIUM_SRC:-}" ]]; then
    dest="$CHROMIUM_SRC/vanadium/blocked_domains"
    mkdir -p "$dest"
    cp "$SCRIPT_DIR/blocked_domains.txt" "$dest/blocked_domains.txt"
    echo "Copied to $dest/blocked_domains.txt"
fi

echo "Done."
