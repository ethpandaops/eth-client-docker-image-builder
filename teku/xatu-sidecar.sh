#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/..

git clone https://github.com/ethpandaops/temu.git

cd temu
echo "temu commit hash: $(git rev-parse HEAD)"
./apply-temu-patch.sh ${source_repository} ${source_ref} ../source

cd ../source

# Build using teku's gradle build process
./gradlew distDocker
docker tag consensys/teku:develop "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}"
docker tag consensys/teku:develop "${target_repository}:${target_tag}-${source_git_commit_hash}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
