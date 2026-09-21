#! /bin/bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "${SCRIPT_DIR}/../source"

# Backfilling removal: stub needsBackfill out in place
TARGET="beacon_chain/consensus_object_pools/blockchain_dag.nim"
ANCHOR='func needsBackfill\*'
EXPECTED_BODY="  dag.backfill.slot > dag.horizon"

if [ "$(grep -A1 "${ANCHOR}" "${TARGET}" | tail -1)" != "${EXPECTED_BODY}" ]; then
  echo "needsBackfill is not the expected 2-line shape in ${TARGET}, aborting..." >&2
  echo "upstream moved or changed it, re-point this patch at https://github.com/status-im/nimbus-eth2/blob/unstable/${TARGET}" >&2
  exit 1
fi

sed -i "/${ANCHOR}/{n;s|.*|  false|}" "${TARGET}"

# NIM_VERSION is exported by the deploy action from ./nimbus-eth2/nim-version.sh
docker build ${NIM_VERSION:+--build-arg NIM_VERSION="${NIM_VERSION}"} -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
