# syntax=docker/dockerfile:1.10
#
# ingress-nginx controller v1.12.1 with upstream nginx security fixes backported
# to its bundled nginx 1.25.5.
#
# The upstream controller image is used unchanged except for one file: the
# nginx binary (/usr/local/nginx/sbin/nginx). It is rebuilt here from the same
# sources, patches and configure arguments the upstream base image
# registry.k8s.io/ingress-nginx/nginx:v1.2.1 was built with
# (kubernetes/ingress-nginx images/nginx/rootfs/build.sh at controller-v1.12.1),
# plus the patches in ./patches, which are unmodified `git format-patch` output
# of the nginx stable-1.30 commits that shipped in nginx 1.30.7. See README.md.

# Upstream ingress-nginx images (linux/amd64 and linux/arm64 index digests).
ARG BASE_IMAGE=registry.k8s.io/ingress-nginx/nginx:v1.2.1@sha256:9ed93911ae01d8cf4d8b3de0e62e718d7a76ad59ef88dd51bb3b9f87ef443c9a
ARG CONTROLLER_IMAGE=registry.k8s.io/ingress-nginx/controller:v1.12.1@sha256:d2fbc4ec70d8aa2050dd91a91506e998765e86c96f32cffb56c503c9c34eed5b

# Checks the nginx release tarball's signature. The signing key is Roman
# Arutyunyan's (fingerprint 43387825DDB1BB97EC36BA5D007C8D7C15D87369), from
# https://nginx.org/en/pgp_keys.html; all three downloads are also pinned by
# sha256.
FROM ${BASE_IMAGE} AS verify
RUN apk add --no-cache gpgv=2.4.9-r0
ADD --checksum=sha256:373eb96344f805f7c7c42733aaeca6adde289f00135ff2c167d301c43925b382 \
    https://nginx.org/keys/arut.key /verify/
ADD --checksum=sha256:092c4d1781fc9ceb1a759fabffbd5ef09fbe7108f8e37dbf3797eb5a24cf37a2 \
    https://nginx.org/download/nginx-1.25.5.tar.gz.asc /verify/
ADD --checksum=sha256:2fe2294f8af4144e7e842eaea884182a84ee7970e11046ba98194400902bbec0 \
    https://nginx.org/download/nginx-1.25.5.tar.gz /verify/
RUN <<'EOF'
set -eu
cd /verify
# gpgv reads only binary keyrings: strip the ASCII armor.
awk '/^-----BEGIN/ {b=1; next} b && /^$/ {d=1; next} /^-----END/ {exit} d && !/^=/ {print}' arut.key \
  | base64 -d > arut.gpg
gpgv --status-fd 1 --keyring ./arut.gpg nginx-1.25.5.tar.gz.asc nginx-1.25.5.tar.gz > status
grep -q '^\[GNUPG:\] VALIDSIG 43387825DDB1BB97EC36BA5D007C8D7C15D87369 ' status
EOF

# The builder starts from the upstream nginx base image, which already holds
# the LuaJIT and libmodsecurity headers and libraries the original build used.
FROM ${BASE_IMAGE} AS builder

# Pinned so the build is reproducible; Alpine drops superseded versions, so a
# failure here means the pins need refreshing, not that the build should float.
# The -dev packages pull newer openssl (3.3.7), zlib (1.4) and musl (r12) into
# the builder only; the controller image keeps its own libraries, which are
# ABI-compatible releases of the same series.
# fortify-headers is what makes -D_FORTIFY_SOURCE=2 take effect with musl;
# upstream's build.sh gets it through build-base.
RUN apk add --no-cache \
    gcc=14.2.0-r4 \
    fortify-headers=1.1-r5 \
    musl-dev=1.2.5-r12 \
    make=4.4.1-r2 \
    linux-headers=6.6-r1 \
    openssl-dev=3.3.7-r2 \
    pcre-dev=8.45-r3 \
    zlib-dev=1.4-r0 \
    libmaxminddb-dev=1.9.1-r0 \
    libcap=2.78-r0

# The nginx 1.25.5 release tarball whose signature the verify stage checked.
COPY --from=verify /verify/nginx-1.25.5.tar.gz /tmp/build/

# ingress-nginx's own nginx patches, at the controller-v1.12.1 commit.
ADD https://github.com/kubernetes/ingress-nginx.git#64780b1fed3af99f4eccbc3fdad7ad785e8a83b6:images/nginx/rootfs/patches /patches/ingress-nginx

