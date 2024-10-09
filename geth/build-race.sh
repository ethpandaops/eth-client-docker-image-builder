#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

ORIGINAL_CI_FILE="build/ci.go"
NEW_CI_FILE="build/ci.race.go"

awk '
/^func buildFlags\(env build\.Environment, staticLinking bool, buildTags \[\]string\) \(flags \[\]string\)/ {
    print
    getline
    print "       flags = append(flags, \"-race\")"
}
/^[^f]/ { print }
/^func / && !/^func buildFlags/ { print }
' "$ORIGINAL_CI_FILE" > "$NEW_CI_FILE"

if((`stat -c%s "${ORIGINAL_CI_FILE}"`==`stat -c%s "${NEW_CI_FILE}"`));then
  echo "no changes detected, aborting..."
  echo "needed to update build/ci.go"
  exit 1
fi

mv $NEW_CI_FILE $ORIGINAL_CI_FILE

docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" -f "../${target_dockerfile}" .
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
