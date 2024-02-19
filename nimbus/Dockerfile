FROM debian:testing-slim AS build

SHELL ["/bin/bash", "-c"]

RUN apt update \
 && apt -y install build-essential git-lfs

RUN ldd --version ldd

ADD . /root/nimbus-eth2

RUN cd /root/nimbus-eth2 \
 && make -j$(nproc) update \
 && make -j$(nproc) V=1 NIMFLAGS="-d:const_preset=mainnet -d:disableMarchNative" LOG_LEVEL=TRACE nimbus_beacon_node nimbus_validator_client


# --------------------------------- #
# Starting new image to reduce size #
# --------------------------------- #
FROM debian:testing-slim as deploy

SHELL ["/bin/bash", "-c"]
RUN apt update \
 && apt -y install build-essential
RUN apt update && apt -y upgrade

RUN ldd --version ldd

RUN rm -rf /home/user/nimbus-eth2/build/beacon_node

# "COPY" creates new image layers, so we cram all we can into one command
COPY --from=build /root/nimbus-eth2/build/nimbus_beacon_node /home/user/nimbus-eth2/build/beacon_node
COPY --from=build /root/nimbus-eth2/build/nimbus_beacon_node /home/user/nimbus-eth2/build/nimbus_beacon_node
COPY --from=build /root/nimbus-eth2/build/nimbus_validator_client /home/user/nimbus-eth2/build/nimbus_validator_client

ENV PATH="/home/user/nimbus-eth2/build:${PATH}"
ENTRYPOINT ["nimbus_beacon_node"]
WORKDIR /home/user/nimbus-eth2/build

STOPSIGNAL SIGINT

# Caller can use either 'beacon_node' or 'validator_client' binary
