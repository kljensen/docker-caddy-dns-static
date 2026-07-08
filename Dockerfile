ARG CADDY_VERSION=2.11.4
ARG ROUTE53_VERSION=1.6.2
ARG CLOUDFLARE_VERSION=0.2.4

FROM --platform=$BUILDPLATFORM caddy:${CADDY_VERSION}-builder-alpine AS builder

ARG CADDY_VERSION
ARG ROUTE53_VERSION
ARG CLOUDFLARE_VERSION
ARG TARGETOS
ARG TARGETARCH

ENV CGO_ENABLED=0
ENV GOOS=$TARGETOS
ENV GOARCH=$TARGETARCH

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN xcaddy build "v${CADDY_VERSION}" \
    --with "github.com/caddy-dns/route53@v${ROUTE53_VERSION}" \
    --with "github.com/caddy-dns/cloudflare@v${CLOUDFLARE_VERSION}" \
    && go version -m /usr/bin/caddy > /tmp/caddy-modules.txt \
    && grep -F "github.com/caddyserver/caddy/v2" /tmp/caddy-modules.txt \
    && grep -F "github.com/caddy-dns/route53" /tmp/caddy-modules.txt \
    && grep -F "github.com/caddy-dns/cloudflare" /tmp/caddy-modules.txt

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
