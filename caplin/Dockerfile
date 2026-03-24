ARG GOLANG_VERSION=1.25

FROM golang:${GOLANG_VERSION}-trixie AS builder

RUN apt-get update && apt-get install -y --no-install-recommends make g++ libc6-dev && rm -rf /var/lib/apt/lists/*

COPY . erigon

RUN cd erigon && make caplin

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /erigon/build/bin/caplin /usr/local/bin/caplin
ENTRYPOINT ["caplin"]
