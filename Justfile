set dotenv-load
set shell := ["bash", "-euo", "pipefail", "-c"]

image_name := env_var_or_default("IMAGE_NAME", "docker-caddy-dns-static")
caddy_version := env_var_or_default("CADDY_VERSION", "2.11.4")
route53_version := env_var_or_default("ROUTE53_VERSION", "1.6.2")
cloudflare_version := env_var_or_default("CLOUDFLARE_VERSION", "0.2.4")
image := env_var_or_default("IMAGE", "local/" + image_name + ":" + caddy_version)
platform := env_var_or_default("PLATFORM", "linux/amd64")

default:
    @just --list

# Run Dockerfile, shell, and GitHub Actions static analysis.
lint:
    hadolint Dockerfile
    shellcheck scripts/*.sh
    actionlint
    uvx zizmor .
    bash scripts/check-github-actions-policy.sh

# Build the local image.
build:
    docker build --platform {{platform}} \
        --build-arg CADDY_VERSION={{caddy_version}} \
        --build-arg ROUTE53_VERSION={{route53_version}} \
        --build-arg CLOUDFLARE_VERSION={{cloudflare_version}} \
        -t {{image}} .

# Verify the image has the expected Caddy modules and command behavior.
smoke:
    bash scripts/smoke.sh {{image}} {{platform}} {{caddy_version}} {{route53_version}} {{cloudflare_version}}

# Check size and runtime packaging invariants.
image-policy:
    bash scripts/check-image-policy.sh {{image}} {{platform}}

# Scan the locally built image with Trivy.
scan:
    trivy image --severity HIGH,CRITICAL --exit-code 1 {{image}}

# Run all local checks that do not require a registry push.
test: lint build smoke image-policy scan
