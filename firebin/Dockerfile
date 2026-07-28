# FireBin Home Assistant add-on.
#
# A Home Assistant add-on is a single container, so this bundles all three parts
# of FireBin (Postgres, the API, and the web app) into one image. The API binary
# and the web assets are copied from the published images; Postgres and nginx are
# installed from Alpine. Builds for amd64 (Intel/AMD) and aarch64 (ARM) from the
# multi-arch published images.
FROM ghcr.io/fireball1725/firebin-api:latest AS api
FROM ghcr.io/fireball1725/firebin-web:latest AS web

FROM alpine:3.20

RUN apk add --no-cache \
      bash \
      postgresql16 \
      postgresql16-client \
      nginx \
      su-exec \
      jq \
      openssl \
      tzdata \
  && mkdir -p /run/nginx /run/postgresql /var/www/firebin \
  && chown postgres:postgres /run/postgresql

# The FireBin binary (a static Go build) and the built web assets.
COPY --from=api /app/firebin-api /usr/bin/firebin-api
COPY --from=web /usr/share/nginx/html /var/www/firebin

COPY rootfs/ /
RUN chmod +x /usr/bin/firebin-run.sh

EXPOSE 3000
CMD ["/usr/bin/firebin-run.sh"]
