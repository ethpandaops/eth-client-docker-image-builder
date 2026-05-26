#!/usr/bin/env bash
#
# Generate a Project Leyden AOT cache for a freshly-built besu image and bake it
# into a derivative `<tag>-aot` image.
#
# Opt-in: called from besu/build.sh only when BESU_BUILD_AOT=true.
#
# The cache is recorded with the JDK 25 single-step flow (JEP 514/515):
#   BESU_OPTS=-XX:AOTCacheOutput=/aot/besu.aot
# Besu runs a finite, representative workload (default: `besu blocks import`)
# and the JVM writes the cache when it exits normally. Block import is finite
# and exits 0, so no graceful-stop dance is needed.
#
# IMPORTANT: an AOT cache is specific to BOTH the besu jar AND the CPU arch +
# JDK. The base image we FROM guarantees the jar; running on the same-platform
# CI runner guarantees the arch. Do not reuse a cache across platforms.
#
# Inputs (env), most provided by build.sh / CI:
#   target_repository        e.g. ethpandaops/besu
#   target_tag               e.g. bal-devnet-7-amd64  (per-platform tag)
#   source_git_commit_hash   commit of the besu source (for the pinned tag)
#   BESU_AOT_BLOCKS          REQUIRED unless BESU_AOT_TRAIN_CMD is set: host path
#                            to an RLP block file, mounted at /training/blocks.rlp.
#   BESU_AOT_GENESIS         REQUIRED with BESU_AOT_BLOCKS: genesis.json matching
#                            those blocks, mounted at /training/genesis.json.
#   BESU_AOT_TRAIN_CMD       Override the besu args that drive training. When set,
#                            BESU_AOT_BLOCKS/GENESIS are not required and no
#                            training volumes are mounted (you manage data).
#   BESU_AOT_TIMEOUT         Hard cap (seconds) on the training run. Default 1800.
#   BESU_AOT_PUSH            Push the resulting image(s). Default true. Set to
#                            false for local validation (build only, no push).
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${target_repository:?target_repository must be set (see besu/build.sh)}"
: "${target_tag:?target_tag must be set (see besu/build.sh)}"
BESU_AOT_TIMEOUT="${BESU_AOT_TIMEOUT:-1800}"

base="${target_repository}:${target_tag}"
aot_dir="$(mktemp -d)"
trap 'rm -rf "${aot_dir}"' EXIT

echo "==> Generating AOT cache from ${base}"

# Assemble the training run. -XX:AOTCacheOutput makes the JVM dump the cache to
# /aot/besu.aot on normal exit.
train_env=( -e "BESU_OPTS=-XX:AOTCacheOutput=/aot/besu.aot -Xlog:aot=info" )
train_mounts=( -v "${aot_dir}:/aot" )

if [ -n "${BESU_AOT_TRAIN_CMD:-}" ]; then
    # Caller fully controls the besu invocation.
    read -r -a train_cmd <<< "${BESU_AOT_TRAIN_CMD}"
else
    : "${BESU_AOT_BLOCKS:?set BESU_AOT_BLOCKS (RLP block file) or BESU_AOT_TRAIN_CMD}"
    : "${BESU_AOT_GENESIS:?set BESU_AOT_GENESIS (genesis.json) or BESU_AOT_TRAIN_CMD}"
    [ -f "${BESU_AOT_BLOCKS}" ]  || { echo "BESU_AOT_BLOCKS not found: ${BESU_AOT_BLOCKS}";  exit 1; }
    [ -f "${BESU_AOT_GENESIS}" ] || { echo "BESU_AOT_GENESIS not found: ${BESU_AOT_GENESIS}"; exit 1; }
    train_mounts+=(
        -v "${BESU_AOT_BLOCKS}:/training/blocks.rlp:ro"
        -v "${BESU_AOT_GENESIS}:/training/genesis.json:ro"
    )
    train_cmd=(
        --data-path=/tmp/besu-aot
        --genesis-file=/training/genesis.json
        blocks import --from=/training/blocks.rlp
    )
fi

echo "==> Training: besu ${train_cmd[*]}"
timeout "${BESU_AOT_TIMEOUT}" docker run --rm \
    "${train_env[@]}" \
    "${train_mounts[@]}" \
    --entrypoint besu \
    "${base}" \
    "${train_cmd[@]}"

if [ ! -s "${aot_dir}/besu.aot" ]; then
    echo "Error: AOT cache was not produced at ${aot_dir}/besu.aot" >&2
    echo "       Check the -Xlog:aot=info output above; the JVM must exit normally." >&2
    exit 1
fi
echo "==> AOT cache: $(du -h "${aot_dir}/besu.aot" | cut -f1)"

# Bake it into the derivative image (build context = besu/aot).
cp "${aot_dir}/besu.aot" "${SCRIPT_DIR}/besu.aot"
trap 'rm -rf "${aot_dir}"; rm -f "${SCRIPT_DIR}/besu.aot"' EXIT

aot_tag="${base}-aot"
echo "==> Building ${aot_tag}"
docker build \
    --build-arg "BASE_IMAGE=${base}" \
    -t "${aot_tag}" \
    -f "${SCRIPT_DIR}/Dockerfile" \
    "${SCRIPT_DIR}"

if [ "${BESU_AOT_PUSH:-true}" != "true" ]; then
    echo "==> BESU_AOT_PUSH=${BESU_AOT_PUSH}; built ${aot_tag} but skipping push"
    exit 0
fi

docker push "${aot_tag}"

# Commit-pinned tag, mirroring build.sh's convention.
if [ -n "${source_git_commit_hash:-}" ]; then
    pinned="${target_repository}:${target_tag}-${source_git_commit_hash}-aot"
    docker tag "${aot_tag}" "${pinned}"
    docker push "${pinned}"
fi

echo "==> Done: ${aot_tag}"
