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

build_method=${build_method:-bazel}  # Default to bazel if not set

case ${build_method} in
  "go")
    echo "Building with Go..."
    go mod tidy

    # Define ldflags for version information
    ldflags=$(cat <<-END
        -X 'github.com/offchainlabs/prysm/v5/runtime/version.gitCommit=$(git rev-parse HEAD)' \
        -X 'github.com/offchainlabs/prysm/v5/runtime/version.gitTag=$(git describe --tags 2>/dev/null || echo Unknown)' \
        -X 'github.com/offchainlabs/prysm/v5/runtime/version.buildDate=$(date -u +%Y-%m-%d\ %H:%M:%S%:z)' \
        -X 'github.com/offchainlabs/prysm/v5/runtime/version.buildDateUnix=$(date +%s)'
END
    )

    # Build with blst_enabled and blst_portable to support both amd64 and arm64. The BLST library (used for
    # cryptographic operations) needs specific CPU features.
    CGO_ENABLED=1 go build \
      -tags=blst_enabled,blst_portable \
      -ldflags "${ldflags}" \
      -o _beacon-chain ./cmd/beacon-chain
    ;;
  "bazel")
    echo "Building with Bazel..."
    # Try with remote cache first
    if ! $HOME/go/bin/bazelisk build //cmd/beacon-chain:beacon-chain --config=release --define pgo_enabled=0 --enable_bzlmod=false --remote_cache=grpcs://bazel-remote-cache-grpc.primary.production.platform.ethpandaops.io:443; then
      echo "Build failed with remote cache, trying without remote cache..."
      # Try without remote cache to avoid cache corruption issues
      if ! $HOME/go/bin/bazelisk build //cmd/beacon-chain:beacon-chain --config=release --define pgo_enabled=0 --enable_bzlmod=false; then
        echo "Build still failing, cleaning local Bazel cache and retrying..."
        # Clean the local Bazel cache and try once more
        $HOME/go/bin/bazelisk clean --expunge
        $HOME/go/bin/bazelisk build //cmd/beacon-chain:beacon-chain --config=release --define pgo_enabled=0 --enable_bzlmod=false
      fi
    fi
    mv bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain _beacon-chain
    ;;
  *)
    echo "Invalid build_method value: ${build_method}. Must be 'go' or 'bazel'"
    exit 1
    ;;
esac

cp ${SCRIPT_DIR}/entrypoint.sh entrypoint.sh

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" --build-arg ENTRY=/app/cmd/beacon-chain/beacon-chain -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"