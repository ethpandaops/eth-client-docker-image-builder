FROM rust:1.75-buster AS builder
RUN apt-get update && apt-get -y upgrade && apt-get install -y cmake clang libclang-dev protobuf-compiler
COPY . eleel
RUN cd eleel && cargo build --release --bin eleel --target x86_64-unknown-linux-gnu

FROM ubuntu:22.04
RUN apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends \
  libssl-dev \
  ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
COPY --from=builder /eleel/target/x86_64-unknown-linux-gnu/release/eleel /usr/local/bin/eleel
