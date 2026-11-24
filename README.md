# eth-client-docker-image-builder

Automates docker builds for ethereum clients. The build process is scheduled every hour to check source repositories for new commits.

## Publishing

Images are pushed to `ghcr.io/ethpandaops/<image>` with the workflow's own `GITHUB_TOKEN`. Each job then attests what it pushed and asks the [image mirror](https://github.com/ethpandaops/image-mirror) to copy it to `docker.io/ethpandaops/<image>` (see [`.github/actions/mirror`](./.github/actions/mirror/action.yml)); the job only succeeds once the tags are on Docker Hub. Image names and tags are the same in both registries. Nothing here holds a Docker Hub credential.

Each per-platform job attests the image it built on its runner; the manifest job attests only the multi-platform index it makes from them.

## Build image on demand

Run the *Build **client*** workflow;
- [Build Besu](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-besu.yml) [[source](https://github.com/besu-eth/besu)]
- [Build Dummy-EL](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-dummy-el.yml) [[source](https://github.com/ethpandaops/dummy-el)]
- [Build Eleel](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-eleel.yml) [[source](https://github.com/sigp/eleel)]
- [Build Erigon](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-erigon.yml) [[source](https://github.com/ledgerwatch/erigon)]
- [Build Ethlambda](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-ethlambda.yml) [[source](https://github.com/lambdaclass/ethlambda)]
- [Build Ethrex](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-ethrex.yml) [[source](https://github.com/lambdaclass/ethrex)]
- [Build Geth](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-geth.yml) [[source](https://github.com/ethereum/go-ethereum)]
- [Build Lighthouse](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-lighthouse.yml) [[source](https://github.com/sigp/lighthouse)]
- [Build Lodestar](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-lodestar.yml) [[source](https://github.com/chainsafe/lodestar)]
- [Build Nethermind](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-nethermin.yml) [[source](https://github.com/nethermindeth/nethermind)]
- [Build Nimbus-Eth2](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-nimbus-eth2.yml) [[source](https://github.com/status-im/nimbus-eth2)]
- [Build Nimbus-Eth1](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-nimbus-eth1.yml) [[source](https://github.com/status-im/nimbus-eth1)]
- [Build Prysm](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-prysm.yml) [[source](https://github.com/offchainlabs/prysm)]
- [Build Reth](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-reth.yml) [[source](https://github.com/paradigmxyz/reth)]
- [Build Silver](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-silver.yml) [[source](https://github.com/gattaca-com/silver)]
- [Build Teku](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-teku.yml) [[source](https://github.com/consensys-incorporated/teku)]
- [Build Grandine](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-grandine.yml) [[source](https://github.com/grandinetech/grandine)]
- [Build Zeam](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-zeam.yml) [[source](https://github.com/blockblaz/zeam)]
- [Build Ream](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-ream.yml) [[source](https://github.com/ReamLabs/ream)]
- [Build Consensoor](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-consensoor.yml) [[source](https://github.com/ethpandaops/consensoor)]

Run the *Build **tooling*** workflow;
- [Build leanVM sidecar](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-leanvm-sidecar.yml) [[source](https://github.com/leanEthereum/leanVM)]
- [Build Eth-DAS-Guardian](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-eth-das-guardian.yml) [[source](https://github.com/probe-lab/eth-das-guardian)]
- [Build Flashbots Builder](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-flashbots-builder.yml) [[source](https://github.com/flashbots/builder)]
- [Build tx-fuzz](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-tx-fuzz.yaml) [[source](https://github.com/MariusVanDerWijden/tx-fuzz)]
- [Build consesnus-monitor](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/.github/workflows/build-push-consensus-monitor.yml) [[source](https://github.com/ralexstokes/ethereum_consensus_monitor)]
- [Build execution-monitor](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/.github/workflows/build-push-execution-monitor.yml) [[source](https://github.com/ethereum/nodemonitor)]
- [Build beacon-metrics-gazer](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/.github/workflows/build-push-beacon-metrics-gazer.yml) [[source](https://github.com/dapplion/beacon-metrics-gazer)]
- [Build ethereum-genesis-generator](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-genesis-generator.yml) [[source](https://github.com/ethpandaops/ethereum-genesis-generator)]
- [Build mev-rs](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-mev-rs.yml) [[source](https://github.com/ralexstokes/mev-rs)]
- [Build reth-rbuilder](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-reth-rbuilder.yml) [[source](https://github.com/flashbots/rbuilder)]
- [Build Syncoor](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-syncoor.yml) [[source](https://github.com/ethpandaops/syncoor)]
- [Build ere-server-zisk](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-ere-server-zisk.yml) [[source](https://github.com/eth-act/ere)]
- [Build TrueBlocks](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-trueblocks.yml) [[source](https://github.com/TrueBlocks/trueblocks-core)]

## Adding a new image to build on schedule

A new image name also has to be added to the image-mirror allowlist before it can reach Docker Hub; see [AGENTS.md](./AGENTS.md#adding-a-new-image) for the full checklist.

Add a new image to [`config.yaml`](./config.yaml) file and it will be built on schedule from [this workflow](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/.github/workflows/scheduled.yml).

```yaml
- source:
    repository: sigp/lighthouse # source repository to build from
    ref: stable # source repository branch/tag/commit to build from
  build_script: ./teku/build.sh # optional build script to run INSTEAD of the docker build & push (see below)
  target:
    tag: stable # tag to add to the docker image tag, this must be unique for each image
    repository: ethpandaops/lighthouse # image to publish, pushed to ghcr.io/ethpandaops/lighthouse and mirrored to Docker Hub
    dockerfile: ./lighthouse/Dockerfile # optional docker file to use, defaults to the source repository's Dockerfile
```

## `branches.yaml` syntax

`config.yaml` is generated from `branches.yaml` by `generate_config.py`. Each client lists branches that should be built; the branch name is used directly as the docker tag (slashes become hyphens).

To build from one branch but publish under a different tag, use `<branch>:<tag>`:

```yaml
teku:
  branches:
    - master
    - prototype/focil:focil   # builds prototype/focil, publishes as :focil
```

The same syntax works inside `alt_repos` entries (the alt-repo prefix is still prepended to the override tag).

After editing `branches.yaml`, run `python3 generate_config.py` to regenerate `config.yaml`.

## Per-tag Dockerfile convention

When a build needs a different Dockerfile than the default (e.g. an alt-fork branch that doesn't work with the upstream one), drop it in alongside the default using the naming convention:

```
./<client>/Dockerfile.<target_tag>
```

Both paths apply this convention automatically:

1. **Scheduled builds** (via `config.yaml` → `generate_config.py`): when a per-tag file exists, `get_dockerfile_path()` picks it up and writes `target.dockerfile` into `config.yaml`.
2. **Manual `workflow_dispatch`** (via the shared `deploy` composite action): at build time, if `basename(target_dockerfile)` is `Dockerfile` or `Dockerfile.minimal` and `./<client>/Dockerfile.<resolved-tag>` exists, the per-tag file is used; otherwise the default `./<client>/Dockerfile` is used.

Example: dispatching `build-push-lighthouse.yml` with `repository=eth-act/lighthouse` and `ref=optional-proofs` resolves the tag to `eth-act-optional-proofs` and automatically picks up `./lighthouse/Dockerfile.eth-act-optional-proofs` if it exists. No workflow changes required to add a new per-tag Dockerfile.

The convention is skipped when the workflow explicitly passes another non-default Dockerfile (e.g. prysm's `Dockerfile.validator`, nimbus-eth2's `Dockerfile.beacon-minimal`), so sub-component builds are unaffected.

Prysm beacon builds use `./prysm/Dockerfile.beacon-<target_tag>` when it exists (e.g. `Dockerfile.beacon-pq-devnet-0`), for both the default and the `-minimal` image. A manual `build-push-prysm.yml` dispatch also uses it when the target tag starts with `<target_tag>-`, the longest match winning, so a fork of such a branch builds with `--tag pq-devnet-0-<name>`.

Scheduled nimbus builds use `./nimbus-eth2/Dockerfile.<beacon|validator>-<target_tag>` when it exists (e.g. `Dockerfile.beacon-pq-devnet-0`). The `-minimal` tag shares that file and is built with `PRESET=minimal`.

A manual `build-push-nimbus-eth2.yml` dispatch uses `./nimbus-eth2/Dockerfile.beacon-<tag>` for both beacon images when the target tag is `<tag>` or starts with `<tag>-`, the longest match winning, so a fork of such a branch builds with `--tag pq-devnet-0-<name>`.

Branches listed under `skip_validator_client` of the `nimbus` entry in `branches.yaml` are built as `nimbus-eth2` only, without the `nimbus-validator-client` images.

To publish an unprefixed tag from a fork, add a `custom_configs` entry with a `repository`; it replaces the entry a branch of the same tag would generate:

```yaml
silver:
  custom_configs:
    - name: "pq-devnet-0"
      repository: "gattaca-com/pq-silver"
      ref: "pq-devnet-0"
      tag: "pq-devnet-0"
```

## leanVM sidecar

PQ consensus clients prove and verify through a `leanvm-sidecar` process, and every client of a network has to run the same leanVM revision. `ethpandaops/leanvm-sidecar:<leanVM release tag>` (e.g. `bindings-v0.15.0`, or a full commit SHA for an untagged revision) holds the sidecar built once per revision: one binary per CPU profile (`generic`, `portable`, `avx2`, `avx2-gfni`, `avx512` on amd64, `portable` on arm64) under `/usr/local/lib/leanvm-sidecar`, `/usr/local/bin/leanvm-sidecar` which runs the fastest one the host supports (`LEANVM_CPU_PROFILE` forces one), and `/usr/local/bin/leanvm-sidecar-run <socket-flag> <command> [args]` which starts the sidecar and then the command with the socket.

The PQ Dockerfiles in this repository copy the sidecar from that image:

```dockerfile
ARG LEANVM_REV
FROM ghcr.io/ethpandaops/leanvm-sidecar:${LEANVM_REV} AS sidecar
...
COPY --from=sidecar /usr/local/bin/leanvm-sidecar /usr/local/bin/leanvm-sidecar
COPY --from=sidecar /usr/local/lib/leanvm-sidecar /usr/local/lib/leanvm-sidecar
```

`./leanvm-sidecar/revision.sh` sets `LEANVM_REV` for a build. The `devnets` map of the `leanvm-sidecar` entry in [`branches.yaml`](./branches.yaml) gives a devnet the one leanVM release all its images run:

```yaml
leanvm-sidecar:
  devnets:
    pq-devnet-0: bindings-v0.16.0
```

A build whose tag contains that devnet name (`pq-devnet-0`, `pq-devnet-0-minimal`, `<fork>-pq-devnet-0`) gets it, whatever the source pins; a different pin in the source is logged as a warning. Other tags get the commit the source pins (`leanvm-revision`, or the leanVM git dependency in `Cargo.toml`), and the build fails when there is neither.

To move a devnet to a new leanVM release, change its line there: the sidecar image for it is built on the next scheduled run, and the client images pick it up the next time they are built (`panda build <client> --ref <devnet branch>`, or their next commit). Releases that no devnet uses are listed under `branches` of the same entry.

## Output image tags

Take the following config;

```yaml
- source:
    repository: sigp/lighthouse
    ref: stable
  target:
    tag: banana
    repository: ethpandaops/lighthouse
```

This would produce the following docker image tags;

```yaml
# the tag by itself to have the latest build
ethpandaops/lighthouse:banana
# the tag and the source repository's commit hash
ethpandaops/lighthouse:banana-abcd123
```

## How does the `build_script` work?

The `build_script` is a bash script that is run INSTEAD of the docker build & push. This is useful for clients that have a custom build process.

When the `build_script` is set, you **must** build and push the docker image yourself! Docker will already be logged in to GHCR. You **must** push to `${target_repository}:${target_tag}` and `${target_repository}:${target_tag}-${source_git_commit_hash}`, the same image under both tags; the job then mirrors them to Docker Hub.

The following environment variables are available to the `build_script`;
- `source_repository` - source repository to build from
- `source_ref` - source repository branch/tag/commit to build from
- `target_tag` - tag to add to the docker image tag
- `target_repository` - image to push to, such as `ghcr.io/ethpandaops/lighthouse`
- `target_dockerfile` - optional docker file to use, defaults to the source repository's Dockerfile
- `source_git_commit_hash` - the source repository's short commit hash
- `source_git_commit_hash_full` - the source repository's full commit hash

Example `build_script` file;
```bash
#!/bin/bash

# helper to get source directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${SCRIPT_DIR}/../source

# do something here that requires this custom build script
# ...

# finally build with the tags from the dockerfile
docker build -t "${target_repository}:${target_tag}" -t "${target_repository}:${target_tag}-${source_git_commit_hash}" -f "../${target_dockerfile}" .

# push the image tags
docker push "${target_repository}:${target_tag}"
docker push "${target_repository}:${target_tag}-${source_git_commit_hash}"
```

## Additional Configuration Files
Our image building process utilizes two additional configuration files: [`platforms.yaml`](./platforms.yaml) and [`runners.yaml`](./runners.yaml). These files help in determining the platforms for which docker images should be built and specifying the runners to use for those platforms, respectively.

### [`platforms.yaml`](./platforms.yaml)
This configuration determines the platforms for which each client will have a Docker image built.

Sample Content:
```yaml
besu:
  - linux/amd64
lighthouse:
  - linux/amd64
  - linux/arm64
```
In the example above, the client 'besu' and 'lighthouse' are both configured to have Docker images built for the linux/amd64 platform. While 'lighthouse' is also configured to have Docker images built for the linux/arm64 platform.

### [`runners.yaml`](./runners.yaml)
This configuration maps platforms to GitHub Action runners. It tells our workflow which runner should be used when building a Docker image for a specific platform.

Sample Content:
```yaml
linux/amd64: ubuntu-latest
linux/arm64: self-hosted
```

In this example, the platform linux/amd64 will use the ubuntu-latest runner, while darwin/arm64 will use the self-hosted runner.

## Lint locally

Requirements;
- Python 3.6+
- [Yamale](https://github.com/23andMe/Yamale)
- [yq](https://github.com/mikefarah/yq)

```bash
# make sure yamale is installed
pip install yamale

# yamale lint
yamale -s schema.yaml config.yaml

# check unique target tag, should return []
yq 'group_by(.target.repository + ":" + .target.tag) | map(select(length>1))' config.yaml
```
