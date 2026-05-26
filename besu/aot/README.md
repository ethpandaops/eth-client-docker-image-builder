# Besu AOT-cache image (benchmarking)

Produces `ethpandaops/besu:<tag>-aot`: the normal besu build plus a baked-in
[Project Leyden](https://openjdk.org/projects/leyden/) AOT cache, so the JVM
starts pre-warmed instead of paying JIT/C2 warmup during a benchmark run.

This exists because in benchmarkoor Besu is otherwise penalised for JVM warmup
versus native clients (reth/geth). The goal is to put Besu, at startup, at the
same warmup point a long-running mainnet node would be at. **This is for
benchmarking only — not a mainnet recommendation.**

Measured by the Besu team on bal-devnet-7 (a 109 MiB cache from a short run):
first block `32.9 → 159.5 Mgas/s`, warm block `154.7 → 233.8 Mgas/s`.

## How it works

1. `besu/build.sh` builds and pushes the normal image as today.
2. When `BESU_BUILD_AOT=true`, it then calls `besu/aot/generate-aot.sh`, which:
   - runs a container from the **just-built image** with
     `BESU_OPTS=-XX:AOTCacheOutput=/aot/besu.aot` against a finite training
     workload (default: `besu blocks import`). On normal JVM exit the cache is
     written.
   - builds `besu/aot/Dockerfile` — `FROM` that exact image — copying the cache
     to `/opt/besu/aot/besu.aot` and defaulting
     `BESU_OPTS=-XX:AOTCache=/opt/besu/aot/besu.aot`.
   - pushes `<tag>-aot` (and the commit-pinned `<tag>-<sha>-aot`).

### The chicken-and-egg, resolved

The Besu team's concern was that baking the cache into a new image creates a new
"version" that invalidates the cache. It does not: the Leyden cache is validated
against the **besu classpath/jar**, not against docker layers. Because the
derivative `FROM`s the precise image the cache was recorded against and only adds
a data file, the jar is byte-identical and the cache stays valid. Generation and
shipping use the same jar, so there is no version skew.

## Caveats

- **Arch- and JDK-specific.** A cache is valid only for the CPU arch and JDK it
  was recorded on. `generate-aot.sh` runs on the same per-platform CI runner as
  the base build, so the arch matches. The multi-arch `manifest` job does **not**
  currently stitch an `-aot` manifest — for now treat `<tag>-aot` as
  per-platform (benchmarks run on amd64). Stitching can be added later if needed.
- **Training corpus is a real choice.** The cache only warms paths the workload
  exercises. For bal-devnet-7 benchmarking, train on blocks representative of the
  benchmark suites. Supply them via `BESU_AOT_BLOCKS` + `BESU_AOT_GENESIS`, or
  take full control with `BESU_AOT_TRAIN_CMD`. With no training input the script
  fails fast rather than shipping a useless cache.

## Local usage

```bash
export target_repository=ethpandaops/besu
export target_tag=bal-devnet-7
export BESU_AOT_BLOCKS=/path/to/bal-devnet-7-blocks.rlp
export BESU_AOT_GENESIS=/path/to/bal-devnet-7-genesis.json
BESU_BUILD_AOT=true ./besu/build.sh   # or call besu/aot/generate-aot.sh directly
```

To validate without publishing, build against an already-pulled base image and
skip the push:

```bash
target_repository=ethpandaops/besu target_tag=bal-devnet-7 \
  BESU_AOT_PUSH=false BESU_AOT_TRAIN_CMD="--version" \
  ./besu/aot/generate-aot.sh
```

Consumed in `benchmarkoor-tests` via a `besu-bal-*-aot` instance that points
`image:` at `ethpandaops/besu:bal-devnet-7-aot`.
