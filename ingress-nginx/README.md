# ingress-nginx controller v1.12.1 with backported nginx fixes

`ethpandaops/ingress-nginx-controller:v1.12.1-patched.1` is the upstream
`registry.k8s.io/ingress-nginx/controller:v1.12.1` image with one file replaced: the
nginx binary, `/usr/local/nginx/sbin/nginx`. kubernetes/ingress-nginx is archived and
will not ship another release, so this is how our clusters get the nginx security
fixes released in nginx 1.30.7 and 1.31.9 without changing anything else.

The binary is nginx 1.25.5, as upstream bundles it, built from the same sources,
ingress-nginx patches and configure arguments as upstream's
`images/nginx/rootfs/build.sh` at `controller-v1.12.1`, plus `patches/`.
`nginx -V` prints the same configure arguments as the upstream binary.

## Patches

Each file is unmodified `git format-patch` output of a commit on nginx's
`stable-1.30` branch that shipped in 1.30.7. They apply to 1.25.5 with line offsets
only (`patch --fuzz=0`).

| File | CVE | nginx commit |
| --- | --- | --- |
| `01-CVE-2026-123633-http2-reusable-connection.patch` | CVE-2026-123633 | `0c87dd1db413e440a4e3ef7ee8acc518509e8809` |
| `02-CVE-2026-118899-request-body-again.patch` | CVE-2026-118899 | `1b723277aa556ba4c6e40cc8f0f0b465e29c0a13` |
| `03-CVE-2026-118899-http3-request-body-again.patch` | CVE-2026-118899 | `d1640655f46c5a2d32fefc2c818583f203e47536` |
| `04-CVE-2026-123634-resolver-cname-restart-error.patch` | CVE-2026-123634 | `338f6231e347c17a07c381802b1bc3c20c55b529` |
| `05-CVE-2026-123634-resolver-finalization.patch` | CVE-2026-123634 | `7426c29f140c330dd6c6cdfeb2943be1978c69e0` |
| `06-CVE-2026-123007-http2-window-update.patch` | CVE-2026-123007 | `b89c4100bf6762a45e4a6463eaf4b70368277c94` |
| `07-CVE-2026-121810-quic-stream-reuse.patch` | CVE-2026-121810 | `c58d2a22d12350766185c94f2245bf4be5bcfb7d` |

Not included:

- CVE-2026-113425 (mail proxy): the binary has no mail module (`--with-mail` is not
  configured).
- CVE-2026-125283, CVE-2026-120967, CVE-2026-123640: `try_files` with `alias` (alias is
  removed by ingress-nginx's `00_drop-alias-root.patch`) and two stream TLS checks the
  controller's stream servers don't use.
- CVE-2026-120993: affects 1.31.4 to 1.31.8 only.

To check a patch against nginx itself:

```sh
git clone https://github.com/nginx/nginx && cd nginx
git format-patch -1 --stdout --no-signature b89c4100bf6762a45e4a6463eaf4b70368277c94 \
  | diff - ../ingress-nginx/patches/06-CVE-2026-123007-http2-window-update.patch
```

Every function these patches touch is identical in nginx 1.25.5 and 1.30.6, the last
stable release before the fixes, so the patched 1.25.5 differs from 1.30.7 in exactly
the lines that 1.25.5 differs from 1.30.6 in those files.

## Build

The build is reproducible: the same inputs give the same image digest. The digest also
depends on the BuildKit version, which compresses the new layer; the workflow pins
`moby/buildkit:v0.34.2`, the version this digest was produced and reproduced with.

```sh
docker buildx build --platform linux/amd64 --provenance=false --sbom=false \
  --build-arg SOURCE_DATE_EPOCH=1794960000 \
  --output type=docker,name=ingress-nginx-controller:test,rewrite-timestamp=true \
  ingress-nginx/
```

Expected linux/amd64 image digest:
`sha256:eb226b2e4795498081e07ad632edbad889a590e9ddbd1a2ab4492442e8e50cf9`,
nginx binary sha256
`1cf27fe30f057874cca78dec51d46f45a857f298ebe73101d728ef7559d95902`.
The workflow checks the digest of the local build before anything is pushed, then
pushes that exact OCI archive with `skopeo copy --preserve-digests` and checks the
registry's digest again.

The build verifies the nginx tarball's PGP signature (the `verify` stage) against
Roman Arutyunyan's key, fingerprint `43387825DDB1BB97EC36BA5D007C8D7C15D87369`,
fetched from nginx.org and pinned by sha256 like the tarball and signature.

`fortify-headers` must be in the builder: without it musl ignores
`-D_FORTIFY_SOURCE=2` and the binary loses the checks upstream's has. `test.sh`
compares the number of `ud2` traps with the upstream binary (426 in both).

Before the first push, create the Docker Hub repository
`ethpandaops/ingress-nginx-controller` as public with immutable tags, so a later
push cannot replace `v1.12.1-patched.1`.

Only linux/amd64 is built; the configure flags are build.sh's x86_64 flags.

The builder's `-dev` packages bring OpenSSL 3.3.7, zlib 1.4 and musl 1.2.5-r12
headers; the controller image keeps upstream's OpenSSL 3.3.3, zlib 1.3.1 and musl
1.2.5-r9 libraries, so `nginx -V` reports "built with OpenSSL 3.3.7 (running with
OpenSSL 3.3.3)". These are ABI-compatible releases of the same Alpine 3.21 series.
