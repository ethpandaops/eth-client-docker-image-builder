#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/..

git clone https://github.com/ethpandaops/dimhouse.git

cd dimhouse
git pull
echo "dimhouse commit hash: $(git rev-parse HEAD)"
./apply-dimhouse-patch.sh ${source_repository} ${source_ref} ../source

cd ../source

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
