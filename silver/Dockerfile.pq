# syntax=docker/dockerfile:1

FROM rust:1.99.1-bookworm AS builder
ARG TARGETARCH
ARG BUF_VERSION=1.67.0
RUN apt-get update && \
    apt-get install -y --no-install-recommends clang && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL -o /usr/local/bin/buf \
      "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/buf-Linux-$(uname -m)" && \
    chmod +x /usr/local/bin/buf

WORKDIR /silver
COPY . .

ARG SILVER_BUILD_COMMIT
RUN --mount=type=cache,id=pq-silver-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=pq-silver-git,target=/usr/local/cargo/git \
    --mount=type=cache,id=pq-silver-target-${TARGETARCH},target=/silver/target \
    if [ "$TARGETARCH" = amd64 ]; then \
      scripts/build-prod.sh --features silver/metrics --bin silver --bin silver_surfer; \
    else \
      cargo build --profile release-prod --locked --features silver/metrics --bin silver --bin silver_surfer; \
    fi && \
    cp target/release-prod/silver target/release-prod/silver_surfer /usr/local/bin/

FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*
ENV LOG_STDOUT=1
COPY --from=builder /usr/local/bin/silver /usr/local/bin/silver_surfer /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/silver"]
