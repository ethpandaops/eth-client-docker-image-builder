#!/usr/bin/env bash
#
# Find published AOT caches that have no baked image yet, and print a JSON
# matrix of {base_tag, aot_url} for the bake job.
#
# The Besu team publishes one GitHub release per cache on AOT_RELEASE_REPO:
# a single .aot asset and the full besu commit sha in the release body. A
# cache only loads on the exact image it was recorded against (the JVM checks
# jar mtimes and sizes, not just names), so this never guesses which image
# that was:
#
#   1. release tag "aot-<docker tag>" names the base outright, e.g.
#      aot-glamsterdam-devnet-8-0d7d0f5;
#   2. otherwise the sha from the body must match exactly one
#      <devnet>-<sha7> tag on Docker Hub. Several matches = ambiguous = skip,
#      and the dispatch input base_tag picks one by hand.
#
# Either way the base must have been pushed before the release was published
# (an image re-pushed after the cache was recorded cannot match it), and a
# base whose bake already failed is not retried until the asset is re-uploaded.
#
# Inputs (env):
#   AOT_RELEASE_REPO    GitHub repo publishing caches. Default ahamlat/besu.
#   AOT_RELEASE_AUTHOR  Only releases by this login. Default ahamlat; empty = any.
#   AOT_RELEASE_TAG     Only this release (workflow_dispatch). Default: all.
#   BASE_TAG            Only this base tag. Default: resolved as above.
#   FORCE               true = emit even if the -aot- twin exists. Default false.
#   FAILED_BAKES        Lines of "<base tag>\t<failed at ISO>" from earlier runs.
#   target_repository   Docker Hub repository. Default ethpandaops/besu.
#   GH_TOKEN            Optional; raises the GitHub API rate limit.
set -euo pipefail

AOT_RELEASE_REPO="${AOT_RELEASE_REPO:-ahamlat/besu}"
AOT_RELEASE_AUTHOR="${AOT_RELEASE_AUTHOR-ahamlat}"
AOT_RELEASE_TAG="${AOT_RELEASE_TAG:-}"
BASE_TAG="${BASE_TAG:-}"
FORCE="${FORCE:-false}"
FAILED_BAKES="${FAILED_BAKES:-}"
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

# One line per usable release:
#   <tag> <published> <sha from body|-> <sha from tag|-> <asset url> <asset updated>
candidates=$(jq -r --arg author "${AOT_RELEASE_AUTHOR}" '.[]
  | select(.draft | not)
  | select($author == "" or .author.login == $author)
  | (.assets | map(select(.name | endswith(".aot")))) as $a
  | select($a | length == 1)
  | [ .tag_name, .published_at,
      (((.body // "") | capture("(?<s>[0-9a-f]{40})").s) // "-"),
      ((.tag_name | capture("-(?<s>[0-9a-f]{7,40})$").s) // "-"),
      $a[0].browser_download_url, $a[0].updated_at ] | @tsv' <<<"${releases}")

matrix="[]"
while IFS=$'\t' read -r tag published body_sha tag_sha url asset_updated; do
  [ -n "${tag}" ] || continue

  # The body's commit link is authoritative; a trailing sha on the tag must agree.
  if [ "${body_sha}" = "-" ] && [ "${tag_sha}" = "-" ]; then
    echo "${tag}: no besu commit sha in the release body or tag, skipping" >&2; continue
  fi
  if [ "${body_sha}" != "-" ] && [ "${tag_sha}" != "-" ] && [[ "${body_sha}" != "${tag_sha}"* ]]; then
    echo "${tag}: release tag says ${tag_sha} but body says ${body_sha:0:7}, skipping" >&2; continue
  fi
  sha7=$([ "${body_sha}" != "-" ] && echo "${body_sha:0:7}" || echo "${tag_sha:0:7}")

  # Every <devnet>-<sha7> tag built from that commit, with when it was pushed.
  hub_tags=$(fetch "${hub}?name=-${sha7}&page_size=100" | jq -r --arg s "${sha7}" '.results[]
    | select(.name | endswith("-" + $s))
    | select(.name | test("-linux-(amd|arm)64-" + $s + "$") | not)
    | select(.name | test("-aot-") | not)
    | [.name, .last_updated[0:19]] | @tsv')
  bases=$(cut -f1 <<<"${hub_tags}" | sed '/^$/d')

  if [ -n "${BASE_TAG}" ]; then
    grep -qx "${BASE_TAG}" <<<"${bases}" || { echo "${tag}: ${target_repository}:${BASE_TAG} is not built from ${sha7}" >&2; exit 1; }
    base="${BASE_TAG}"
  elif grep -qx "${tag#aot-}" <<<"${bases}"; then
    base="${tag#aot-}"
  elif [ -z "${bases}" ]; then
    echo "${tag}: no ${target_repository} tag built from ${sha7} yet" >&2; continue
  elif [ "$(wc -l <<<"${bases}")" -eq 1 ]; then
    base="${bases}"
  else
    echo "${tag}: ${sha7} is built under several tags ($(tr '\n' ' ' <<<"${bases}")); name the release aot-<docker tag> or dispatch with base_tag" >&2; continue
  fi

  pushed=$(awk -F'\t' -v b="${base}" '$1 == b { print $2 }' <<<"${hub_tags}")
  if [[ "${pushed}" > "${published:0:19}" ]]; then
    echo "${tag}: ${base} was pushed at ${pushed}Z, after the cache was published; it cannot be the image the cache was recorded on, skipping" >&2; continue
  fi

  aot="${base%-"${sha7}"}-aot-${sha7}"
  if jq -e --arg b "${base}" 'any(.base_tag == $b)' <<<"${matrix}" >/dev/null; then
    echo "${tag}: ${base} already queued from a newer release, skipping" >&2; continue
  fi
  if [ "${FORCE}" != "true" ] && tag_exists "${aot}"; then
    echo "${tag}: ${aot} exists, skipping" >&2; continue
  fi
  failed_at=$(awk -F'\t' -v b="${base}" '$1 == b { print $2 }' <<<"${FAILED_BAKES}" | sort | tail -n 1)
  if [ "${FORCE}" != "true" ] && [ -n "${failed_at}" ] && [[ "${failed_at:0:19}" > "${asset_updated:0:19}" ]]; then
    echo "${tag}: bake onto ${base} failed at ${failed_at} and the asset has not changed since, skipping" >&2; continue
  fi

  echo "${tag}: bake ${aot} from ${base}" >&2
  matrix=$(jq -c --arg b "${base}" --arg u "${url}" '. + [{base_tag: $b, aot_url: $u}]' <<<"${matrix}")
done <<<"${candidates}"

echo "${matrix}"
