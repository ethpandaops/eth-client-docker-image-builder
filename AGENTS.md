# Agent notes

## Adding a new image

A new image name (`ethpandaops/<name>`) needs changes here and an image-mirror allowlist entry. The build fails at its last step if the allowlist entry is missing.

In this repository:

1. `.github/workflows/build-push-<name>.yml`, copied from an existing one. `panda build <name>` dispatches the workflow with exactly this filename.
2. `platforms.yaml`: the platforms to build `<name>` for.
3. `generate_config.py`: an entry in `DEFAULT_REPOS` when the source is not `ethpandaops/<name>`.
4. `branches.yaml`: the branches to build on schedule.
5. `README.md`: a link to the workflow.

Outside this repository:

6. Ask the platform team to add `<name>` to the image-mirror allowlist, for both `deploy.yml` (scheduled builds) and `build-push-<name>.yml` (manual builds) of this repository.

Builds push to `ghcr.io/ethpandaops/<name>` and then ask the image mirror to copy the tags to Docker Hub. The mirror only publishes image names on that allowlist, so until step 6 is rolled out every build of the new image fails with:

```
The image mirror won't publish <name> from ethpandaops/eth-client-docker-image-builder@refs/heads/master.
```

The image is on GHCR at that point, but not on Docker Hub. A new branch, tag or Dockerfile for an image that already exists needs no allowlist change.
