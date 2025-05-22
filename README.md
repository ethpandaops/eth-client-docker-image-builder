# eth-client-docker-image-builder

Automates docker builds for ethereum clients. The build process is scheduled every hour to check source repositories for new commits.

## Build image on demand

Run the *Build **client*** workflow;
- [Build Besu](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-besu.yml) [[source](https://github.com/hyperledger/besu)]
- [Build Eleel](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-eleel.yml) [[source](https://github.com/sigp/eleel)]
- [Build Erigon](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-erigon.yml) [[source](https://github.com/ledgerwatch/erigon)]
- [Build EthereumJS](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-ethereumjs.yml) [[source](https://github.com/ethereumjs/ethereumjs-monorepo)]
- [Build Ethrex](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-ethrex.yml) [[source](https://github.com/lambdaclass/ethrex)]
- [Build Geth](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-geth.yml) [[source](https://github.com/ethereum/go-ethereum)]
- [Build Lighthouse](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-lighthouse.yml) [[source](https://github.com/sigp/lighthouse)]
- [Build Lodestar](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-lodestar.yml) [[source](https://github.com/chainsafe/lodestar)]
- [Build Nethermind](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-nethermin.yml) [[source](https://github.com/nethermindeth/nethermind)]
- [Build Nimbus-Eth2](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-nimbus-eth2.yml) [[source](https://github.com/status-im/nimbus-eth2)]
- [Build Nimbus-Eth1](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-nimbus-eth1.yml) [[source](https://github.com/status-im/nimbus-eth1)]
- [Build Prysm](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-prysm.yml) [[source](https://github.com/offchainlabs/prysm)]
- [Build Reth](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-reth.yml) [[source](https://github.com/paradigmxyz/reth)]
- [Build Teku](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-teku.yml) [[source](https://github.com/consensys/teku)]
- [Build Grandine](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-grandine.yml) [[source](https://github.com/grandinetech/grandine)]

Run the *Build **tooling*** workflow;
- [Build Flashbots Builder](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-flashbots-builder.yml) [[source](https://github.com/flashbots/builder)]
- [Build tx-fuzz](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-tx-fuzz.yaml) [[source](https://github.com/MariusVanDerWijden/tx-fuzz)]
- [Build consesnus-monitor](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/.github/workflows/build-push-consensus-monitor.yml) [[source](https://github.com/ralexstokes/ethereum_consensus_monitor)]
- [Build execution-monitor](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/.github/workflows/build-push-execution-monitor.yml) [[source](https://github.com/ethereum/nodemonitor)]
- [Build beacon-metrics-gazer](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/.github/workflows/build-push-beacon-metrics-gazer.yml) [[source](https://github.com/dapplion/beacon-metrics-gazer)]
- [Build goomy-blob](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-goomy-blob.yaml) [[source](https://github.com/ethpandaops/goomy-blob)]
- [Build ethereum-genesis-generator](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-genesis-generator.yml) [[source](https://github.com/ethpandaops/ethereum-genesis-generator)]
- [Build mev-rs](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-mev-rs.yml) [[source](https://github.com/ralexstokes/mev-rs)]
- [Build reth-rbuilder](https://github.com/ethpandaops/eth-client-docker-image-builder/actions/workflows/build-push-reth-rbuilder.yml) [[source](https://github.com/flashbots/rbuilder)]

## Adding a new image to build on schedule

Add a new image to [`config.yaml`](./config.yaml) file and it will be built on schedule from [this workflow](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/.github/workflows/scheduled.yml).

```yaml
- source:
    repository: sigp/lighthouse # source repository to build from
    ref: stable # source repository branch/tag/commit to build from
  build_script: ./teku/build.sh # optional build script to run INSTEAD of the docker build & push (see below)
  target:
    tag: stable # tag to add to the docker image tag, this must be unique for each docker hub repository
    repository: ethpandaops/lighthouse # dockerhub target to deploy the built image
    dockerfile: ./lighthouse/Dockerfile # optional docker file to use, defaults to the source repository's Dockerfile
```

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

When the `build_script` is set, you **must** build and push the docker image yourself! Docker will already be logged in to the target repository. You **should** try to use the `target_tag` and `target_repository` environment variables to tag your image.

The following environment variables are available to the `build_script`;
- `source_repository` - source repository to build from
- `source_ref` - source repository branch/tag/commit to build from
- `target_tag` - tag to add to the docker image tag
- `target_repository` - dockerhub target to deploy the built image
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
