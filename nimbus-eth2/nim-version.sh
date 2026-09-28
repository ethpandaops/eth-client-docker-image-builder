#! /bin/bash
#
# Prints the NIM_VERSION docker build arg for a nimbus-eth2 build, on stdout.
#
# Three sources declare the Nim version a ref builds with, in decreasing order
# of authority:
#
# 1. The canonical one - the compiler nimbus actually builds with, reached by
#    following the gitlinks:
#      nimbus-eth2 -> vendor/nimbus-build-system -> vendor/Nim -> a Nim commit
#    and reading NimMajor/NimMinor/NimPatch out of lib/system/compilation.nim in
#    that Nim tree. Our source checkout has no submodules, so the gitlinks are
#    resolved over the GitHub API rather than by cloning. Both repositories are
#    taken from the .gitmodules that declares them, never assumed, because we
#    build forks of nimbus-eth2 as readily as status-im/nimbus-eth2.
# 2. `requires("nim == 2.2.12", ...)` in beacon_chain.nimble - the production
#    version, maintained alongside Nimble support that nimbus doesn't use yet.
# 3. `const v = ["2.2.12", "2.2.13"]` in config.nims, asserted at compile time:
#      doAssert [$NimMajor, $NimMinor, $NimPatch].join(".") in v,
#        "nimbus-eth2 requires one of Nim versions " & $v
#    It lists upcoming versions under test besides the one in production, and
#    is what fails the build loudly on a wrong compiler - which is what a
#    version hardcoded in our Dockerfiles ran into. So it doesn't pick the
#    version, it vetoes: a candidate it rejects is dropped.
#
# Only even minor and patch numbers are Nim releases (2.2.10, 2.2.12, 2.4.0,
# 2.4.2, ...); odd ones are devel snapshots published only as nightlies, never
# as a docker image - there is no 2.1.x or 2.3.x at all. Per tersec, 2026-09-18.
#
# Each source is optional: whatever resolves is tried against Docker Hub in
# order, and refs that declare nothing print nothing, leaving the Dockerfile
# default in place.

set -euo pipefail

SOURCE_DIR="${source_dir:-./source}"
NIMBLE="${beacon_chain_nimble:-${SOURCE_DIR}/beacon_chain.nimble}"
CONFIG_NIMS="${config_nims:-${SOURCE_DIR}/config.nims}"
PLATFORM="${platform:-linux/amd64}"
ARCH="${PLATFORM##*/}"

VERSION_RE='[0-9]+\.[0-9]+\.[0-9]+'
SHA_RE='[0-9a-f]{40}'

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

gh_api() {
  local url="$1"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -sfL --max-time 20 -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" "$url"
  else
    curl -sfL --max-time 20 -H "Accept: application/vnd.github+json" "$url"
  fi
}

# url of the submodule registered for a path, out of a .gitmodules file
submodule_url() {
  local gitmodules="$1" want="$2" name
  name=$(git config -f "$gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | awk -v p="$want" '$2 == p { sub(/^submodule\./, "", $1); sub(/\.path$/, "", $1); print $1; exit }') || true
  [ -n "$name" ] || return 1
  git config -f "$gitmodules" --get "submodule.${name}.url"
}

# https://github.com/status-im/nimbus-build-system.git -> status-im/nimbus-build-system
github_slug() {
  local url="${1%.git}"
  case "$url" in
    https://github.com/*|http://github.com/*) echo "${url#*://github.com/}" ;;
    ssh://git@github.com/*)                   echo "${url#ssh://git@github.com/}" ;;
    git@github.com:*)                         echo "${url#git@github.com:}" ;;
    *) return 1 ;;
  esac
}

# the repo a checkout's submodule points at, as owner/name
submodule_slug() {
  local gitmodules="$1" path="$2" url
  url=$(submodule_url "$gitmodules" "$path") || return 1
  github_slug "$url" || return 1
}

