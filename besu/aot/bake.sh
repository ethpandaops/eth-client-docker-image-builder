#!/usr/bin/env bash
#
# Bake a Besu-team AOT cache into the ethpandaops/besu image it was recorded
# against, prove the JVM maps it, and push <devnet>-aot-<sha>.
#
# Inputs (env):
#   BASE_TAG           REQUIRED. Per-commit base tag, e.g. glamsterdam-devnet-8-0d7d0f5.
#                      Never a rolling tag: the cache is only valid for the exact
#                      jars it was recorded against, and a rolling tag moves.
#   AOT_URL            REQUIRED. URL of the .aot file (a GitHub release asset).
#   target_repository  Docker Hub repository. Default ethpandaops/besu.
#   PUSH               Push the result. Default true; false = build + verify only.
set -euo pipefail

: "${BASE_TAG:?BASE_TAG must be set, e.g. glamsterdam-devnet-8-0d7d0f5}"
: "${AOT_URL:?AOT_URL must be set}"
target_repository="${target_repository:-ethpandaops/besu}"
PUSH="${PUSH:-true}"

[[ "${BASE_TAG}" =~ ^(.+)-([0-9a-f]{7})$ ]] || { echo "BASE_TAG must be <devnet>-<7-hex sha>, got: ${BASE_TAG}" >&2; exit 1; }
devnet="${BASH_REMATCH[1]}"
sha="${BASH_REMATCH[2]}"
base="${target_repository}:${BASE_TAG}"
out="${target_repository}:${devnet}-aot-${sha}"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ctx="$(mktemp -d)"
trap 'rm -rf "${ctx}"' EXIT

echo "==> Downloading ${AOT_URL}"
curl -fsSL --retry 3 --retry-delay 5 -o "${ctx}/besu.aot" "${AOT_URL}"
ls -la "${ctx}/besu.aot"

# A cache only loads on the CPU arch + JDK it was recorded on; the JVM ident is
# embedded in the file. Benchmark hosts are amd64, and we once shipped an
# aarch64 cache by accident, so check before spending a build on it.
echo "==> Checking cache arch"
ident=$(grep -a -o -m1 -E 'OpenJDK 64-Bit Server VM \([^)]*\) for linux-[a-z0-9_]+' "${ctx}/besu.aot" || true)
[ -n "${ident}" ] || { echo "No JVM ident found in the file; not an AOT cache?" >&2; exit 1; }
echo "    ${ident}"
case "${ident}" in
  *linux-amd64) ;;
  *) echo "Cache is not linux-amd64; refusing to bake" >&2; exit 1 ;;
esac

echo "==> Pulling ${base}"
docker pull --platform linux/amd64 "${base}" >/dev/null
revision=$(docker inspect "${base}" --format '{{index .Config.Labels "org.opencontainers.image.revision"}}')
[ "${revision}" = "${sha}" ] || { echo "${base} is built from '${revision}', not ${sha}; wrong base tag" >&2; exit 1; }

echo "==> Building ${out}"
cp "${SCRIPT_DIR}/Dockerfile" "${ctx}/Dockerfile"
docker build -q --platform linux/amd64 \
  --build-arg "BASE_IMAGE=${base}" --build-arg "AOT_COMMIT=${sha}" \
  -t "${out}" "${ctx}"

# Strict load test. AOTMode=on makes the JVM exit non-zero on any jar/arch/JDK
# mismatch instead of silently running cold, and the log line proves the
# archived classes were actually linked. -Xmx8g is the benchmark heap ceiling;
# it only reserves address space here, so it is fine on a small runner.
verify() {
  local image="$1" log
  if ! log=$(docker run --rm --platform linux/amd64 --entrypoint /opt/besu/bin/besu \
      -e BESU_OPTS="-Xmx8g -XX:AOTCache=/opt/besu/aot/besu.aot -XX:AOTMode=on -Xlog:aot=info" \
      "${image}" --version 2>&1); then
    echo "${log}" | tail -n 20 >&2
    echo "AOT cache failed to load in ${image}" >&2
    return 1
  fi
  if ! grep -q "Using AOT-linked classes: true" <<<"${log}"; then
    echo "${log}" | tail -n 20 >&2
    echo "JVM started but did not link classes from the cache" >&2
    return 1
  fi
  grep -E "Using AOT-linked classes|besu/v" <<<"${log}" | sed 's/^/    /'
}
echo "==> Verifying local build"
verify "${out}"

if [ "${PUSH}" != "true" ]; then
  echo "==> PUSH=${PUSH}; built and verified ${out}, not pushing"
  exit 0
fi

echo "==> Pushing ${out}"
docker push "${out}" | tail -n 1

echo "==> Verifying from the registry"
docker rmi "${out}" >/dev/null
docker pull --platform linux/amd64 "${out}" >/dev/null
docker inspect "${out}" --format '    arch={{.Architecture}} aot={{index .Config.Labels "io.ethpandaops.besu.aot"}} commit={{index .Config.Labels "io.ethpandaops.besu.aot.commit"}} revision={{index .Config.Labels "org.opencontainers.image.revision"}}'
verify "${out}"
echo "==> Done: ${out}"
