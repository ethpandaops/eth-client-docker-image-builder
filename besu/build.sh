#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source
./gradlew distDocker

# generate the docker image tag based off besu gradle build
getImageTag() {
    local length=${1:-8} # Default length
    local gitFolder="$PWD/.git/"
    if [ ! -d "$gitFolder" ]; then
        # If not a directory, attempt to follow the .git file indication for worktrees or submodules
        gitFolder=$(cat "$gitFolder" | awk '{print $2}')"/"
    fi

    local headContent=$(cat "${gitFolder}HEAD")
    local isCommit=0
    local commitHash=""
    local refHeadFile=""

    if [[ $headContent =~ ^ref: ]]; then
        # It's a reference to a branch
        local ref=$(echo $headContent | cut -d ' ' -f 2)
        refHeadFile="${gitFolder}${ref}"
        commitHash=$(cat "$refHeadFile" | cut -c1-$length)
    else
        # It's a direct commit hash in HEAD
        isCommit=1
        commitHash=$(echo $headContent | cut -c1-$length)
        refHeadFile="${gitFolder}HEAD"
    fi

    # Use head file modification time as a proxy for the build date
    local lastModified=$(date -r "$refHeadFile" "+%y.%-m") # Format date as "yy.M"

    echo "${lastModified}-develop-${commitHash}-openjdk-17"
}

docker tag "hyperledger/besu:$(getImageTag 10)" "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}"
docker tag "hyperledger/besu:$(getImageTag 10)" "${target_repository}:${target_tag}-${source_git_commit_hash}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
