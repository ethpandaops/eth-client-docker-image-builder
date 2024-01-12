#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

docker build --build-arg COMMIT="${source_git_commit_hash}" -t "${target_repository}:${target_tag}" .
docker push "${target_repository}:${target_tag}"
docker tag "${target_repository}:${target_tag}" "${target_repository}:${target_tag}-${source_git_commit_hash}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
