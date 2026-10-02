# Ada adapter

`ada_polycall.adb` imports every function of the Polycall binding ABI v1
(`<polycall.h>`) with `Import`, `Convention => C` and the exact C
signatures (`Interfaces.C.int`, `size_t`, `char_array`, `Integer_32`
handles, `Unsigned_32` timeouts, `System.Address` for byte buffers and
nullable strings). Output goes into Ada-owned buffers; the core never
returns memory to free.

    Run_Config (Path)  ->  polycall_ffi_run_config (Path, 1)

Failures raise `Polycall_Error` carrying the status, `polycall_strerror`
name and `polycall_last_error` detail. Nothing here parses configuration or
duplicates core logic.
