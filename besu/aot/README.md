# Besu AOT-cache image (benchmarking)

Produces `ethpandaops/besu:<devnet>-aot-<sha>`: an already-published
`ethpandaops/besu:<devnet>-<sha>` plus a baked-in
[Project Leyden](https://openjdk.org/projects/leyden/) AOT cache, so the JVM
starts pre-warmed instead of paying JIT/C2 warmup during a benchmark run.

This exists because in benchmarkoor Besu is otherwise penalised for JVM warmup
versus native clients. The goal is to put Besu, at startup, at the warmup point
a long-running node would be at. **Benchmarking only — not a mainnet
recommendation.** First measurement by the Besu team on bal-devnet-7: first
block `32.9 → 159.5 Mgas/s`, warm block `154.7 → 233.8 Mgas/s`.

## Who does what

The cache is only useful if the training run is representative, which for Besu
means the exact image running on the target devnet for a few hours with real
load. That cannot happen on a CI runner, so the process has two owners:

1. **Besu team records the cache.** They run `ethpandaops/besu:<devnet>-<sha>`
   on an x86-64 devnet node with `-XX:AOTCacheOutput=…` for a few hours, then
   publish the file as a GitHub release on `ahamlat/besu`:
   one `.aot` asset, and the full besu commit sha in the release body.
   Their procedure: <https://hackmd.io/@8AY4P2cSSJaZliiRSkWAgw/Syoj_xmlGg>.
2. **This repo bakes it.** [`bake-besu-aot.yml`](../../.github/workflows/bake-besu-aot.yml)
   polls that repo hourly and, for every published cache, finds each
   `ethpandaops/besu:<devnet>-<sha>` tag built from that commit and pushes
   `<devnet>-aot-<sha>` if it does not exist yet. Nothing to trigger, nothing
   to download by hand. The same workflow can be dispatched manually with the
   release tag (and optionally one base tag, or `force` to re-bake).

`besu/aot/discover.sh` is the poll; `besu/aot/bake.sh` is the bake.

## What the bake guarantees

Every image that gets pushed has passed, in this order:

- the cache's embedded JVM ident says `linux-amd64` (a cache recorded on
  aarch64 was shipped once; it fails at load time, not build time, without this);
- the base image's `org.opencontainers.image.revision` label equals the sha in
  the tag, so a rolling or mistyped base tag is refused;
- the derived image starts with `-XX:AOTMode=on` and logs
  `Using AOT-linked classes: true`. `AOTMode=on` makes the JVM exit non-zero on
  any jar/arch/JDK mismatch instead of silently running cold;
- the same start-up test again after `docker push`, from a clean pull.

The image carries `io.ethpandaops.besu.aot=true` and
`io.ethpandaops.besu.aot.commit=<sha>`, and defaults `BESU_OPTS` to the strict
load flags. Consumers may override `BESU_OPTS`; keep `-XX:AOTMode=on`.

## Why derive instead of rebuild

The JVM validates the cache against the besu classpath. The jar names carry the
build version (`besu-app-26.9-develop-0d7d0f5.jar`), so rebuilding besu, even
from the same commit, would produce a classpath the cache does not match.
Deriving `FROM` the published image and only `COPY`ing a data file keeps the
jars byte-identical, and the cache stays valid. That is also why the base must
be the per-commit tag: `ethpandaops/besu:<devnet>` moves with the branch.

## Asking for a new cache

When the benchmark lane moves to a new besu commit, the Besu team needs to
record a new cache against `ethpandaops/besu:<devnet>-<sha>`. Things that have
gone wrong before, worth a checklist:

- **Publish the release.** A URL containing `untagged-…` is a draft and is
  invisible to everyone but the author.
- **x86-64.** The benchmark hosts are amd64.
- **Full commit sha in the release body** (a link to the besu commit is fine).
  The devnet name is discovered from Docker Hub, so the release tag can be
  anything.
- **One `.aot` asset per release.** Releases with zero or several are ignored.

## Local usage

```bash
# Dry run: download, check, build, verify, do not push.
BASE_TAG=glamsterdam-devnet-8-0d7d0f5 \
AOT_URL=https://github.com/ahamlat/besu/releases/download/aot-glam-devnet8-0d7d0f5/besu-devnet-8-0d7d0f5.aot \
PUSH=false ./besu/aot/bake.sh

# What the hourly poll would do right now.
./besu/aot/discover.sh
```

## Caveats

- **amd64 only.** The bake pulls and builds `linux/amd64`; the resulting tag is
  single-arch. There is no `-aot` entry in the multi-arch manifest and no plan
  for one, since the benchmark hosts are amd64 and a cache is per-arch anyway.
- **Not pushed to Harbor.** benchmarkoor pulls from Docker Hub.
- **Cache source is pinned** to `AOT_RELEASE_REPO` in the workflow. A cache
  from anywhere else is a local `bake.sh` run with an explicit `AOT_URL`.

## Consumers

`benchmarkoor-tests` runs a `besu-bal-full-aot` twin next to `besu-bal-full`.
Pin both to the same sha (`<devnet>-<sha>` and `<devnet>-aot-<sha>`) and bump
them together, only once the `-aot-` tag exists; otherwise the A/B comparison
is across two different Besu builds.
