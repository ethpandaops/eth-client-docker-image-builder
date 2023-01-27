FROM debian:11-slim

WORKDIR /app/cmd/beacon-chain/beacon-chain.runfiles/prysm
ADD ./bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /app/cmd/beacon-chain/beacon-chain
ADD ./bazel-bin/cmd/validator/validator_/validator /app/cmd/validator/validator
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates
ENTRYPOINT [ "/app/cmd/beacon-chain/beacon-chain" ]
