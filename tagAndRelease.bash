#!/usr/bin/env bash
# Usage:
#   tagAndRelease.bash -version v1.2.3 -message "commit message"
#
# What it does:
#   1. Updates Sources/MacTimeWidget/Version.swift with the new version
#   2. Commits all pending changes with the provided message
#   3. Creates an annotated git tag
#   4. Pushes the commit and tag — the tag push triggers the GitHub Actions release build

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- argument parsing ----------
VERSION=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -version)
            VERSION="$2"
            shift 2
            ;;
        -message)
            MESSAGE="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 -version v1.2.3 -message \"commit message\"" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$VERSION" || -z "$MESSAGE" ]]; then
    echo "Error: both -version and -message are required." >&2
    echo "Usage: $0 -version v1.2.3 -message \"commit message\"" >&2
    exit 1
fi

# Normalise: ensure tag has a leading 'v', bare version does not
if [[ "$VERSION" == v* ]]; then
    TAG="$VERSION"
    BARE="${VERSION#v}"
else
    TAG="v$VERSION"
    BARE="$VERSION"
fi

# Basic semver sanity check
if ! [[ "$BARE" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: version '$BARE' is not a valid semver (expected X.Y or X.Y.Z)." >&2
    exit 1
fi

# ---------- guard: tag must not already exist ----------
if git -C "$SCRIPT_DIR" tag --list | grep -qx "$TAG"; then
    echo "Error: tag '$TAG' already exists locally." >&2
    exit 1
fi
if git -C "$SCRIPT_DIR" ls-remote --tags origin | grep -q "refs/tags/$TAG$"; then
    echo "Error: tag '$TAG' already exists on remote." >&2
    exit 1
fi

# ---------- update Version.swift ----------
VERSION_FILE="$SCRIPT_DIR/Sources/MacTimeWidget/Version.swift"
cat > "$VERSION_FILE" << EOF
// Updated by tagAndRelease.bash — do not edit by hand.
let AppVersion = "$BARE"
EOF
echo "Updated $VERSION_FILE → $BARE"

# ---------- stage, commit, tag, push ----------
git -C "$SCRIPT_DIR" add "$VERSION_FILE"

# Stage any other tracked changes the caller may have pending
git -C "$SCRIPT_DIR" add -u

# Only commit if there is something staged
if ! git -C "$SCRIPT_DIR" diff --cached --quiet; then
    git -C "$SCRIPT_DIR" commit -m "$MESSAGE"
    echo "Committed changes."
else
    echo "Nothing new to commit (Version.swift may already be at $BARE)."
fi

git -C "$SCRIPT_DIR" tag -a "$TAG" -m "$MESSAGE"
echo "Created tag $TAG."

git -C "$SCRIPT_DIR" push
echo "Pushed commits."

git -C "$SCRIPT_DIR" push origin "$TAG"
echo "Pushed tag $TAG → GitHub Actions release workflow triggered."
