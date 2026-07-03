# ada-polycall

Ada binding for libpolycall 1.5.0, published as
`@obinexusltd/ada-polycall`. It is a thin adapter: configuration and runtime
logic remain in libpolycall, while this package maps Ada calls onto
`polycall_ffi_run_config(config_path, 1)`.

## Ada API

Add `src/` to the Ada source path and call either API:

```ada
with Ada_Polycall;

procedure Main is
   Status : Integer;
begin
   Status := Ada_Polycall.Run_Config ("ada-polycallrc");
   Ada_Polycall.Run_Config_Or_Raise ("ada-polycallrc");
end Main;
```

`Run_Config` returns the libpolycall status unchanged.
`Run_Config_Or_Raise` raises the Ada-native `Polycall_Error` exception when
the status is nonzero.

## npm source package

Install the package:

```sh
npm install @obinexusltd/ada-polycall
```

The CommonJS entry point exposes absolute paths for build tooling:

```js
const polycall = require('@obinexusltd/ada-polycall');

console.log(polycall.adaSpec);
console.log(polycall.adaBody);
console.log(polycall.nativeAdapter);
console.log(polycall.publicHeader);
console.log(polycall.ffiHeader);
console.log(polycall.project);
console.log(polycall.config);
```

The npm tarball explicitly includes `src/`, `include/`, `generated/`,
`examples/`, `scripts/`, and `tests/`, plus the GNAT project, Makefile,
manifest, and read-only runtime configuration. Platform-specific build output
is excluded.

## Build and test

Build the portable native forwarding archive with GCC:

```sh
make
# or
npm run build
```

With GNAT and GPRbuild installed, build the complete Ada library:

```sh
make ada
# or
npm run build:ada
```

The native boundary and npm package tests do not require GNAT:

```sh
npm test
npm run verify
```

Run the Ada smoke test when GNAT is available:

```sh
npm run test:ada
```

## Core integration

A real integration run requires a libpolycall v1.5 library exporting
`polycall_ffi_run_config`. Link it into the Ada executable with:

```sh
make example POLYCALL_LDFLAGS="-L/path/to/libpolycall/lib -lpolycall"
```

The runnable program is [`examples/basic.adb`](examples/basic.adb). The
read-only shared-schema override is [`ada-polycallrc`](ada-polycallrc); the
binding never parses or modifies it.
