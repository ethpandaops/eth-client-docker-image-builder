#! /bin/bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "${SCRIPT_DIR}/.."

# a clone left behind by an earlier run on this runner would both break `set -e` and
# risk patching with stale tooling
rm -rf dimhouse
git clone https://github.com/ethpandaops/dimhouse.git

cd dimhouse
echo "dimhouse commit hash: $(git rev-parse HEAD)"
./apply-dimhouse-patch.sh "${source_repository}" "${source_ref}" ../source

cd ../source

# Use dimhouse patched lighthouse dockerfile without cache, this also adds the xatulib.so to the image
docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
