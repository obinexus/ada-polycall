# Ada tests

`ada_polycall_test.adb` runs against the REAL installed Polycall core (no
mock) and covers the checklist of the core's `docs/BINDING_ABI.md` through
the Ada API: version/ABI; `Run_Config` (valid, missing, malformed, strict
unknown key, unsupported TLS) and `Polycall_Error` (status, name, detail);
`Call` against a live `polycall start` (success, unknown operation, unknown
item, deadline, invalid input, no runtime); two peers exchanging empty,
UTF-8, binary-with-NUL and exactly-1-MiB payloads both ways (bytes, sender,
id), 1 MiB + 1 rejected; registry ownership; duplicate id stored once; auth
failure; dead peer; receive timeout; a 4-byte receive buffer (E_TOO_LARGE,
message stays queued, binding regrows); cancel and close waking a task
blocked in `Receive`; double close / use after close / unopened handle;
4 concurrent sender tasks; interop both ways with the C CLI.

`run-real.sh` starts `polycall peer serve` + `polycall start` with a random
`POLYCALL_DEV_TOKEN`; exit 77 = SKIP without the CLI. `package.test.js`
checks the npm entry point.

```sh
make test
```
