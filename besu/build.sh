#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source
./gradlew distDocker

# generate the docker image tag based off besu gradle build
# view the calculateVersion gradle function incase of changes upstream
# https://github.com/hyperledger/besu/blob/main/build.gradle
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

    echo "${lastModified}-develop-${commitHash}"
}

# list all docker images
echo "Listing all docker images from gradle build:"
docker images --format "{{.Repository}}:{{.Tag}}"

# list of tags to check for after building from gradle
gradle_tags=(
    "${source_repository}:$(getImageTag)"
    "${source_repository}:$(getImageTag 7)" # legacy tag
)

echo "Listing all calculated image tags:"
for gradle_tag in "${gradle_tags[@]}"; do
    echo "${gradle_tag}"
done

tag=""
for gradle_tag in "${gradle_tags[@]}"; do
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${gradle_tag}"; then
        tag="${gradle_tag}"
        echo "Matched ${gradle_tag} as the correct image tag."
        break
    fi
done

if [ -z "$tag" ]; then
    echo "Error: Can't find expected image tag after building from Gradle. Might be updates to source repository's build.gradle."
    exit 1
fi

docker tag "${tag}" "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}"
docker tag "${tag}" "${target_repository}:${target_tag}-${source_git_commit_hash}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
