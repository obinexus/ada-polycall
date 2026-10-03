# Ada tests

`ada_polycall_test.adb` runs against the REAL installed Polycall core (no
mock) and covers the checklist of the core's `docs/BINDING_ABI.md` through
the Ada API: version/ABI; `Run_Config` (valid, missing, malformed, strict
unknown key, unsupported TLS, a non-ASCII UTF-8 file name) and
`Polycall_Error` (status, name, detail); `Call` against a live
`polycall start` (success, unknown operation, unknown item, deadline,
invalid input, no runtime, timeout 0 / 600000 / 600001); two peers
exchanging empty, UTF-8, binary-with-NUL and exactly-1-MiB payloads both
ways (bytes, sender, id), 1 MiB + 1 rejected; 63-byte ids accepted and
received intact, 64-byte ids rejected; registry ownership; duplicate id
stored once; auth failure; dead peer; receive timeout, poll (timeout 0) and
`Wait_Forever` with a queued message; a 4-byte receive buffer (E_TOO_LARGE,
message stays queued, binding regrows) and an exactly-sized one; cancel and
close waking a task blocked in `Receive`; double close / use after close /
unopened handle; 4 concurrent sender tasks; interop both ways with the C
CLI.

`run-real.sh` starts `polycall peer serve` + `polycall start` with a random
`POLYCALL_DEV_TOKEN`; exit 77 = SKIP without the CLI. `package.test.js`
checks the npm entry point.

`loader-errors.sh` (`make test-loader`, Linux) starts `loader_check.adb`
(built without a run path) against the real core, a fake library that
reports binding ABI 2, a fake 1.0 library without the ABI v1 symbols, and no
library; the fake libraries come from `loader/stub_polycall.c` and are used
for nothing else.

`make memcheck` runs the real-core test under valgrind memcheck (errors and
definite leaks fail it).

```sh
make test
make test-loader
make memcheck
```
