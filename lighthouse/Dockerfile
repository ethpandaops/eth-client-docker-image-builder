FROM rust:1.88-bullseye AS builder
RUN apt-get clean && apt-get update && apt-get -y upgrade && apt-get install -y cmake clang libclang-dev protobuf-compiler
COPY . lighthouse
ARG FEATURES=gnosis,spec-minimal,slasher-lmdb
ARG PROFILE=release
ARG CARGO_USE_GIT_CLI=true
ENV FEATURES=$FEATURES
ENV PROFILE=$PROFILE
ENV CARGO_NET_GIT_FETCH_WITH_CLI=$CARGO_USE_GIT_CLI
RUN cd lighthouse && make

FROM ubuntu:22.04
RUN apt-get clean && apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends \
  libssl-dev \
  ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/cargo/bin/lighthouse /usr/local/bin/lighthouse
