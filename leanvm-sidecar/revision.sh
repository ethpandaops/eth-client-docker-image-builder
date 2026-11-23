#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
SOURCE_DIR="${source_dir:-./source}"
DOCKERFILE="${target_dockerfile:-}"
TARGET_TAG="${target_tag:-}"
BRANCHES="${leanvm_branches:-${SCRIPT_DIR}/../branches.yaml}"

if [ -z "$DOCKERFILE" ] || ! grep -q '^ARG LEANVM_REV' "$DOCKERFILE" 2>/dev/null; then
  exit 0
fi

pinned=""
if [ -f "${SOURCE_DIR}/leanvm-revision" ]; then
  pinned=$(tr -d '[:blank:]\r' < "${SOURCE_DIR}/leanvm-revision" | sed '/^$/d' | sort -u)
else
  for manifest in Cargo.toml beacon_chain/pq/leanxmss_ffi/Cargo.toml; do
    [ -f "${SOURCE_DIR}/${manifest}" ] || continue
    pinned=$(grep -i 'github.com/leanEthereum/leanVM' "${SOURCE_DIR}/${manifest}" \
      | grep -oE "rev = ['\"][0-9a-f]{40}['\"]" | grep -oE '[0-9a-f]{40}' | sort -u) || pinned=""
    [ -z "$pinned" ] || break
  done
fi

devnet=""
revision=""
while read -r name rev; do
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || continue
  if [[ "$TARGET_TAG" =~ (^|-)"$name"(-|$) ]] && [ "${#name}" -gt "${#devnet}" ]; then
    devnet="$name"
    revision="$rev"
  fi
done < <(awk '
  function indent(line) { match(line, /^ */); return RLENGTH }
  /^[[:space:]]*(#|$)/ { next }
  { depth = indent($0) }
  section == 2 && depth <= devnets_depth { section = (depth > client_depth) ? 1 : 0 }
  section == 1 && depth <= client_depth { section = 0 }
  section == 0 && /^ *leanvm-sidecar:[[:space:]]*$/ { section = 1; client_depth = depth; next }
  section == 1 && /^ *devnets:[[:space:]]*$/ { section = 2; devnets_depth = depth; next }
  section == 2 {
    line = $0
    sub(/[[:space:]]+#.*$/, "", line)
    gsub(/[[:space:]"\047]/, "", line)
    split(line, pair, ":")
    print pair[1], pair[2]
  }
' "$BRANCHES")

if [ -n "$devnet" ]; then
  commit=$(git ls-remote https://github.com/leanEthereum/leanVM "refs/tags/${revision}" 2>/dev/null | cut -f1) || commit=""
  if [ -n "$pinned" ] && [ -n "$commit" ] && [ "$pinned" != "$commit" ]; then
    echo "::warning::${SOURCE_DIR} pins leanVM ${pinned//$'\n'/ }, ${devnet} runs ${revision} (${commit})" >&2
  fi
  echo "${devnet} runs leanVM ${revision}" >&2
else
  if [ -n "$pinned" ] && ! [[ "$pinned" =~ ^[0-9a-f]{40}$ ]]; then
    echo "${SOURCE_DIR} does not pin exactly one leanVM commit: ${pinned//$'\n'/ }" >&2
    exit 1
  fi
  revision="$pinned"
  echo "${SOURCE_DIR} pins leanVM ${revision}" >&2
fi

if ! [[ "$revision" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "no single leanVM revision for ${TARGET_TAG}: add its devnet under leanvm-sidecar in branches.yaml or pin one in the source" >&2
  exit 1
fi

echo "LEANVM_REV=${revision}"
