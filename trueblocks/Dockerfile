# Builds chifra from trueblocks-core source.

FROM golang:1.25.1-bookworm AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        git \
        libcurl4-openssl-dev \
        make \
        python3 \
    && rm -rf /var/lib/apt/lists/*

COPY . /src
WORKDIR /src

RUN git submodule update --init --recursive
RUN scripts/go-work-sync.sh
RUN mkdir build && cd build && cmake ../src && make -j"$(nproc)"

# ---------------------------------------------------------------------------

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libcurl4 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/bin/chifra /usr/local/bin/chifra

# Ship chifra's bundled per-chain configs (allocs.csv etc.) for known public
# networks; without them chifra's IsNodeArchive can't validate against block 0.
COPY --from=builder /src/src/other/install/per-chain /root/.local/share/trueblocks/config

EXPOSE 8080
ENTRYPOINT ["chifra"]
