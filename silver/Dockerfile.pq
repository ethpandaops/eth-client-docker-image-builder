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
    bins="silver silver_surfer" && \
    if [ -d crates/vc ]; then bins="$bins silver-vc"; fi && \
    bin_args=$(for b in $bins; do printf -- '--bin %s ' "$b"; done) && \
    if [ "$TARGETARCH" = amd64 ]; then \
      scripts/build-prod.sh --features "$features" $bin_args; \
    else \
      cargo build --profile release-prod --locked --features "$features" $bin_args; \
    fi && \
    mkdir -p /out && \
    for b in $bins; do cp "target/release-prod/$b" /out/; done

FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*
ENV LOG_STDOUT=1
COPY --from=builder /out/ /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/silver"]
