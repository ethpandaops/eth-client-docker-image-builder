#!/usr/bin/env bash
#
# Find published AOT caches that have no baked image yet, and print a JSON
# matrix of {base_tag, aot_url} for the bake job.
#
# The Besu team publishes one GitHub release per cache on AOT_RELEASE_REPO:
# a single .aot asset and the full besu commit sha in the release body. For each
# such release this resolves every ethpandaops/besu:<devnet>-<sha7> tag built
# from that commit and emits the ones lacking a <devnet>-aot-<sha7> twin.
#
# Inputs (env):
#   AOT_RELEASE_REPO   GitHub repo publishing caches. Default ahamlat/besu.
#   AOT_RELEASE_TAG    Only this release (workflow_dispatch). Default: all.
#   BASE_TAG           Only this base tag. Default: every tag built from the commit.
#   FORCE              true = emit even if the -aot- twin exists. Default false.
#   target_repository  Docker Hub repository. Default ethpandaops/besu.
#   GH_TOKEN           Optional; raises the GitHub API rate limit.
set -euo pipefail

AOT_RELEASE_REPO="${AOT_RELEASE_REPO:-ahamlat/besu}"
AOT_RELEASE_TAG="${AOT_RELEASE_TAG:-}"
BASE_TAG="${BASE_TAG:-}"
FORCE="${FORCE:-false}"
target_repository="${target_repository:-ethpandaops/besu}"
hub="https://hub.docker.com/v2/repositories/${target_repository}/tags"
api="https://api.github.com/repos/${AOT_RELEASE_REPO}/releases"

fetch() { curl -fsSL --retry 3 --retry-delay 5 "$@"; }
gh_fetch() { fetch -H "Accept: application/vnd.github+json" ${GH_TOKEN:+-H "Authorization: Bearer ${GH_TOKEN}"} "$@"; }
tag_exists() { curl -fsSo /dev/null --retry 3 --retry-delay 5 "${hub}/$1"; }

if [ -n "${AOT_RELEASE_TAG}" ]; then
  releases="[$(gh_fetch "${api}/tags/${AOT_RELEASE_TAG}")]"
else
  releases=$(gh_fetch "${api}?per_page=50")
fi

# One line per usable release: <release tag> <sha> <asset url>.
# The sha is taken from the body (a link to the besu commit) and, failing that,
# from a trailing -<sha> on the release tag.
candidates=$(jq -r '.[]
  | select(.draft | not)
  | (.assets | map(select(.name | endswith(".aot")))) as $a
  | select($a | length == 1)
  | (((.body // "") | capture("(?<sha>[0-9a-f]{40})").sha)
      // (.tag_name | capture("-(?<sha>[0-9a-f]{7,40})$").sha)
      // null) as $sha
  | select($sha != null)
  | [.tag_name, $sha, $a[0].browser_download_url] | @tsv' <<<"${releases}")

matrix="[]"
while IFS=$'\t' read -r tag sha url; do
  [ -n "${tag}" ] || continue
  sha7="${sha:0:7}"

  # Every <prefix>-<sha7> tag except the per-platform ones and baked ones.
  bases=$(fetch "${hub}?name=-${sha7}&page_size=100" | jq -r --arg s "${sha7}" '.results[].name
    | select(endswith("-" + $s))
    | select(test("-linux-(amd|arm)64-" + $s + "$") | not)
    | select(test("-aot-") | not)')
  if [ -n "${BASE_TAG}" ]; then
    grep -qx "${BASE_TAG}" <<<"${bases}" || { echo "${tag}: ${target_repository}:${BASE_TAG} is not built from ${sha7}" >&2; exit 1; }
    bases="${BASE_TAG}"
  fi
  [ -n "${bases}" ] || { echo "${tag}: no ${target_repository} tag built from ${sha7} yet" >&2; continue; }

  for base in ${bases}; do
    aot="${base%-"${sha7}"}-aot-${sha7}"
    if jq -e --arg b "${base}" 'any(.base_tag == $b)' <<<"${matrix}" >/dev/null; then
      echo "${tag}: ${base} already queued from a newer release, skipping" >&2; continue
    fi
    if [ "${FORCE}" != "true" ] && tag_exists "${aot}"; then
      echo "${tag}: ${aot} exists, skipping" >&2; continue
    fi
    echo "${tag}: bake ${aot} from ${base}" >&2
    matrix=$(jq -c --arg b "${base}" --arg u "${url}" '. + [{base_tag: $b, aot_url: $u}]' <<<"${matrix}")
  done
done <<<"${candidates}"

echo "${matrix}"
