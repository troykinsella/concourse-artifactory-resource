FROM alpine:latest as main
LABEL maintainer="Troy Kinsella <troy.kinsella@gmail.com>"

COPY assets/* /opt/resource/

RUN set -eux; \
    apk --update --no-cache add \
      bash \
      ca-certificates \
      curl \
      jq;

FROM main as testing

RUN set -eux; \
    apk --update --no-cache add \
      bash \
      ruby \
      ruby-json \
      wget; \
    gem install rspec --no-document; \
    wget -q -O - https://raw.githubusercontent.com/troykinsella/mockleton/master/install.sh | bash; \
    cp /usr/local/bin/mockleton /usr/bin/curl; \
    rm -rf /var/cache/apk/*;

COPY . /resource/

RUN set -eux; \
    cd /resource; \
    rspec

FROM main
