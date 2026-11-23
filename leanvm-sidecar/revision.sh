#!/bin/bash
set -euo pipefail

SOURCE_DIR="${source_dir:-./source}"
DOCKERFILE="${target_dockerfile:-}"

if [ -z "$DOCKERFILE" ] || ! grep -q '^ARG LEANVM_REV' "$DOCKERFILE" 2>/dev/null; then
  exit 0
fi

revisions=""
if [ -f "${SOURCE_DIR}/leanvm-revision" ]; then
  revisions=$(tr -d '[:space:]' < "${SOURCE_DIR}/leanvm-revision")
else
  for manifest in Cargo.toml beacon_chain/pq/leanxmss_ffi/Cargo.toml; do
    [ -f "${SOURCE_DIR}/${manifest}" ] || continue
    revisions=$(grep -i 'github.com/leanEthereum/leanVM' "${SOURCE_DIR}/${manifest}" \
      | grep -oE "rev = ['\"][0-9a-f]{40}['\"]" | grep -oE '[0-9a-f]{40}' | sort -u) || revisions=""
    [ -z "$revisions" ] || break
  done
fi

if [ -z "$revisions" ]; then
  echo "${SOURCE_DIR} pins no leanVM revision, keeping the default of ${DOCKERFILE}" >&2
  exit 0
fi

if ! grep -qxE '[0-9a-f]{40}' <<< "$revisions"; then
  echo "${SOURCE_DIR} does not pin exactly one leanVM revision: ${revisions//$'\n'/ }" >&2
  exit 1
fi

echo "${SOURCE_DIR} pins leanVM ${revisions}" >&2
echo "LEANVM_REV=${revisions}"
