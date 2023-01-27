FROM debian:11-slim

WORKDIR /app/cmd/beacon-chain/beacon-chain.runfiles/prysm
ADD ./beacon-chain /app/cmd/beacon-chain/beacon-chain
ADD ./validator /app/cmd/validator/validator
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates
ENTRYPOINT [ "/app/cmd/beacon-chain/beacon-chain" ]
