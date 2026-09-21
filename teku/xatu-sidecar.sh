#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "${SCRIPT_DIR}/.."

# a clone left behind by an earlier run on this runner would both break `set -e` and
# risk patching with stale tooling
rm -rf temu
git clone https://github.com/ethpandaops/temu.git

cd temu
echo "temu commit hash: $(git rev-parse HEAD)"
# Temu still stores patches under Teku's former GitHub organization.
patch_repository="${source_repository}"
if [ "$patch_repository" = "consensys-incorporated/teku" ]; then
    patch_repository="consensys/teku"
fi
./scripts/apply-temu-patch.sh "${patch_repository}" "${source_ref}" ../source

cd ../source

# Build using teku's gradle build process
GRADLE_USER_HOME="$(pwd)/../.gradle"
export GRADLE_USER_HOME

# distDocker always writes the same fixed tag, so drop any copy left behind by an
# earlier build on this runner - otherwise a failed build could be pushed as current.
docker image rm -f consensys/teku:develop > /dev/null 2>&1 || true

./gradlew distDocker

docker tag consensys/teku:develop "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}"
docker tag consensys/teku:develop "${target_repository}:${target_tag}-${source_git_commit_hash}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
