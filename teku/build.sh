#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "${SCRIPT_DIR}/../source"
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
