#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

"${SCRIPT_DIR}/nim-version.sh"
"${SCRIPT_DIR}/../leanvm-sidecar/revision.sh"
