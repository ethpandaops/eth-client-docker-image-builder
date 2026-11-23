#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
SOURCE_DIR="${source_dir:-./source}"
DOCKERFILE="${target_dockerfile:-}"
TARGET_TAG="${target_tag:-}"
DEVNETS="${leanvm_devnets:-${SCRIPT_DIR}/devnets.yaml}"

if [ -z "$DOCKERFILE" ] || ! grep -q '^ARG LEANVM_REV' "$DOCKERFILE" 2>/dev/null; then
  exit 0
fi

pinned=""
if [ -f "${SOURCE_DIR}/leanvm-revision" ]; then
  pinned=$(tr -d '[:space:]' < "${SOURCE_DIR}/leanvm-revision")
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
while IFS=': ' read -r name rev; do
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || continue
  if [[ "$TARGET_TAG" =~ (^|-)"$name"(-|$) ]] && [ "${#name}" -gt "${#devnet}" ]; then
    devnet="$name"
    revision="$rev"
  fi
done < "$DEVNETS"

if [ -n "$devnet" ]; then
  commit=$(git ls-remote https://github.com/leanEthereum/leanVM "refs/tags/${revision}" 2>/dev/null | cut -f1) || commit=""
  if [ -n "$pinned" ] && [ -n "$commit" ] && [ "$pinned" != "$commit" ]; then
    echo "::warning::${SOURCE_DIR} pins leanVM ${pinned//$'\n'/ }, ${devnet} runs ${revision} (${commit})" >&2
  fi
  echo "${devnet} runs leanVM ${revision}" >&2
else
  revision="$pinned"
  echo "${SOURCE_DIR} pins leanVM ${revision//$'\n'/ }" >&2
fi

if ! [[ "$revision" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "no single leanVM revision for ${TARGET_TAG}: add its devnet to ${DEVNETS} or pin one in the source" >&2
  exit 1
fi

echo "LEANVM_REV=${revision}"
