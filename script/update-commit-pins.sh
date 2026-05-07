#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Format: component|remote git URL|version file
COMMIT_PINS=(
    "svt-av1|https://gitlab.com/AOMediaCodec/SVT-AV1.git|version/svt-av1"
    "vpx|https://github.com/webmproject/libvpx.git|version/vpx"
    "vvdec|https://github.com/fraunhoferhhi/vvdec.git|version/vvdec"
    "vvenc|https://github.com/fraunhoferhhi/vvenc.git|version/vvenc"
    "x265|https://bitbucket.org/multicoreware/x265_git.git|version/x265"
)

has_updates="false"
updates=""

echo "Checking commit-pinned codec dependencies..."

for entry in "${COMMIT_PINS[@]}"; do
    IFS="|" read -r component remote version_file <<< "$entry"
    file_path="$ROOT_DIR/$version_file"

    if [ ! -f "$file_path" ]; then
        echo "Error: version file not found: $version_file" >&2
        exit 1
    fi

    current_commit="$(tr -d '[:space:]' < "$file_path")"
    if [[ ! "$current_commit" =~ ^[0-9a-fA-F]{40}$ ]]; then
        echo "Error: $version_file does not contain a 40-character commit hash: $current_commit" >&2
        exit 1
    fi

    echo "Checking $component..."
    latest_commit="$(git ls-remote "$remote" HEAD | awk 'NR == 1 { print $1 }')"

    if [[ ! "$latest_commit" =~ ^[0-9a-fA-F]{40}$ ]]; then
        echo "Error: unable to resolve HEAD for $component from $remote" >&2
        exit 1
    fi

    if [ "${current_commit,,}" = "${latest_commit,,}" ]; then
        echo "  $component is already current (${current_commit:0:12})."
        continue
    fi

    printf '%s\n' "$latest_commit" > "$file_path"
    has_updates="true"
    line="- $component: ${current_commit:0:12} -> ${latest_commit:0:12}"
    updates+="$line"$'\n'
    echo "  Updated $component: ${current_commit:0:12} -> ${latest_commit:0:12}"
done

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "has_updates=$has_updates"
        echo "updates<<EOF"
        printf '%s' "$updates"
        echo "EOF"
    } >> "$GITHUB_OUTPUT"
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
        echo "### Commit pin update check"
        echo
        if [ "$has_updates" = "true" ]; then
            echo "Updated dependencies:"
            echo
            printf '%s' "$updates"
        else
            echo "No commit-pinned dependencies changed."
        fi
    } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$has_updates" = "true" ]; then
    echo "Commit pin updates were found."
else
    echo "No commit pin updates were found."
fi
