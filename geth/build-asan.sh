#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

# need to update dockerfile to use debian instead of alpine
# as asan go builds doesn't seem to like alpine
ORIGINAL_DOCKER_FILE="Dockerfile"
NEW_DOCKER_FILE="Dockerfile.asan"

sed -e 's|-alpine AS builder| AS builder|' \
    -e 's|RUN apk add --no-cache gcc musl-dev linux-headers git|RUN apt-get update \&\& apt-get install -y --no-install-recommends build-essential git \&\& rm -rf /var/lib/apt/lists/*|' \
    -e 's|RUN cd /go-ethereum \&\& go run build/ci.go install -static ./cmd/geth|RUN cd /go-ethereum \&\& go run build/ci.go install ./cmd/geth|' \
    -e 's|FROM alpine:latest|FROM debian:bookworm-slim|' \
    -e 's|RUN apk add --no-cache ca-certificates|RUN apt-get update \&\& apt-get install -y --no-install-recommends ca-certificates libasan8 \&\& rm -rf /var/lib/apt/lists/*|' \
    "$ORIGINAL_DOCKER_FILE" > "$NEW_DOCKER_FILE"

if((`stat -c%s "${ORIGINAL_DOCKER_FILE}"`==`stat -c%s "${NEW_DOCKER_FILE}"`));then
  echo "no changes detected, aborting..."
  echo "needed to update dockerfile"
  exit 1
fi

mv $NEW_DOCKER_FILE $ORIGINAL_DOCKER_FILE

# need to add -asan flag to geth custom build script
ORIGINAL_CI_FILE="build/ci.go"
NEW_CI_FILE="build/ci.asan.go"

awk '
/^func buildFlags\(env build\.Environment, staticLinking bool, buildTags \[\]string\) \(flags \[\]string\)/ {
    print
    getline
    print "       flags = append(flags, \"-asan\")"
}
/^[^f]/ { print }
/^func / && !/^func buildFlags/ { print }
' "$ORIGINAL_CI_FILE" > "$NEW_CI_FILE"

if((`stat -c%s "${ORIGINAL_CI_FILE}"`==`stat -c%s "${NEW_CI_FILE}"`));then
  echo "no changes detected, aborting..."
  echo "needed to update build/ci.go"
  exit 1
fi

mv $NEW_CI_FILE $ORIGINAL_CI_FILE

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
