# Overridden per build by ./nimbus-eth2/nim-version.sh, which resolves the Nim
# version the source ref pins. This default only applies to refs that don't
# declare one.
ARG NIM_VERSION=2.2.12
FROM nimlang/nim:${NIM_VERSION} AS build

SHELL ["/bin/bash", "-c"]

RUN apt-get clean && apt update \
 && apt -y install build-essential git-lfs ca-certificates

RUN ldd --version ldd

ADD . /root/nimbus-eth1

RUN cd /root/nimbus-eth1 \
 && rm -rf build/ \
 && make -j$(nproc) USE_SYSTEM_NIM=1 DISABLE_MARCH_NATIVE=1 V=1 nimbus

# --------------------------------- #
# Starting new image to reduce size #
# --------------------------------- #
FROM debian:trixie-slim AS deploy

SHELL ["/bin/bash", "-c"]
RUN apt-get clean && apt update \
 && apt -y install build-essential
RUN apt update && apt -y upgrade

RUN ldd --version

COPY --from=build /root/nimbus-eth1/build/nimbus /home/user/nimbus-eth1/build/nimbus

ENV PATH="/home/user/nimbus-eth1/build:${PATH}"
ENTRYPOINT ["nimbus"]
WORKDIR /home/user/nimbus-eth1/build

STOPSIGNAL SIGINT
