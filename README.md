# Docker Caddy DNS Static

Minimal `scratch` image containing Caddy with the Route53 and Cloudflare DNS
provider modules.

```sh
docker pull ghcr.io/kljensen/docker-caddy-dns-static:2.11.4
docker run --rm ghcr.io/kljensen/docker-caddy-dns-static:2.11.4 version
docker run --rm ghcr.io/kljensen/docker-caddy-dns-static:2.11.4 list-modules --skip-standard --versions
```

## Versions

- Caddy: `2.11.4`
- `github.com/caddy-dns/route53`: `1.6.2`
- `github.com/caddy-dns/cloudflare`: `0.2.4`

The final image contains only `/bin/caddy`, CA certificates, and the runtime
directories Caddy expects for `/etc/caddy`, `/data`, `/config`, and
`/usr/share/caddy`.

## Local Checks

Required local tools:

- Docker with Buildx
- `just`
- `hadolint`
- `shellcheck`
- `actionlint`
- `uvx`
- `trivy`

```sh
just lint
just build
just smoke
just image-policy
just scan
just test
```

The image policy check verifies the final runtime has no shell or package
manager and stays below the configured size limit.

## Publishing

Pushing a tag like `v2.11.4` publishes
`ghcr.io/kljensen/docker-caddy-dns-static:2.11.4`.

The GitHub Actions workflow uses pinned actions, `linux/amd64` and
`linux/arm64`, BuildKit SBOM/provenance attestations, and keyless cosign signing
with GitHub OIDC.
