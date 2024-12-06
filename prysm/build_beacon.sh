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

prysm_build_with=${prysm_build_with:-bazel}  # Default to bazel if not set

case ${prysm_build_with} in
  "go")
    echo "Building with Go..."
    go mod tidy
    CGO_ENABLED=1 go build -o _beacon-chain ./cmd/beacon-chain
    ;;
  "bazel")
    echo "Building with Bazel..."
    $HOME/go/bin/bazelisk build //cmd/beacon-chain:beacon-chain --config=release --define pgo_enabled=0 --enable_bzlmod=false --remote_cache=grpcs://bazel-remote-cache-grpc.primary.production.platform.ethpandaops.io:443
    mv bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain _beacon-chain
    ;;
  *)
    echo "Invalid BUILD_WITH value: ${prysm_build_with}. Must be 'go' or 'bazel'"
    exit 1
    ;;
esac

cp ${SCRIPT_DIR}/entrypoint.sh entrypoint.sh

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" --build-arg ENTRY=/app/cmd/beacon-chain/beacon-chain -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"