#! /bin/bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "${SCRIPT_DIR}/../source"

# Backfilling removal: delete the block by resolved line range so the deletion
# can never run to EOF if an anchor moves upstream.
TARGET="beacon_node/network/src/sync/manager.rs"
START='// complete a backfill sync\.'
END='// Return the sync state if backfilling is not required\.'

start_line=$(grep -n "${START}" "${TARGET}" | cut -d: -f1 || true)
end_line=$(grep -n "${END}" "${TARGET}" | cut -d: -f1 || true)

if ! [ "${start_line}" -gt 0 ] 2>/dev/null || ! [ "${end_line}" -gt "${start_line}" ] 2>/dev/null; then
  echo "backfill block anchors not resolvable in ${TARGET} (start='${start_line}' end='${end_line}'), aborting..." >&2
  echo "upstream moved or changed it, re-point this patch at https://github.com/sigp/lighthouse/blob/unstable/${TARGET}" >&2
  exit 1
fi

sed -i "${start_line},${end_line}d" "${TARGET}"

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
