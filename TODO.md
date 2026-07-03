# TODO — ada-polycall (Ada)

Status: implemented thin adapter for libpolycall 1.5.0.

- [x] Folder structure, manifest, and `ada-polycallrc` (shared schema)
- [x] Generate the consumed declaration from `polycall_ffi.h`
- [x] Implement the thin adapter in `src/` (Ada/C -> `polycall_ffi_run_config`)
- [x] Add a runnable example under `examples/`
- [x] Add native and Ada smoke tests under `tests/`
- [x] Add `scripts/verify-dry.sh` (no core duplication)

Do not add config parsing or runtime logic here — adapt the core only.
