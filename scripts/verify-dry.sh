#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if grep -E -n 'fopen|open\(|CreateFile|sscanf|strtok|socket\(|connect\(' \
    "$root/src/ada_polycall.c" \
    "$root/src/ada_polycall.ads" \
    "$root/src/ada_polycall.adb"; then
    echo "ada-polycall must not parse configuration or implement runtime logic" >&2
    exit 1
fi

grep -F -q 'polycall_ffi_run_config(config_path, 1)' \
    "$root/src/ada_polycall.c"

echo "ada-polycall thin-adapter check: PASS"
