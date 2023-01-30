#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

ORIGINAL_FILE="beacon/pow/src/main/java/tech/pegasys/teku/beacon/pow/Eth1BlockFetcher.java"
NEW_FILE="beacon/pow/src/main/java/tech/pegasys/teku/beacon/pow/Eth1BlockFetcher.new.java"

sed -e '/backfillEth1Blocks.latestCanonicalBlockNumber/,+0d' $ORIGINAL_FILE > $NEW_FILE

if((`stat -c%s "${ORIGINAL_FILE}"`==`stat -c%s "${NEW_FILE}"`));then
  echo "no changes detected, aborting..."
  echo "to remove backfilling code, remove this block (on the ref branch/tag/commit) https://github.com/ConsenSys/teku/blob/19478cda9358bdf12f3a501bcbd9aafc793a51f7/beacon/pow/src/main/java/tech/pegasys/teku/beacon/pow/Eth1BlockFetcher.java#L60"
  exit 1
fi

mv $NEW_FILE $ORIGINAL_FILE

./gradlew distDocker
docker tag consensys/teku:develop-jdk16 "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}"
docker tag consensys/teku:develop-jdk16 "${target_repository}:${target_tag}-${source_git_commit_hash}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
