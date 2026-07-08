#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: check-image-policy.sh IMAGE [PLATFORM]}"
platform="${2:-linux/amd64}"
max_size_bytes="${MAX_IMAGE_SIZE_BYTES:-80000000}"

size_bytes=$(docker image inspect "$image" --format '{{.Size}}')

if ((size_bytes > max_size_bytes)); then
    printf 'image-policy: image size %s exceeds limit %s\n' "$size_bytes" "$max_size_bytes" >&2
    exit 1
fi

docker run --rm --platform "$platform" "$image" version
docker run --rm --platform "$platform" "$image" list-modules --skip-standard --versions \
    | grep -Eq 'dns\.providers\.(route53|cloudflare)'

if docker run --rm --platform "$platform" --entrypoint /bin/sh "$image" -c 'exit 0' 2>/dev/null; then
    printf 'image-policy: final image unexpectedly contains /bin/sh\n' >&2
    exit 1
fi

if docker run --rm --platform "$platform" --entrypoint /sbin/apk "$image" --version 2>/dev/null; then
    printf 'image-policy: final image unexpectedly contains apk\n' >&2
    exit 1
fi

printf 'image-policy: ok size_bytes=%s limit_bytes=%s\n' "$size_bytes" "$max_size_bytes"
