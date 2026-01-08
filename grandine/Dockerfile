FROM rust:1.82.0-bullseye AS builder
RUN apt-get clean && apt-get update && apt-get --yes upgrade && apt-get install --yes cmake libclang-dev
COPY . .
RUN scripts/build/release.sh

FROM ubuntu:latest
RUN apt-get clean && apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends \
  libssl-dev \
  ca-certificates \
  curl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /target/compact/grandine /usr/local/bin/grandine

ENTRYPOINT ["grandine"]
