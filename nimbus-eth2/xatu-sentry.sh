#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

# Backfilling removal
ORIGINAL_FILE="beacon_chain/consensus_object_pools/blockchain_dag.nim"
NEW_FILE="beacon_chain/consensus_object_pools/blockchain_dag.new.nim"

sed -e '/func needsBackfill\*/,+2d' $ORIGINAL_FILE > $NEW_FILE

if((`stat -c%s "${ORIGINAL_FILE}"`==`stat -c%s "${NEW_FILE}"`));then
  echo "no changes detected, aborting..."
  echo "to remove backfilling code, remove this block (on the ref branch/tag/commit) https://github.com/status-im/nimbus-eth2/blob/ba7c0bc091161f261148dbfcb27b21cc48f1fdf8/beacon_chain/consensus_object_pools/blockchain_dag.nim#L2318-L2319"
  exit 1
fi

echo "" >> $NEW_FILE
echo "func needsBackfill*(dag: ChainDAGRef): bool = false" >> $NEW_FILE

mv $NEW_FILE $ORIGINAL_FILE

# Deposit contract lookup removal (breaks in stubbies)
ORIGINAL_FILE="beacon_chain/eth1/eth1_monitor.nim"
NEW_FILE="beacon_chain/eth1/eth1_monitor.new.nim"

sed -e '/if m.chainSyncingLoopFut.isNil:/,+3d' $ORIGINAL_FILE > $NEW_FILE

if((`stat -c%s "${ORIGINAL_FILE}"`==`stat -c%s "${NEW_FILE}"`));then
  echo "no changes detected, aborting..."
  echo "to remove deposit syncing code, remove this block (on the ref branch/tag/commit) https://github.com/status-im/nimbus-eth2/blob/unstable/beacon_chain/eth1/eth1_monitor.nim#L2039-L2041"
  exit 1
fi

mv $NEW_FILE $ORIGINAL_FILE

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
