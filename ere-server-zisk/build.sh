#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

CUDA_ARCH="${CUDA_ARCH:-sm_120}"

echo "Building ere-server-zisk with CUDA (arch: ${CUDA_ARCH})"

echo "Stage 1/3: Building ere-base image..."
docker build \
  --build-arg CUDA=1 \
  -f docker/Dockerfile.base \
  -t ere-base:local \
  .

echo "Stage 2/3: Building ere-base-zisk image..."
docker build \
  --build-arg BASE_IMAGE=ere-base:local \
  --build-arg CUDA=1 \
  --build-arg CUDA_ARCH="${CUDA_ARCH}" \
  -f docker/zisk/Dockerfile.base \
  -t ere-base-zisk:local \
  .

echo "Stage 3/3: Building ere-server-zisk image..."
docker build \
  --build-arg BASE_ZKVM_IMAGE=ere-base-zisk:local \
  --build-arg CUDA=1 \
  -f docker/zisk/Dockerfile.server \
  -t "${target_repository}:${target_tag}" \
  -t "${target_repository}:${target_tag}-${source_git_commit_hash}" \
  .

docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
