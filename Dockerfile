FROM ubuntu:bionic

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates \
      curl; \
    apt-get clean all; \
    rm -rf /var/lib/apt/lists/*
