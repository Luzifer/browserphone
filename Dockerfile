FROM node as builder

COPY . /src
WORKDIR /src

RUN set -ex \
 && npm ci \
 && npm run build

RUN set -ex \
 && apt-get update \
 && apt-get install -y \
      curl \
 && curl -sSfLo /tmp/dumb-init "https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64" \
 && chmod +x /tmp/dumb-init \
 && curl -sSfL "https://github.com/Luzifer/korvike/releases/download/v0.5.0/korvike_linux_amd64.tar.gz" | tar -xz -C /tmp


FROM python:3-alpine

LABEL maintainer Knut Ahlers <knut@ahlers.me>

COPY                docker-entrypoint.sh      /usr/local/bin/docker-entrypoint.sh
COPY --from=builder /tmp/dumb-init            /usr/local/bin/dumb-init
COPY --from=builder /tmp/korvike_linux_amd64  /usr/local/bin/korvike
COPY --from=builder /src/dist                 /usr/local/share/browserphone/dist

RUN set -ex \
 && apk --no-cache add bash

EXPOSE 3000/tcp
WORKDIR "/usr/local/share/browserphone/dist"
CMD ["/usr/local/bin/docker-entrypoint.sh"]
