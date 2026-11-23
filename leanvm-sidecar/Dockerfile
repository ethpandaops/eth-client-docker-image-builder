# syntax=docker/dockerfile:1

FROM rust:1.99.1-bookworm@sha256:e6f2cff35d0f309acf8433b4f05878ed77092602c5065cc81801177da0bb3a9c AS build
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true
ARG TARGETARCH
WORKDIR /leanvm
COPY . .
RUN --mount=type=cache,id=leanvm-sidecar-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=leanvm-sidecar-target-${TARGETARCH},target=/leanvm/target \
    <<'EOF'
#!/bin/sh
set -eu

out=/out/lib/leanvm-sidecar
mkdir -p "$out"
: > "$out/profiles.tsv"

build_profile() {
    profile=$1
    flags=$2
    CARGO_TARGET_DIR="/leanvm/target/$profile" RUSTFLAGS="$flags" \
        cargo build --target "$target" --locked --release -p leanvm-sidecar --features experimental_prover
    install "/leanvm/target/$profile/$target/release/leanvm-sidecar" "$out/leanvm-sidecar-$profile"

    required=
    if [ "$target" = x86_64-unknown-linux-gnu ] && [ "$profile" != generic ]; then
        required=$(rustc --target "$target" $flags --print cfg | awk -F'"' '
            /^target_feature=/ {
                feature = $2
                if (feature == "sse3") feature = "pni"
                if (feature == "sse4.1") feature = "sse4_1"
                if (feature == "sse4.2") feature = "sse4_2"
                printf "%s%s", separator, feature
                separator = " "
            }
        ')
        test -n "$required"
    fi
    printf '%s\t%s\t%s\n' "$profile" "leanvm-sidecar-$profile" "$required" >> "$out/profiles.tsv"
}

case "$TARGETARCH" in
    arm64)
        target=aarch64-unknown-linux-gnu
        export JEMALLOC_SYS_WITH_LG_PAGE=16
        build_profile portable "-C target-cpu=generic -C target-feature=+aes"
        ;;
    amd64)
        target=x86_64-unknown-linux-gnu
        generic="-C target-cpu=x86-64"
        portable="$generic -C target-feature=+ssse3,+pclmulqdq"
        avx2="$portable,+avx2,+bmi2"
        avx2_gfni="$avx2,+gfni,+vpclmulqdq"
        avx512="$avx2_gfni,+avx512f,+avx512bw,+avx512vbmi"
        build_profile generic "$generic"
        build_profile portable "$portable"
        build_profile avx2 "$avx2"
        build_profile avx2-gfni "$avx2_gfni"
        build_profile avx512 "$avx512"
        ;;
    *)
        echo "Unsupported leanVM target architecture: $TARGETARCH" >&2
        exit 1
        ;;
esac
EOF

COPY --chmod=755 <<'EOF' /out/bin/leanvm-sidecar
#!/bin/sh
set -eu

sidecars=/usr/local/lib/leanvm-sidecar
requested=${LEANVM_CPU_PROFILE:-auto}

cpu_flags=$(awk -F: '
    $1 ~ /^(flags|Features)[ \t]*$/ {
        cpus++
        count_of_fields = split($2, fields, " ")
        for (i = 1; i <= count_of_fields; i++)
            if (!seen[cpus, fields[i]]++) count[fields[i]]++
    }
    END { for (flag in count) if (count[flag] == cpus) print flag }
' /proc/cpuinfo 2>/dev/null || true)

selected_profile=
selected_binary=
while IFS="$(printf '\t')" read -r profile binary required; do
    if [ "$requested" != auto ] && [ "$requested" != "$profile" ]; then
        continue
    fi
    missing=
    for flag in $required; do
        printf '%s\n' "$cpu_flags" | grep -qx -- "$flag" || missing="$missing $flag"
    done
    if [ -z "$missing" ]; then
        selected_profile=$profile
        selected_binary=$binary
    elif [ "$requested" = "$profile" ]; then
        echo "leanvm-sidecar: CPU profile $profile requires:$missing" >&2
        exit 1
    fi
done < "$sidecars/profiles.tsv"

if [ -z "$selected_binary" ]; then
    echo "leanvm-sidecar: no sidecar available for CPU profile $requested" >&2
    exit 1
fi

echo "leanvm-sidecar CPU profile: $selected_profile" >&2
exec "$sidecars/$selected_binary" "$@"
EOF

COPY --chmod=755 <<'EOF' /out/bin/leanvm-sidecar-run
#!/bin/bash
set -eu

if (( $# < 2 )); then
    echo 'usage: leanvm-sidecar-run <socket-flag> <command> [argument...]' >&2
    exit 2
fi
socket_flag=$1
node=$2
shift 2

socket_dir=$(mktemp -d "${TMPDIR:-/tmp}/leanvm.XXXXXXXX")
socket="$socket_dir/sidecar.sock"
sidecar_pid=
node_pid=

cleanup() {
    for pid in $node_pid $sidecar_pid; do
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    rm -rf -- "$socket_dir"
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

leanvm-sidecar --socket "$socket" --threads "${LEANVM_THREADS:-0}" &
sidecar_pid=$!
deadline=$((SECONDS + 120))
until [[ -S "$socket" ]]; do
    if ! kill -0 "$sidecar_pid" 2>/dev/null; then
        echo 'leanvm-sidecar exited before creating its socket' >&2
        exit 1
    fi
    if (( SECONDS >= deadline )); then
        echo 'leanvm-sidecar did not create its socket within 120 seconds' >&2
        exit 1
    fi
    sleep 0.1
done

"$node" "$socket_flag" "$socket" "$@" &
node_pid=$!

status=0
wait -n "$sidecar_pid" "$node_pid" || status=$?
if kill -0 "$node_pid" 2>/dev/null; then
    echo "leanvm-sidecar exited while $node was running" >&2
    exit 1
fi
node_pid=
exit "$status"
EOF

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libstdc++6 \
    && rm -rf /var/lib/apt/lists/*
ARG COMMIT_HASH
LABEL org.opencontainers.image.revision=$COMMIT_HASH
COPY --from=build /out/ /usr/local/
ENTRYPOINT ["/usr/local/bin/leanvm-sidecar"]
