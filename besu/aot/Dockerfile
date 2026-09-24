# syntax=docker/dockerfile:1
#
# Besu + Project Leyden AOT cache (benchmarking only).
#
# Thin derivative of one specific ethpandaops/besu build. It bakes in an AOT
# cache (besu.aot) that the Besu team recorded against THIS EXACT image, so the
# JVM starts already warmed up instead of paying JIT/C2 warmup in a benchmark.
#
# The JVM validates the cache against the besu classpath (jar names carry the
# build version, e.g. besu-app-26.9-develop-0d7d0f5.jar), not against image
# layers. Rebuilding besu would produce new jars and invalidate the cache;
# deriving FROM the already-published image and only COPYing a data file keeps
# the jars byte-identical.
#
# Built by besu/aot/bake.sh — not intended to be built standalone.
ARG BASE_IMAGE=ethpandaops/besu:unset
FROM ${BASE_IMAGE}
ARG AOT_COMMIT

# Upstream besu runs as uid 1000 ("besu", WORKDIR /opt/besu).
COPY --chown=besu:besu besu.aot /opt/besu/aot/besu.aot

# AOTMode=on: refuse to start if the cache cannot be mapped. Without it the JVM
# silently falls back to a cold run (exit 0), which in a benchmark publishes
# results labelled "aot" that got no AOT benefit. Consumers may override.
ENV BESU_OPTS="-XX:AOTCache=/opt/besu/aot/besu.aot -XX:AOTMode=on -Xlog:aot=info"

LABEL io.ethpandaops.besu.aot="true"
LABEL io.ethpandaops.besu.aot.commit="${AOT_COMMIT}"
