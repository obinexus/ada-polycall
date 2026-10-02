#!/usr/bin/env sh
# Thin-adapter audit: ada-polycall imports the real binding ABI of
# <polycall.h> and must not parse configuration or open sockets itself.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if grep -E -n -i 'GNAT\.Sockets|Ada\.Text_IO\.Open|Stream_IO|sscanf|strtok' \
    "$root/src/ada_polycall.ads" "$root/src/ada_polycall.adb"; then
    echo "ada-polycall must not parse configuration or implement runtime logic" >&2
    exit 1
fi
if grep -R -n 'polycall_ffi\.h' "$root/src" "$root/ada_polycall.gpr" "$root/Makefile"; then
    echo "ada-polycall must bind the real ABI, not a generated stub" >&2
    exit 1
fi
for sym in polycall_ffi_abi_version polycall_ffi_version polycall_strerror \
           polycall_last_error polycall_ffi_run_config polycall_ffi_describe polycall_call \
           polycall_peer_open polycall_peer_close polycall_peer_endpoint polycall_peer_node_id \
           polycall_peer_register polycall_peer_unregister polycall_peer_list polycall_peer_ping \
           polycall_peer_send polycall_peer_recv polycall_peer_cancel polycall_peer_health; do
    grep -F -q "External_Name => \"$sym\"" "$root/src/ada_polycall.adb"
done

echo "ada-polycall thin-adapter check: PASS"
