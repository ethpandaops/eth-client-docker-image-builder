#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "${OS_NAME}" == "darwin" ]; then
  /opt/homebrew/bin/brew install go
  /opt/homebrew/bin/go install github.com/bazelbuild/bazelisk@latest
else 
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo apt install -y ca-certificates python3
  go install github.com/bazelbuild/bazelisk@latest
fi

build_with_go() {
  echo "Building with Go..."
  go mod tidy
  CGO_ENABLED=1 go build -o _validator ./cmd/validator
}

build_with_bazel() {
  echo "Building with Bazel..."
  $HOME/go/bin/bazelisk build //cmd/validator:validator --config=release --define pgo_enabled=0 --enable_bzlmod=false --remote_cache=grpcs://bazel-remote-cache-grpc.primary.production.platform.ethpandaops.io:443
  if [ $? -eq 0 ]; then
    # move to base dir to avoid any dockerignore/stat issues
    mv bazel-bin/cmd/validator/validator_/validator _validator
    return 0
  else
    echo "Bazel build failed, falling back to go build..."
    return 1
  fi
}

# Try Bazel first, fall back to Go if it fails.
build_with_bazel || build_with_go

cp ${SCRIPT_DIR}/entrypoint.sh entrypoint.sh

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" --build-arg ENTRY=/app/cmd/validator/validator -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
