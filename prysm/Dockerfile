FROM ubuntu:latest

ARG ENTRY=/app/cmd/beacon-chain/beacon-chain
ENV ENTRY=${ENTRY}
WORKDIR /app/cmd/beacon-chain/beacon-chain.runfiles/prysm
ADD ./_beacon-chain /app/cmd/beacon-chain/beacon-chain
ADD ./_validator /app/cmd/validator/validator
RUN apt-get update && apt-get install -y ca-certificates libc6 && update-ca-certificates
ENTRYPOINT [ "$ENTRY" ]
