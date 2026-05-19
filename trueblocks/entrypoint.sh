#!/bin/sh
# Bootstrap entrypoint for the ethpandaops/trueblocks image.
#
# Inputs are read from env vars; the ethereum-package launcher sets them, and
# users running the image standalone can too (`docker run -e TB_CHAIN=…`).
set -u

CHAIN="${TB_CHAIN:-mainnet}"
RPC_URL="${TB_RPC_URL:-}"
PROBE_ADDR="${TB_PROBE_ADDR:-}"
SCRAPE_SLEEP="${TB_SCRAPE_SLEEP:-3}"
HTTP_PORT="${TB_HTTP_PORT:-8080}"
CONFIG_STAGING="${TB_CONFIG_STAGING:-/tb-config}"

CONFIG_DIR=/root/.local/share/trueblocks
CHAIN_DIR="$CONFIG_DIR/config/$CHAIN"

mkdir -p "$CHAIN_DIR"

if [ -f "$CONFIG_STAGING/trueBlocks.toml" ]; then
    cp "$CONFIG_STAGING/trueBlocks.toml" "$CONFIG_DIR/trueBlocks.toml"
fi

# chifra's IsNodeArchive picks the largest prefund in <chain>/allocs.csv and
# compares its balance to the RPC's balance at block 0; without a matching row
# it refuses to scrape. For chains we don't ship a bundled allocs.csv for, the
# caller passes TB_PROBE_ADDR and we write a self-consistent row at runtime.
# (The zero address won't work — chifra's Address.Hex() short-circuits to
# "0x0", which fails its own IsValidAddress length check.)
if [ -n "$PROBE_ADDR" ] && [ -n "$RPC_URL" ] && [ ! -f "$CHAIN_DIR/allocs.csv" ]; then
    BAL=""
    for _ in $(seq 1 60); do
        BAL=$(curl -fsS -X POST -H 'Content-Type: application/json' \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$PROBE_ADDR\",\"0x0\"],\"id\":1}" \
            "$RPC_URL" 2>/dev/null \
            | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
        echo "$BAL" | grep -qE '^0x[0-9a-fA-F]+$' && break
        sleep 2
    done
    echo "$BAL" | grep -qE '^0x[0-9a-fA-F]+$' || {
        echo "trueblocks entrypoint: balance probe of $PROBE_ADDR at $RPC_URL failed" >&2
        exit 1
    }
    printf 'address,balance\n%s,%s\n' "$PROBE_ADDR" "$BAL" > "$CHAIN_DIR/allocs.csv"
fi

# chifra scrape exits non-zero before block 1 has been mined (it reads the RPC
# error as "node lacks tracing"). Retry forever so it catches up once the
# chain starts producing blocks.
(
    while true; do
        chifra scrape --sleep "$SCRAPE_SLEEP" 2>&1
        sleep 5
    done
) &

exec chifra daemon --url ":$HTTP_PORT"
