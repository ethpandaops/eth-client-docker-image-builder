ARG GOLANG_VERSION=1.24

FROM golang:${GOLANG_VERSION}-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends make gcc g++ && rm -rf /var/lib/apt/lists/*

COPY . erigon

RUN cd erigon && make caplin && cp build/bin/caplin /usr/local/bin/caplin

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/bin/caplin /usr/local/bin/caplin
ENTRYPOINT ["caplin"]
