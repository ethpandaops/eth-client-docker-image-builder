#! /bin/bash
#
# Prints the NIM_VERSION docker build arg for a nimbus-eth2 build, on stdout.
#
# nimbus-eth2 declares the exact Nim versions it accepts in config.nims:
#
#   const v = ["2.2.12", "2.2.13"]
#   doAssert [$NimMajor, $NimMinor, $NimPatch].join(".") in v,
#     "nimbus-eth2 requires one of Nim versions " & $v
#
# and fails the build loudly on anything else, so a version hardcoded in our
# Dockerfiles breaks on every upstream Nim bump. Print the newest accepted
# version that is actually published as a nimlang/nim image for the platform
# we're building for (unstable currently accepts 2.2.13, which has no image yet).
#
# Refs that don't declare a requirement (stable and column-syncer at the time of
# writing) print nothing, leaving the Dockerfile's default in place.

set -euo pipefail

CONFIG_NIMS="${config_nims:-./source/config.nims}"
PLATFORM="${platform:-linux/amd64}"
ARCH="${PLATFORM##*/}"

if [ ! -f "$CONFIG_NIMS" ]; then
  echo "${CONFIG_NIMS} not found, leaving NIM_VERSION at the Dockerfile default" >&2
  exit 0
fi

# `  const v = ["2.2.12", "2.2.13"]` -> `2.2.13\n2.2.12` (newest first)
VERSIONS=$(sed -n 's/^[[:space:]]*const v = \[\(.*\)\].*/\1/p' "$CONFIG_NIMS" \
  | tr -d ' "' | tr ',' '\n' \
  | grep -E '^[0-9]+(\.[0-9]+){2}$' \
  | sort -Vr) || true

if [ -z "$VERSIONS" ]; then
  echo "no Nim version requirement found in ${CONFIG_NIMS}, leaving NIM_VERSION at the Dockerfile default" >&2
  exit 0
fi

echo "${CONFIG_NIMS} accepts Nim $(echo "$VERSIONS" | tr '\n' ' ')" >&2

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

for version in $VERSIONS; do
  if tag_has_arch "$version"; then
    echo "using nimlang/nim:${version} (${ARCH})" >&2
    echo "NIM_VERSION=${version}"
    exit 0
  fi
  echo "nimlang/nim:${version} is not published for ${ARCH}, trying next" >&2
done

echo "none of the Nim versions accepted by ${CONFIG_NIMS} are published as a nimlang/nim image for ${ARCH}" >&2
exit 1
