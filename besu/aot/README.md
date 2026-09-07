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
   publish the file as a GitHub release on `ahamlat/besu`: one `.aot` asset,
   the full besu commit sha in the body, ideally the release tagged
   `aot-<docker tag>`. Their procedure:
   <https://hackmd.io/@8AY4P2cSSJaZliiRSkWAgw/Syoj_xmlGg>.
2. **This repo bakes it.** [`bake-besu-aot.yml`](../../.github/workflows/bake-besu-aot.yml)
   polls that repo hourly and pushes `<devnet>-aot-<sha>` for every published
   cache that has an image to go on and no baked image yet. Nothing to
   trigger, nothing to download by hand. The same workflow can be dispatched
   with the release tag, optionally one `base_tag`, and `force` to re-bake.

`besu/aot/discover.sh` is the poll; `besu/aot/bake.sh` is the bake.

## The cache only fits one image

The JVM validates the cache against every classpath entry by **path, size and
mtime**. Rebuilding besu from the same commit produces jars with the same names
but new mtimes, and the cache is refused:

```
[warning][aot] This file is not the one used while building the shared archive file: '/opt/besu/lib/besu-app-26.9-develop-0d7d0f5.jar', timestamp has changed
[error  ][aot] shared class paths mismatch
Unable to use AOT cache.
```

Three consequences:

- The `-aot-` image is **derived** `FROM` the published image with a single
  `COPY`; it is never rebuilt. The jars stay byte-identical, mtimes included.
- The base must be the **per-commit tag**. `ethpandaops/besu:<devnet>` moves.
- **Do not re-dispatch a build of a ref that already has a cache.** The
  scheduled builder skips shas that already exist on Docker Hub, but a manual
  build of the same ref re-pushes `<devnet>-<sha>` with new mtimes, and from
  then on the recorded cache fits nothing.

## How discovery picks the base image

Because of the above, discovery never guesses which image a cache was recorded
on. For each published release (by the pinned author, one `.aot` asset, a sha
in the body that agrees with any sha in the tag):

1. If the release tag is `aot-<docker tag>` and that tag exists, that is the
   base. **This is the convention to adopt**: `aot-glamsterdam-devnet-8-0d7d0f5`.
2. Otherwise the commit sha must be built under **exactly one**
   `<devnet>-<sha>` tag on Docker Hub. Several (the same commit under
   `main-<sha>` and a devnet tag, say) is ambiguous and is skipped with a hint;
   dispatch with `base_tag` to resolve it by hand.
3. The base must have been pushed **before** the release was published. An
   image newer than the cache cannot be the one it was recorded on.
4. A base whose bake **already failed** is not retried until the asset is
   re-uploaded. The workflow's own run history is the memory, so a cache that
   does not load produces one failure notification, not one per hour.

## What the bake guarantees

Every image that gets pushed has passed, in this order:

- the cache's embedded JVM ident says `linux-amd64` (a cache recorded on
  aarch64 was shipped once; it fails at load time, not build time, without this);
- the base image's `org.opencontainers.image.revision` label equals the sha in
  the tag, so a rolling or mistyped base tag is refused;
- the derived image starts with `-XX:AOTMode=on -Xmx8g` and logs
  `Using AOT-linked classes: true`. `AOTMode=on` makes the JVM exit non-zero on
  any jar/arch/JDK mismatch instead of silently running cold;
- the same start-up test again after `docker push`, from a clean pull.

The image carries `io.ethpandaops.besu.aot=true` and
`io.ethpandaops.besu.aot.commit=<sha>`, and defaults `BESU_OPTS` to the strict
load flags. Consumers may override `BESU_OPTS`; keep `-XX:AOTMode=on`.

## Trust boundary

An AOT cache is pre-linked class metadata and archived heap objects that the
JVM maps and trusts. Whoever can publish a release on the cache repo therefore
controls code that runs inside Besu on the benchmark hosts. The workflow pins
the repo **and** the release author (`AOT_RELEASE_AUTHOR`); a cache from
anywhere else is a local `bake.sh` run with an explicit `AOT_URL`. This is the
same trust already extended to `besu-eth/besu` commits by the image builds,
held by a Besu maintainer's account rather than the org's branch protection.

## Asking for a new cache

When the benchmark lane moves to a new besu commit, the Besu team needs to
record a new cache against `ethpandaops/besu:<devnet>-<sha>`. Checklist, from
things that have gone wrong before:

- **Tag the release `aot-<docker tag>`**, e.g. `aot-glamsterdam-devnet-8-0d7d0f5`.
  Any other tag still works as long as the commit is built under one tag only.
- **Publish it.** A URL containing `untagged-…` is a draft, invisible to
  everyone but the author.
- **x86-64.** The benchmark hosts are amd64.
- **Full commit sha in the body** (a link to the besu commit is fine).
- **One `.aot` asset per release.** Zero or several are ignored. Re-uploading
  the asset on the same release is how to replace a bad cache; the bake
  retries once the asset changes.

## Local usage

```bash
# Dry run: download, check, build, verify, do not push.
BASE_TAG=glamsterdam-devnet-8-0d7d0f5 \
AOT_URL=https://github.com/ahamlat/besu/releases/download/aot-glam-devnet8-0d7d0f5/besu-devnet-8-0d7d0f5.aot \
PUSH=false ./besu/aot/bake.sh

# What the hourly poll would do right now (GH_TOKEN optional, avoids rate limits).
./besu/aot/discover.sh
```

## Caveats

- **amd64 only.** The bake pulls and builds `linux/amd64`; the resulting tag is
  single-arch. There is no `-aot` entry in the multi-arch manifest and no plan
  for one, since the benchmark hosts are amd64 and a cache is per-arch anyway.
- **Not pushed to Harbor.** benchmarkoor pulls from Docker Hub.

## Consumers

`benchmarkoor-tests` runs a `besu-bal-full-aot` twin next to `besu-bal-full`.
Pin both to the same sha (`<devnet>-<sha>` and `<devnet>-aot-<sha>`) and bump
them together, only once the `-aot-` tag exists; otherwise the A/B comparison
is across two different Besu builds.
