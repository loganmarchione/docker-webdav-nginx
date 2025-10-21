FROM debian:13-slim

ARG BUILD_DATE

LABEL \
  maintainer="Logan Marchione <logan@loganmarchione.com>" \
  org.opencontainers.image.authors="Logan Marchione <logan@loganmarchione.com>" \
  org.opencontainers.image.title="docker-webdav-nginx" \
  org.opencontainers.image.description="Runs a Nginx WebDav server in Docker" \
  org.opencontainers.image.created=$BUILD_DATE

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get -y install --no-install-recommends \
    apache2-utils \
    netcat-openbsd \
    nginx-extras && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p "/var/www/webdav/restricted" && \
    mkdir -p "/var/www/webdav/public" && \
    chown -R www-data:www-data "/var/www" && \
    rm /etc/nginx/sites-enabled/default

EXPOSE 80

VOLUME [ "/var/www/webdav" ]

COPY entrypoint.sh /

COPY VERSION /

COPY webdav.conf /etc/nginx/sites-enabled/webdav

ENTRYPOINT ["/entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]

HEALTHCHECK CMD nc -z localhost 80 || exit 1 
