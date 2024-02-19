FROM debian:testing-slim AS build

SHELL ["/bin/bash", "-c"]

RUN apt update \
 && apt -y install build-essential git-lfs librocksdb-dev


RUN ldd --version ldd

ADD . /root/nimbus-eth1

RUN cd /root/nimbus-eth1 \
 && make -j$(nproc) update \
 && make -j$(nproc) V=1 LOG_LEVEL=TRACE nimbus

# --------------------------------- #
# Starting new image to reduce size #
# --------------------------------- #
FROM debian:testing-slim as deploy

SHELL ["/bin/bash", "-c"]
RUN apt update \
 && apt -y install build-essential
RUN apt update && apt -y upgrade

RUN ldd --version ldd

RUN rm -rf /home/user/nimbus-eth1/build/nimbus

COPY --from=build /root/nimbus-eth1/build/nimbus /home/user/nimbus-eth1/build/nimbus

ENV PATH="/home/user/nimbus-eth1/build:${PATH}"
ENTRYPOINT ["nimbus"]
WORKDIR /home/user/nimbus-eth1/build

STOPSIGNAL SIGINT
