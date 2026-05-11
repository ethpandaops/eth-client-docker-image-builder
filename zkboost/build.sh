#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

echo "Building zkboost image (commit ${source_git_commit_hash})..."
docker build \
  -f docker/Dockerfile \
  -t "${target_repository}:${target_tag}" \
  -t "${target_repository}:${target_tag}-${source_git_commit_hash}" \
  .

docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