# nimbus-eth2 -> vendor/nimbus-build-system -> vendor/Nim -> Nim's own version
canonical_version() {
  local nbs_slug nbs_sha nim_slug nim_sha nbs_gitmodules major minor patch

  nbs_slug=$(submodule_slug "${SOURCE_DIR}/.gitmodules" vendor/nimbus-build-system) || nbs_slug=""
  if [ -z "$nbs_slug" ]; then
    echo "could not tell which github repo ${SOURCE_DIR} vendors nimbus-build-system from" >&2
    return 1
  fi

  # The gitlink is in our checkout, no network needed for this one
  nbs_sha=$(git -C "$SOURCE_DIR" rev-parse "HEAD:vendor/nimbus-build-system" 2>/dev/null) || nbs_sha=""
  if ! grep -qE "^${SHA_RE}$" <<< "$nbs_sha"; then
    echo "could not read the vendor/nimbus-build-system gitlink from ${SOURCE_DIR}" >&2
    return 1
  fi

  nim_sha=$(gh_api "https://api.github.com/repos/${nbs_slug}/contents/vendor/Nim?ref=${nbs_sha}" \
    | grep -oE "\"sha\"[[:space:]]*:[[:space:]]*\"${SHA_RE}\"" | grep -oE "$SHA_RE" | head -n1) || nim_sha=""
  if ! grep -qE "^${SHA_RE}$" <<< "$nim_sha"; then
    echo "could not resolve vendor/Nim in ${nbs_slug}@${nbs_sha:0:7}" >&2
    return 1
  fi

  # which Nim repo that commit lives in is nimbus-build-system's business too
  nbs_gitmodules="${TMP_DIR}/nbs.gitmodules"
  curl -sfL --max-time 20 "https://raw.githubusercontent.com/${nbs_slug}/${nbs_sha}/.gitmodules" \
    -o "$nbs_gitmodules" || true
  nim_slug=""
  [ -s "$nbs_gitmodules" ] && nim_slug=$(submodule_slug "$nbs_gitmodules" vendor/Nim) || true
  if [ -z "$nim_slug" ]; then
    echo "could not tell which github repo ${nbs_slug}@${nbs_sha:0:7} vendors Nim from" >&2
    return 1
  fi

  # NimMajor* {.intdefine.}: int = 2
  read -r major minor patch < <(
    curl -sfL --max-time 20 "https://raw.githubusercontent.com/${nim_slug}/${nim_sha}/lib/system/compilation.nim" \
      | sed -n 's/^[[:space:]]*Nim\(Major\|Minor\|Patch\)\*[^=]*=[[:space:]]*\([0-9]\+\).*/\1 \2/p' \
      | sort | awk '{ v[$1] = $2 } END { print v["Major"], v["Minor"], v["Patch"] }'
  ) || true

  if [ -z "${major:-}" ] || [ -z "${minor:-}" ] || [ -z "${patch:-}" ]; then
    echo "could not read the Nim version from ${nim_slug}@${nim_sha:0:7}" >&2
    return 1
  fi

  echo "${nbs_slug}@${nbs_sha:0:7} pins ${nim_slug}@${nim_sha:0:7} = Nim ${major}.${minor}.${patch}" >&2
  echo "${major}.${minor}.${patch}"
}

# Keep only Nim releases; see the note above.
releases_only() {
  awk -F. '$2 % 2 == 0 && $3 % 2 == 0'
}

CANONICAL_VERSION=$(canonical_version) || CANONICAL_VERSION=""

# `  "nim == 2.2.12",` -> `2.2.12`
NIMBLE_VERSION=""
if [ -f "$NIMBLE" ]; then
  NIMBLE_VERSION=$(grep -oE "\"nim[[:space:]]*==[[:space:]]*${VERSION_RE}\"" "$NIMBLE" \
    | grep -oE "$VERSION_RE" | head -n1) || true
  [ -n "$NIMBLE_VERSION" ] && echo "${NIMBLE} requires Nim ${NIMBLE_VERSION}" >&2
fi

