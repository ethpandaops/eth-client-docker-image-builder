FROM debian:buster-slim AS build

SHELL ["/bin/bash", "-c"]

# switch to testing branch to enable an update to >=glibc 2.29 which is required by the nim compiler
RUN echo deb http://ftp.us.debian.org/debian testing main contrib non-free >> /etc/apt/sources.list

# use gcc 10.2.0-15 or older, see https://github.com/status-im/nimbus-eth2/issues/1970#issuecomment-723736321
RUN apt-get -qq update \
 && apt-get -qq -y install build-essential git &>/dev/null \
 && apt-get -qq clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


RUN ldd --version ldd
# TODO: use volumes or bind-mounts instead
ADD nimbus-eth2 /root/nimbus-eth2

# It's up to you to run `git pull; make update` in "nimbus-eth2", outside the container,
# preferably in the "devel" branch.

# Note: -d:insecure allows the insecure http server to run for API support, but it's buggy and insecure.
# We need to run `make update` again because some absolute paths changed.
RUN cd /root/nimbus-eth2 \
 && make -j$(nproc) update \
 && make -j$(nproc) LOG_LEVEL="TRACE" NIMFLAGS="" nimbus_validator_client \
 && make -j$(nproc) LOG_LEVEL="TRACE" NIMFLAGS="" nimbus_beacon_node

# alternatively:
# && make -j$(nproc) LOG_LEVEL=TRACE NIMFLAGS="-d:insecure -d:ETH2_SPEC=v0.12.1 -d:BLS_ETH2_SPEC=v0.12.x -d:const_preset=/root/config.yaml" nimbus_validator_client

# --------------------------------- #
# Starting new image to reduce size #
# --------------------------------- #
FROM statusim/nimbus-eth2:amd64-latest as deploy

SHELL ["/bin/bash", "-c"]

RUN rm -rf /home/user/nimbus-eth2/build/beacon_node

# "COPY" creates new image layers, so we cram all we can into one command
COPY --from=build /root/nimbus-eth2/build/nimbus_validator_client /home/user/nimbus-eth2/build/validator_client
COPY --from=build /root/nimbus-eth2/build/nimbus_beacon_node /home/user/nimbus-eth2/build/beacon_node

ENV PATH="/home/user/nimbus-eth2/build:${PATH}"
ENTRYPOINT [""]
WORKDIR /home/user/nimbus-eth2/build

STOPSIGNAL SIGINT

# Caller can use either 'beacon_node' or 'validator_client' binary