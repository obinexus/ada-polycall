$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$sources = @(
    (Join-Path $root 'src/ada_polycall.c'),
    (Join-Path $root 'src/ada_polycall.ads'),
    (Join-Path $root 'src/ada_polycall.adb')
)
$forbidden = 'fopen|open\(|CreateFile|sscanf|strtok|socket\(|connect\('
$matches = Select-String -Path $sources -Pattern $forbidden

if ($matches) {
    $matches | ForEach-Object { Write-Error $_.Line }
    throw 'ada-polycall must not parse configuration or implement runtime logic'
}

$adapter = Get-Content -Raw (Join-Path $root 'src/ada_polycall.c')
if (-not $adapter.Contains('polycall_ffi_run_config(config_path, 1)')) {
    throw 'ada-polycall does not forward through polycall_ffi_run_config'
}

Write-Output 'ada-polycall thin-adapter check: PASS'