# Modules compiled into the binary or configured as dynamic modules, at the
# versions build.sh pins (tags resolved to their commits).
ADD https://github.com/vision5/ngx_devel_kit.git#91e30eb05085e7f9762f130cbb883a0e753cf74d /tmp/build/ngx_devel_kit
ADD https://github.com/openresty/set-misc-nginx-module.git#796f5a3e518748eb29a93bd450324e0ad45b704e /tmp/build/set-misc-nginx-module
ADD https://github.com/openresty/headers-more-nginx-module.git#06dc0be56e5ec9f7fd814e881b066b5540a85bec /tmp/build/headers-more-nginx-module
ADD https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git#e12e965ac1837ca709709f9a26f572a54d83430e /tmp/build/ngx_http_substitutions_filter_module
ADD https://github.com/openresty/lua-nginx-module.git#0e769b76432df91e5f10aa56a56858e8a190faf7 /tmp/build/lua-nginx-module
ADD https://github.com/openresty/stream-lua-nginx-module.git#bea8a0c0de94cede71554f53818ac0267d675d63 /tmp/build/stream-lua-nginx-module
ADD https://github.com/openresty/lua-upstream-nginx-module.git#542be0893543a4e42d89f6dd85372972f5ff2a36 /tmp/build/lua-upstream-nginx-module
ADD https://github.com/atomx/nginx-http-auth-digest.git#cd8641886c873cf543255aeda20d23e4cd603d05 /tmp/build/nginx-http-auth-digest
ADD https://github.com/SpiderLabs/ModSecurity-nginx.git#d59e4ad121df702751940fd66bcc0b3ecb51a079 /tmp/build/ModSecurity-nginx
ADD https://github.com/leev/ngx_http_geoip2_module.git#a607a41a8115fecfc05b5c283c81532a3d605425 /tmp/build/ngx_http_geoip2_module
ADD https://github.com/google/ngx_brotli.git#63ca02abdcf79c9e788d2eedcc388d2335902e52 /tmp/build/ngx_brotli

COPY patches /patches/backports

# Same steps, flags and paths as build.sh, so `nginx -V` matches the upstream
# binary. Only the binary is built (`make binary`); the upstream dynamic
# modules in the controller image are kept.
RUN <<'EOF'
set -euxo pipefail
# The flags below are build.sh's x86_64 flags; all clusters are amd64.
test "$(uname -m)" = x86_64
export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.1

sed -i "s/ngx_feature_test='printf(\"hello\");'/ngx_feature_test='msc_init();'/" /tmp/build/ModSecurity-nginx/config

cd /tmp/build
tar xzf nginx-1.25.5.tar.gz
cd nginx-1.25.5

for p in $(ls /patches/ingress-nginx); do
  if [[ "$p" == *.txt ]]; then
    patch -p0 < "/patches/ingress-nginx/$p"
  else
    patch -p1 < "/patches/ingress-nginx/$p"
  fi
done

# --no-backup-if-mismatch: the patches apply with line offsets only.
for p in $(ls /patches/backports); do
  patch -p1 --fuzz=0 --no-backup-if-mismatch < "/patches/backports/$p"
done

WITH_FLAGS="--with-debug --with-compat --with-pcre-jit --with-http_ssl_module \
  --with-http_stub_status_module --with-http_realip_module \
  --with-http_auth_request_module --with-http_addition_module \
  --with-http_gzip_static_module --with-http_sub_module --with-http_v2_module \
  --with-http_v3_module --with-stream --with-stream_ssl_module \
  --with-stream_realip_module --with-stream_ssl_preread_module --with-threads \
  --with-http_secure_link_module --with-http_gunzip_module --with-file-aio"

CC_OPT="-g -O2 -fPIE -fstack-protector-strong -Wformat -Werror=format-security \
  -Wno-deprecated-declarations -fno-strict-aliasing -D_FORTIFY_SOURCE=2 \
  --param=ssp-buffer-size=4 -DTCP_FASTOPEN=23 -fPIC -Wno-cast-function-type \
  -m64 -mtune=generic"
LD_OPT="-fPIE -fPIC -pie -Wl,-z,relro -Wl,-z,now"

./configure \
  --prefix=/usr/local/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --modules-path=/etc/nginx/modules \
  --http-log-path=/var/log/nginx/access.log \
  --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock \
  --pid-path=/run/nginx.pid \
  --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
  --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi \
  --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  ${WITH_FLAGS} \
  --without-mail_pop3_module \
  --without-mail_smtp_module \
  --without-mail_imap_module \
  --without-http_uwsgi_module \
  --without-http_scgi_module \
  --with-cc-opt="${CC_OPT}" \
  --with-ld-opt="${LD_OPT}" \
  --user=www-data \
  --group=www-data \
  --add-module=/tmp/build/ngx_devel_kit \
  --add-module=/tmp/build/set-misc-nginx-module \
  --add-module=/tmp/build/headers-more-nginx-module \
  --add-module=/tmp/build/ngx_http_substitutions_filter_module \
  --add-module=/tmp/build/lua-nginx-module \
  --add-module=/tmp/build/stream-lua-nginx-module \
  --add-module=/tmp/build/lua-upstream-nginx-module \
  --add-dynamic-module=/tmp/build/nginx-http-auth-digest \
  --add-dynamic-module=/tmp/build/ModSecurity-nginx \
  --add-dynamic-module=/tmp/build/ngx_http_geoip2_module \
  --add-dynamic-module=/tmp/build/ngx_brotli

make -j"$(nproc)" -f objs/Makefile binary
install -m 0755 objs/nginx /nginx
setcap cap_net_bind_service=+ep /nginx
EOF

FROM ${CONTROLLER_IMAGE}
# --chown and the file capability match the upstream image.
COPY --from=builder --chown=www-data:www-data /nginx /usr/local/nginx/sbin/nginx
