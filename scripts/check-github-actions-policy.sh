#!/usr/bin/env bash
set -euo pipefail

failures=0

fail() {
    printf 'github-actions-policy: %s\n' "$*" >&2
    failures=$((failures + 1))
}

check_file() {
    local workflow="$1"
    local uses_line action_ref action_name

    if grep -Eq 'pull_request_target|workflow_run' "$workflow"; then
        fail "$workflow must not use privileged untrusted-code triggers"
    fi

    if grep -Eq 'runs-on:[[:space:]]*ubuntu-latest' "$workflow"; then
        fail "$workflow must pin runs-on to ubuntu-24.04, not ubuntu-latest"
    fi

    if ! grep -Eq 'runs-on:[[:space:]]*ubuntu-24\.04' "$workflow"; then
        fail "$workflow must use ubuntu-24.04"
    fi

    if grep -Eq 'uses:[[:space:]]*actions/checkout@' "$workflow"; then
        fail "$workflow must avoid actions/checkout; docker/build-push-action can use Git context directly"
    fi

    if grep -Eq 'uses:[[:space:]]*docker/metadata-action@' "$workflow"; then
        fail "$workflow must avoid docker/metadata-action for simple v* tag mapping"
    fi

    while IFS= read -r uses_line; do
        action_name="${uses_line#*uses:}"
        action_name="${action_name#"${action_name%%[![:space:]]*}"}"
        action_ref="${action_name#*@}"
        action_ref="${action_ref%%[[:space:]#]*}"

        if [[ ! "$action_name" == *@* ]]; then
            fail "$workflow has an action without an explicit ref: $uses_line"
        elif [[ ! "$action_ref" =~ ^[0-9a-f]{40}$ ]]; then
            fail "$workflow action must be pinned to a full 40-character SHA: $uses_line"
        fi
    done < <(grep -E '^[[:space:]]*uses:[[:space:]]*[^[:space:]]+' "$workflow" || true)

    if ! grep -Eq 'contents:[[:space:]]*read' "$workflow"; then
        fail "$workflow must grant contents: read"
    fi

    if ! grep -Eq 'packages:[[:space:]]*write' "$workflow"; then
        fail "$workflow must grant packages: write"
    fi

    if ! grep -Eq 'id-token:[[:space:]]*write' "$workflow"; then
        fail "$workflow must grant id-token: write for keyless cosign signing"
    fi

    if ! grep -Eq 'uses:[[:space:]]*docker/build-push-action@[0-9a-f]{40}' "$workflow"; then
        fail "$workflow must use docker/build-push-action pinned to a full SHA"
    fi

    if grep -Eq 'context:[[:space:]]*\.' "$workflow"; then
        fail "$workflow must not use path context without checkout; use the default Git context"
    fi

    if ! grep -Eq 'platforms:[[:space:]]*linux/amd64,linux/arm64' "$workflow"; then
        fail "$workflow must publish linux/amd64 and linux/arm64"
    fi

    if ! grep -Eq 'pull:[[:space:]]*true' "$workflow"; then
        fail "$workflow must set docker/build-push-action pull: true"
    fi

    if ! grep -Eq 'provenance:[[:space:]]*mode=max' "$workflow"; then
        fail "$workflow must set docker/build-push-action provenance: mode=max"
    fi

    if ! grep -Eq 'sbom:[[:space:]]*true' "$workflow"; then
        fail "$workflow must set docker/build-push-action sbom: true"
    fi

    if ! grep -Eq 'cosign sign' "$workflow"; then
        fail "$workflow must sign the pushed image with cosign"
    fi
}

while IFS= read -r workflow; do
    check_file "$workflow"
done < <(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

if ((failures > 0)); then
    exit 1
fi

printf 'github-actions-policy: ok\n'