# `  const v = ["2.2.12", "2.2.13"]` -> `2.2.13\n2.2.12` (newest first)
ACCEPTED=""
if [ -f "$CONFIG_NIMS" ]; then
  ACCEPTED=$(sed -n 's/^[[:space:]]*const v = \[\(.*\)\].*/\1/p' "$CONFIG_NIMS" \
    | tr -d ' "' | tr ',' '\n' \
    | grep -E "^${VERSION_RE}$" \
    | sort -Vr) || true

  # Upstream is free to reword that block, so tell "no requirement declared"
  # apart from "declared in a shape we no longer parse" - the latter would
  # otherwise silently build against a compiler its assert rejects.
  if [ -z "$ACCEPTED" ] && grep -q 'requires one of Nim versions' "$CONFIG_NIMS"; then
    echo "${CONFIG_NIMS} declares a Nim version requirement that this script could not parse - the upstream pattern changed, update ./nimbus-eth2/nim-version.sh" >&2
    exit 1
  fi
  [ -n "$ACCEPTED" ] && echo "${CONFIG_NIMS} accepts Nim $(echo "$ACCEPTED" | tr '\n' ' ')" >&2
fi

if [ -n "$CANONICAL_VERSION" ] && [ -n "$NIMBLE_VERSION" ] && [ "$CANONICAL_VERSION" != "$NIMBLE_VERSION" ]; then
  echo "note: ${NIMBLE} says ${NIMBLE_VERSION} but the pinned compiler is ${CANONICAL_VERSION}" >&2
fi

CANDIDATES=$(printf '%s\n%s\n%s\n' "$CANONICAL_VERSION" "$NIMBLE_VERSION" "$ACCEPTED" \
  | grep -E "^${VERSION_RE}$" | awk '!seen[$0]++') || true

if [ -z "$CANDIDATES" ]; then
  echo "no Nim version requirement found, leaving NIM_VERSION at the Dockerfile default" >&2
  exit 0
fi

# config.nims has the final say: its assert aborts the build on anything else.
if [ -n "$ACCEPTED" ]; then
  for version in $CANDIDATES; do
    grep -qxF "$version" <<< "$ACCEPTED" || \
      echo "dropping Nim ${version}: ${CONFIG_NIMS} rejects it" >&2
  done
  CANDIDATES=$(grep -xF -f <(echo "$ACCEPTED") <<< "$CANDIDATES") || CANDIDATES=""
fi

CANDIDATES=$(releases_only <<< "$CANDIDATES") || true

if [ -z "$CANDIDATES" ]; then
  echo "no released Nim version is declared, only devel snapshots" >&2
  exit 1
fi

# Docker Hub answers 404 for a tag that was never pushed - that's authoritative,
# anything else (rate limit, 5xx, timeout) is retried so a flaky request doesn't
# silently downgrade us to an older Nim.
tag_has_arch() {
  local version="$1" attempt response http_code body
  for attempt in 1 2 3; do
    response=$(curl -sL --max-time 20 -w $'\n%{http_code}' \
      "https://hub.docker.com/v2/repositories/nimlang/nim/tags/${version}") || response=""
    http_code=$(tail -n1 <<< "$response")
    body=$(sed '$d' <<< "$response")

    case "$http_code" in
      200) grep -qE "\"architecture\"[[:space:]]*:[[:space:]]*\"${ARCH}\"" <<< "$body"; return $? ;;
      404) return 1 ;;
      *)   echo "docker hub lookup for nimlang/nim:${version} failed (http ${http_code:-none}), retrying" >&2 ;;
    esac
    sleep $((attempt * 5))
  done

  echo "could not determine whether nimlang/nim:${version} exists" >&2
  return 1
}

for version in $CANDIDATES; do
  if tag_has_arch "$version"; then
    echo "using nimlang/nim:${version} (${ARCH})" >&2
    echo "NIM_VERSION=${version}"
    exit 0
  fi
  echo "nimlang/nim:${version} is not published for ${ARCH}, trying the next candidate" >&2
done

echo "none of the declared Nim releases ($(echo "$CANDIDATES" | tr '\n' ' ')) are published as a nimlang/nim image for ${ARCH}" >&2
exit 1
