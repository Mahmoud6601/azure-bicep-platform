FROM nginxinc/nginx-unprivileged:1.27.4-alpine

ARG APP_VERSION=local-dev
ARG GIT_SHA=local
ARG DEPLOYMENT_TRACK=paas-container
ARG ENVIRONMENT=local

USER root
RUN apk upgrade --no-cache

COPY --chown=101:101 nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --chown=101:101 public/ /usr/share/nginx/html/

RUN printf '{"version":"%s","git_sha":"%s","deployment_track":"%s","environment":"%s","built_at":"%s"}\n' \
      "${APP_VERSION}" "${GIT_SHA}" "${DEPLOYMENT_TRACK}" "${ENVIRONMENT}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > /usr/share/nginx/html/version.json \
    && chown 101:101 /usr/share/nginx/html/version.json

USER 101

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null || exit 1
