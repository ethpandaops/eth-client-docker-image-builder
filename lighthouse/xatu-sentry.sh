#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

ORIGINAL_FILE="beacon_node/network/src/sync/manager.rs"
NEW_FILE="beacon_node/network/src/sync/manager.new.rs"

sed '/\/\/ complete a backfill sync\./,/\/\/ Return the sync state if backfilling is not required\./d' $ORIGINAL_FILE > $NEW_FILE

if((`stat -c%s "${ORIGINAL_FILE}"`==`stat -c%s "${NEW_FILE}"`));then
  echo "no changes detected, aborting..."
  echo "to remove backfilling code, remove this block (on the ref branch/tag/commit) https://github.com/sigp/lighthouse/blob/6d5a2b509fac7b6ffe693866f58ba49989f946d7/beacon_node/network/src/sync/manager.rs#L403-L422"
  exit 1
fi

mv $NEW_FILE $ORIGINAL_FILE

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
