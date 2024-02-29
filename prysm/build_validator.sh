#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "${OS_NAME}" == "darwin" ]; then
  /opt/homebrew/bin/brew install go
  /opt/homebrew/bin/go install github.com/bazelbuild/bazelisk@latest
else 
  sudo apt-get update
  sudo apt install -y ca-certificates python2 golang-go
  go install github.com/bazelbuild/bazelisk@latest
fi
$HOME/go/bin/bazelisk build //cmd/validator:validator --config=release --define pgo_enabled=0
# move to base dir to avoid any dockerignore/stat issues
mv bazel-bin/cmd/validator/validator_/validator _validator
cp ${SCRIPT_DIR}/entrypoint.sh entrypoint.sh

docker build -t "${target_repository}-validator:${target_tag}" -t "${target_repository}-validator:${target_tag}-${source_git_commit_hash}" --build-arg ENTRY=/app/cmd/validator/validator -f "../${target_dockerfile}" .
docker push "${target_repository}-validator:${target_tag}"
docker push "${target_repository}-validator:${target_tag}-${source_git_commit_hash}"
