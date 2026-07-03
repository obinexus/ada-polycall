# Ada tests

`ada_polycall_adapter_test.c` verifies that the native adapter forwards the
path, sets `run=1`, and propagates success and failure statuses unchanged.

`ada_polycall_smoke.adb` loads `../ada-polycallrc` through the Ada API and
asserts a zero status. Run the native test with `make test`; run the Ada smoke
test with `make test-ada` when GNAT is installed.
