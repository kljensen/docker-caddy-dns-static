ARG CADDY_VERSION=2.11.4
ARG ROUTE53_VERSION=1.6.2
ARG CLOUDFLARE_VERSION=0.2.4

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

ARG CADDY_VERSION
ARG ROUTE53_VERSION
ARG CLOUDFLARE_VERSION

ENV CGO_ENABLED=0

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN xcaddy build "v${CADDY_VERSION}" \
    --with "github.com/caddy-dns/route53@v${ROUTE53_VERSION}" \
    --with "github.com/caddy-dns/cloudflare@v${CLOUDFLARE_VERSION}" \
    && /usr/bin/caddy version \
    && /usr/bin/caddy list-modules --skip-standard --versions \
    | tee /tmp/caddy-modules.txt \
    && grep -F "dns.providers.route53 v${ROUTE53_VERSION}" /tmp/caddy-modules.txt \
    && grep -F "dns.providers.cloudflare v${CLOUDFLARE_VERSION}" /tmp/caddy-modules.txt \
    && { ldd /usr/bin/caddy > /tmp/caddy-ldd.txt 2>&1 || true; } \
    && grep -Eq 'Not a valid dynamic program|not a dynamic executable' /tmp/caddy-ldd.txt

RUN mkdir -p \
        /runtime/bin \
        /runtime/config \
        /runtime/data \
        /runtime/etc/caddy \
        /runtime/etc/ssl/certs \
        /runtime/usr/share/caddy \
    && cp /usr/bin/caddy /runtime/bin/caddy \
    && cp /etc/ssl/certs/ca-certificates.crt /runtime/etc/ssl/certs/ca-certificates.crt

FROM scratch

LABEL org.opencontainers.image.title="docker-caddy-dns-static"
LABEL org.opencontainers.image.description="Minimal Caddy runtime with Route53 and Cloudflare DNS providers"
LABEL org.opencontainers.image.licenses="MIT"

COPY --from=builder /runtime/ /

EXPOSE 80 443 443/udp
VOLUME ["/data", "/config"]

ENTRYPOINT ["/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
