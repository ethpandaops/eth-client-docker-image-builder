#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

sudo apt-get update
sudo apt install -y ca-certificates python2 golang-go
go install github.com/bazelbuild/bazelisk@latest
$HOME/go/bin/bazelisk build //cmd/beacon-chain:beacon-chain --config=release
$HOME/go/bin/bazelisk build //cmd/validator:validator --config=release
# move to base dir to avoid any dockerignore/stat issues
mv bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain _beacon-chain
mv bazel-bin/cmd/validator/validator_/validator _validator
cp ${SCRIPT_DIR}/entrypoint.sh entrypoint.sh

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" --build-arg ENTRY=/app/cmd/beacon-chain/beacon-chain -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"

docker build -t "${target_repository}-validator:${target_tag}" -t "${target_repository}-validator:${target_tag}-${source_git_commit_hash}" --build-arg ENTRY=/app/cmd/validator/validator -f "../${target_dockerfile}" .
docker push "${target_repository}-validator:${target_tag}"
docker push "${target_repository}-validator:${target_tag}-${source_git_commit_hash}"
