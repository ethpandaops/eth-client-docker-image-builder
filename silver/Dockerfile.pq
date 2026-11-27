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

ARG COMMIT_HASH
ARG PRESET=mainnet
RUN --mount=type=cache,id=pq-silver-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=pq-silver-git,target=/usr/local/cargo/git \
    --mount=type=cache,id=pq-silver-target-${TARGETARCH}-${PRESET},target=/silver/target \
    export SILVER_BUILD_COMMIT="$COMMIT_HASH" && \
    features=silver/metrics && \
    if [ "$PRESET" = minimal ]; then features="$features,silver/minimal"; fi && \
    if [ "$TARGETARCH" = amd64 ]; then \
      build="scripts/build-prod.sh --features $features"; \
    else \
      build="cargo build --profile release-prod --locked --features $features"; \
    fi && \
    $build --bin silver --bin silver_surfer && \
    mkdir -p /out && \
    cp target/release-prod/silver target/release-prod/silver_surfer /out/ && \
    if [ -d crates/vc ]; then \
      if $build --bin silver-vc; then \
        cp target/release-prod/silver-vc /out/; \
      else \
        echo "warning: silver-vc failed to build, shipping the image without it" >&2; \
      fi; \
    fi

FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*
ENV LOG_STDOUT=1
COPY --from=builder /out/ /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/silver"]
