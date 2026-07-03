# Ada adapter

The adapter calls across the FFI boundary only:

    status = polycall_ffi_run_config("ada-polycallrc", /*run=*/1)

`ada_polycall.c` fixes the FFI `run` argument to one and propagates the status
unchanged. `ada_polycall.adb` converts the Ada `String` to a C string and
exposes both a status-returning `Run_Config` function and an
`Run_Config_Or_Raise` procedure that raises `Polycall_Error` on failure.
Neither layer parses configuration or duplicates core logic.
