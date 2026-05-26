# syntax=docker/dockerfile:1
#
# Besu + Project Leyden AOT cache (benchmarking only).
#
# This is a thin derivative of one specific ethpandaops/besu build. It bakes in
# an AOT cache (besu.aot) that was generated FROM THIS EXACT image, so the JVM
# starts already warmed up instead of paying JIT/C2 warmup during a benchmark.
#
# Why this resolves the "chicken-and-egg":
#   The Leyden AOT cache is validated against the besu classpath/jar, NOT against
#   docker image layers. Because we FROM the precise image the cache was recorded
#   against and only COPY in a data file, the jar is byte-identical and the cache
#   stays valid. Adding the file does not create a "new code version" that would
#   invalidate it.
#
# Built by besu/aot/generate-aot.sh — not intended to be built standalone.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Upstream besu runs as uid 1000 ("besu", WORKDIR /opt/besu).
COPY --chown=besu:besu besu.aot /opt/besu/aot/besu.aot

# Load the cache by default. Consumers may override BESU_OPTS.
# -Xlog:aot=info prints whether the cache loaded — handy in benchmark logs.
ENV BESU_OPTS="-XX:AOTCache=/opt/besu/aot/besu.aot -Xlog:aot=info"

LABEL io.ethpandaops.besu.aot="true"
