#!/usr/bin/env sh
# Run a binding test program against the REAL Polycall core with live C-CLI
# counterparts:
#
#   tests/run-real.sh <test-command> [args...]
#
# Starts `polycall peer serve` (node id cli-node) and `polycall start` (RPC
# runtime) on ephemeral loopback ports, exports
#   POLYCALL_CLI, POLYCALL_CLI_PEER, POLYCALL_RPC_ENDPOINT, POLYCALL_DEV_TOKEN
# and runs the command. Exit 77 (SKIP) when the polycall CLI is not
# available -- a missing toolchain is never reported as success.
# Works under POSIX sh on Linux and under Git Bash / MSYS2 on Windows.
set -eu

if [ "$#" -eq 0 ]; then
    echo "usage: $0 <test-command> [args...]" >&2
    exit 2
fi

cli=${POLYCALL_CLI:-}
if [ -z "$cli" ]; then
    cli=$(command -v polycall 2>/dev/null || command -v polycall.exe 2>/dev/null || true)
fi
if [ -z "$cli" ] || [ ! -f "$cli" ]; then
    echo "SKIP: polycall CLI not found (set POLYCALL_CLI or put polycall on PATH)"
    exit 77
fi

native_cli=$cli
if command -v cygpath >/dev/null 2>&1; then
    native_cli=$(cygpath -w "$cli")
fi
export POLYCALL_CLI="$native_cli"
if [ -z "${POLYCALL_DEV_TOKEN:-}" ]; then
    POLYCALL_DEV_TOKEN="qa-$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')"
fi
export POLYCALL_DEV_TOKEN
export POLYCALL_TELEMETRY=off

work=".polycall-qa.$$"
rm -rf "$work"
mkdir "$work"
serve_pid=""
rpc_pid=""
rpc_ep=""

cleanup() {
    if [ -n "$rpc_ep" ]; then
        "$cli" stop --endpoint "$rpc_ep" --auth-token "$POLYCALL_DEV_TOKEN" >/dev/null 2>&1 || true
    fi
    [ -n "$serve_pid" ] && kill "$serve_pid" 2>/dev/null || true
    [ -n "$rpc_pid" ] && kill "$rpc_pid" 2>/dev/null || true
    [ -n "$serve_pid" ] && wait "$serve_pid" 2>/dev/null || true
    [ -n "$rpc_pid" ] && wait "$rpc_pid" 2>/dev/null || true
    rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

"$cli" peer serve --node-id cli-node --endpoint 127.0.0.1:0 \
    --endpoint-file "$work/peer.ep" >"$work/serve.log" 2>&1 &
serve_pid=$!
"$cli" start --endpoint 127.0.0.1:0 --endpoint-file "$work/rpc.ep" \
    --auth-token "$POLYCALL_DEV_TOKEN" >"$work/rpc.log" 2>&1 &
rpc_pid=$!

i=0
while [ ! -s "$work/peer.ep" ] || [ ! -s "$work/rpc.ep" ]; do
    i=$((i + 1))
    if [ "$i" -gt 100 ]; then
        echo "FAIL: polycall peer serve / polycall start did not come up" >&2
        cat "$work/serve.log" "$work/rpc.log" >&2 || true
        exit 1
    fi
    sleep 0.1
done
POLYCALL_CLI_PEER=$(tr -d '\r\n' <"$work/peer.ep")
rpc_ep=$(tr -d '\r\n' <"$work/rpc.ep")
POLYCALL_RPC_ENDPOINT=$rpc_ep
export POLYCALL_CLI_PEER POLYCALL_RPC_ENDPOINT
echo "run-real: polycall CLI $("$cli" --version | tr -d '\r'), peer node $POLYCALL_CLI_PEER, runtime $POLYCALL_RPC_ENDPOINT"

set +e
"$@"
status=$?
set -e
exit "$status"
