FROM rust:1.76-bullseye AS builder
RUN apt-get update && apt-get -y upgrade && apt-get install -y cmake clang libclang-dev protobuf-compiler
COPY . lighthouse
RUN cd lighthouse && make

FROM ubuntu:22.04
RUN apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends \
  libssl-dev \
  ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/cargo/bin/lighthouse /usr/local/bin/lighthouse
