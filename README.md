# ada-polycall

Ada binding for the [Polycall](https://github.com/obinexus/polycall) core,
published as the npm source package `@obinexusltd/ada-polycall`.

The package `Ada_Polycall` imports the core's **binding ABI v1**
(`<polycall.h>`, `docs/BINDING_ABI.md` in the core repository) directly with
`Import` / `Convention => C` and `Interfaces.C`; it requires
**polycall >= 1.1.0**. There is no C shim and no configuration parser,
socket or protocol code in this repository.

## Ada API

```ada
with Ada_Polycall; use Ada_Polycall;

Check_ABI;                                     --  Polycall_Error unless ABI 1
Put_Line (Version);                            --  "1.1.0"

Status := Run_Config ("ada-polycallrc");                  --  polycall_ffi_run_config (path, 1)
Status := Run_Config ("ada-polycallrc", Strict => False); --  validate only
Run_Config_Or_Raise ("ada-polycallrc");                   --  raises Polycall_Error

Put_Line (Call ("127.0.0.1:7000", "inventory", "get",
                "{""item_id"":""widget-a""}", Timeout_Ms => 2000));

declare
   Alpha, Beta : Peer;                         --  limited, controlled: finalization closes
begin
   Open (Alpha, "alpha");                      --  127.0.0.1:<ephemeral>
   Open (Beta, "beta", "127.0.0.1:0", Auth_Token => Token);
   Register (Alpha, "beta", Endpoint (Beta));
   Send (Alpha, "beta", "hello", Message_Id => "msg-1");   --  String or Bytes payload
   declare
      M : constant Message := Receive (Beta, Timeout_Ms => 5000);
   begin
      --  M.Sender, M.Id (Unbounded_String), M.Payload (Stream_Element_Array)
   end;
end;
```

Also: `Open_Send_Only`, `Close` (a second `Close` raises `E_Invalid_Handle`),
`Node_Id`, `Unregister`, `List`, `Ping`, `Cancel` (wakes a task blocked in
`Receive` with `E_Cancelled`), `Health`, `Describe`, `Error_Name`,
`Last_Error`, and a non-raising `Call` procedure returning the status and
the remote error object.

`Polycall_Error` messages read
`status=<code> POLYCALL_E_<NAME>: ... (<polycall_last_error detail>) [context]`;
`Status_Of (Occurrence)` returns the code, to compare with the `E_*`
constants of the package.

## Build and test

Needs GNAT and GPRbuild (Debian: `apt-get install gnat gprbuild`) and an
installed core found through pkg-config:

```sh
export PKG_CONFIG_PATH=/opt/polycall/lib/pkgconfig LD_LIBRARY_PATH=/opt/polycall/lib
make              # lib/libada_polycall.a  (gprbuild -P ada_polycall.gpr)
make test         # real-core test + interop with the polycall CLI
make test-loader  # missing library / old library / ABI mismatch (Linux)
make memcheck     # the real-core test under valgrind memcheck
make example      # examples/basic.adb
```

Without `make`, pass the core's library directory yourself:
`gprbuild -P ada_polycall.gpr -XPOLYCALL_LDFLAGS="-L<prefix>/lib"`. Projects
that `with "ada_polycall.gpr"` inherit `-lpolycall` through
`Linker_Options` (gprbuild also records that directory as the program's
RUNPATH).

`make test` builds `tests/ada_polycall_test.adb` and runs it through
`tests/run-real.sh`, which starts `polycall peer serve` and `polycall start`.
A missing GNAT, polycall CLI or valgrind is reported as SKIP (exit 77), never
as success. See [tests/TESTS.md](tests/TESTS.md).

### Loading

The core is linked (`-lpolycall`), so the dynamic loader resolves
`libpolycall.so.1` when the program starts. A missing library stops the
program with the loader's `libpolycall.so.1: cannot open shared object file`
(exit 127); a 1.0 library without the binding ABI v1 symbols with
`undefined symbol: polycall_...` (exit 127); neither is a crash. A library
that reports another binding ABI is refused: `Check_ABI`, `Run_Config`,
`Describe`, `Call` and `Open` return or raise `E_UNSUPPORTED` (the raising
forms with a `Polycall_Error` naming the ABI it reported).
`make test-loader` checks all three against fake libraries.

Windows: the Makefile builds `.exe` programs, but the binding has not been
run on Windows yet -- the QA host has no GNAT (MinGW GNAT + GPRbuild needed).

## npm source package

```sh
npm install @obinexusltd/ada-polycall
```

The CommonJS entry point only exposes absolute paths (`adaSpec`, `adaBody`,
`project`, `config`, ...). The package is not yet published.

## Author

Nnamdi Michael Okpala — <okpalan@protonmail.com>. MIT licensed, see
[LICENSE](LICENSE).
