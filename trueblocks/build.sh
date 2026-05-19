#!/bin/bash
# Builds the ethpandaops/trueblocks image. Invoked by the deploy action with
# ${target_dockerfile} pointing at ./trueblocks/Dockerfile and the trueblocks-core
# source already checked out at ./source. We stage entrypoint.sh into the
# source tree (so the Dockerfile's COPY can reach it from the build context)
# then build & push the standard tags.
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "${SCRIPT_DIR}/../source"

cp "${SCRIPT_DIR}/entrypoint.sh" ./.trueblocks-entrypoint.sh

build_arg_flags=()
while IFS= read -r arg; do
  [ -n "${arg}" ] && build_arg_flags+=(--build-arg "${arg}")
done <<< "${build_args:-}"

docker build \
  "${build_arg_flags[@]}" \
  -t "${target_repository}:${target_tag}" \
  -t "${target_repository}:${target_tag}-${source_git_commit_hash}" \
  -f "../${target_dockerfile}" \
  .

docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
