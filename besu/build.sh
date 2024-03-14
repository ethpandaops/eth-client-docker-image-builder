#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source
./gradlew distDocker

# pull the version from gradle props
BUILT_IMAGE_TAG=openjdk-17

docker tag "hyperledger/besu:${BUILT_IMAGE_TAG}" "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}"
docker tag "hyperledger/besu:${BUILT_IMAGE_TAG}" "${target_repository}:${target_tag}-${source_git_commit_hash}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
