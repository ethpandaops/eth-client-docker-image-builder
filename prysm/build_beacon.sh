#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "${OS_NAME}" == "darwin" ]; then
  /opt/homebrew/bin/brew install go
else
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo apt install -y ca-certificates
fi

go mod tidy

# Define ldflags for version information
version_pkg="$(awk '$1 == "module" {print $2; exit}' go.mod)/runtime/version"
ldflags=$(cat <<-END
    -X '${version_pkg}.gitCommit=$(git rev-parse HEAD)' \
    -X '${version_pkg}.gitTag=$(git describe --tags --abbrev=0 2>/dev/null || echo Unknown)' \
    -X '${version_pkg}.buildDate=$(date -u +%Y-%m-%d\ %H:%M:%S%:z)' \
    -X '${version_pkg}.buildDateUnix=$(date +%s)'
END
)

# Build with blst_enabled and blst_portable to support both amd64 and arm64. The BLST library (used for
# cryptographic operations) needs specific CPU features.
CGO_ENABLED=1 go build \
  -tags=blst_enabled,blst_portable \
  -ldflags "${ldflags}" \
  -o _beacon-chain ./cmd/beacon-chain

cp ${SCRIPT_DIR}/entrypoint.sh entrypoint.sh

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" --build-arg ENTRY=/app/cmd/beacon-chain/beacon-chain ${LEANVM_REV:+--build-arg "LEANVM_REV=${LEANVM_REV}"} -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"