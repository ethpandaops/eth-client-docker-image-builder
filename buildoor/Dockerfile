# ── Stage 1: Build frontend ──────────────────────────────────────
FROM node:20-alpine AS ui

RUN apk add --no-cache make

WORKDIR /app/pkg/webui

# Copy dependency manifests first for layer caching
COPY pkg/webui/package.json pkg/webui/package-lock.json* pkg/webui/Makefile ./
RUN make install

# Copy source and build
COPY pkg/webui/tsconfig.json pkg/webui/webpack.config.js ./
COPY pkg/webui/src/ src/
RUN make build

# ── Stage 2: Build Go binary (CGO required for herumi BLS) ──────
FROM golang:1.25-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download Go modules first for layer caching
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Overlay frontend static assets from stage 1 (ensure-ui will skip npm)
COPY --from=ui /app/pkg/webui/static/ pkg/webui/static/

ARG VERSION=dev
ARG BUILDTIME
ARG RELEASE
RUN CGO_ENABLED=1 make build \
    VERSION="${VERSION}" \
    BUILDTIME="$(date '+%Y-%m-%dT%H:%M:%SZ')" \
    RELEASE="${RELEASE}"

# ── Stage 3: Minimal runtime ────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -r -s /bin/false buildoor
USER buildoor

COPY --from=builder /app/bin/buildoor /usr/local/bin/buildoor

EXPOSE 9000

ENTRYPOINT ["buildoor"]
CMD ["run"]
