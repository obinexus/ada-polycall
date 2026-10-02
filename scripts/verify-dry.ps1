$ErrorActionPreference = 'Stop'

# Thin-adapter audit (see verify-dry.sh).
$root = Split-Path -Parent $PSScriptRoot
$body = Join-Path $root 'src/ada_polycall.adb'
$spec = Join-Path $root 'src/ada_polycall.ads'
$found = Select-String -Path $body, $spec -Pattern 'GNAT\.Sockets|Ada\.Text_IO\.Open|Stream_IO|sscanf|strtok'
if ($found) {
    $found | ForEach-Object { Write-Error $_.Line }
    throw 'ada-polycall must not parse configuration or implement runtime logic'
}
$source = Get-Content -Raw $body
foreach ($sym in @('polycall_ffi_abi_version', 'polycall_ffi_run_config', 'polycall_call',
                   'polycall_peer_open', 'polycall_peer_send', 'polycall_peer_recv')) {
    if (-not $source.Contains("External_Name => `"$sym`"")) {
        throw "ada-polycall does not import $sym"
    }
}
Write-Output 'ada-polycall thin-adapter check: PASS'
