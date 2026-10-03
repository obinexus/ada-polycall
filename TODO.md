# TODO — ada-polycall (Ada)

Status: supported (Linux, GNAT 12) -- Ada binding over Polycall binding ABI v1
(polycall >= 1.1.0).

- [x] `Run_Config` / `Run_Config_Or_Raise` kept (strict and validate modes)
- [x] Direct `Import`/`Convention => C` binding of the whole ABI (no C shim)
- [x] `Peer` (limited controlled), `Message`, `Call`, `Describe`, version/ABI
- [x] Real-core tests incl. Ada tasks and interop with the C CLI
- [x] Loader errors (missing / old / ABI-mismatched library), valgrind run
- [ ] Windows (GNAT/MinGW) run -- needs GNAT + GPRbuild on the Windows host
- [ ] Publish `@obinexusltd/ada-polycall` (not published yet)

Do not add config parsing or runtime logic here — adapt the core only.
