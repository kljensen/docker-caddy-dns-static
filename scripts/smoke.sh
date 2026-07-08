#!/usr/bin/env bash
set -euo pipefail

image="${1:?usage: smoke.sh IMAGE PLATFORM CADDY_VERSION ROUTE53_VERSION CLOUDFLARE_VERSION}"
platform="${2:-linux/amd64}"
caddy_version="${3:?usage: smoke.sh IMAGE PLATFORM CADDY_VERSION ROUTE53_VERSION CLOUDFLARE_VERSION}"
route53_version="${4:?usage: smoke.sh IMAGE PLATFORM CADDY_VERSION ROUTE53_VERSION CLOUDFLARE_VERSION}"
cloudflare_version="${5:?usage: smoke.sh IMAGE PLATFORM CADDY_VERSION ROUTE53_VERSION CLOUDFLARE_VERSION}"

version_output=$(docker run --rm --platform "$platform" "$image" version)
case "$version_output" in
    "v${caddy_version} "*) ;;
    "v${caddy_version}"*) ;;
    *)
        printf 'smoke: expected Caddy v%s, got: %s\n' "$caddy_version" "$version_output" >&2
        exit 1
        ;;
esac

modules_output=$(docker run --rm --platform "$platform" "$image" list-modules --skip-standard --versions)
printf '%s\n' "$modules_output" | grep -F "dns.providers.route53 v${route53_version}" >/dev/null
printf '%s\n' "$modules_output" | grep -F "dns.providers.cloudflare v${cloudflare_version}" >/dev/null

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/caddy-dns-static.XXXXXX")
container_id=""

# shellcheck disable=SC2329
cleanup() {
    if [ -n "$container_id" ]; then
        docker rm -f "$container_id" >/dev/null 2>&1 || true
    fi
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

cat > "$tmp_dir/Caddyfile" <<'EOF'
:8080 {
	respond /health "ok"
}
EOF

container_id=$(docker run -d --platform "$platform" \
    -p 127.0.0.1::8080 \
    -v "$tmp_dir/Caddyfile:/etc/caddy/Caddyfile:ro" \
    "$image")

host_port=$(docker inspect "$container_id" --format '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}')

for _ in $(seq 1 30); do
    if [ "$(curl -fsS "http://127.0.0.1:${host_port}/health" 2>/dev/null || true)" = ok ]; then
        printf 'smoke: ok\n'
        exit 0
    fi
    sleep 1
done

docker logs "$container_id" >&2 || true
printf 'smoke: Caddy did not serve /health\n' >&2
exit 1
