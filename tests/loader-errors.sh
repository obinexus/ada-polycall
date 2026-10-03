#!/usr/bin/env sh
# Loader-error checks for a binding that is LINKED against libpolycall
# (-lpolycall; the dynamic loader resolves it when the program starts):
#
#   tests/loader-errors.sh <loader-check-program> [repo-root]
#
# The program (tests/loader_check.*) prints "loader-check: <step>=<status>"
# lines. It is started four times with LD_LIBRARY_PATH pointing at:
#   1. the real installed core            -> every step works (the call to
#      127.0.0.1:1, where nothing listens, is E_TRANSPORT = -5)
#   2. a fake library speaking ABI 2      -> the binding refuses it with
#      POLYCALL_E_UNSUPPORTED (-15) naming the ABI (check_abi, run_config,
#      call, peer open), and the program exits normally
#   3. a fake "old 1.0" library (no ABI v1 symbols) -> the dynamic loader
#      stops the program with "undefined symbol: polycall_..." (exit 127)
#   4. no library at all                  -> the dynamic loader stops the
#      program with "libpolycall.so.1: cannot open shared object file"
# None of them may crash (die from a signal). The fake libraries are built
# from tests/loader/stub_polycall.c into a temporary directory.
#
# Linux/ELF only (LD_LIBRARY_PATH); elsewhere exit 77 (SKIP).
set -eu

if [ "$#" -lt 1 ]; then
    echo "usage: $0 <loader-check-program> [repo-root]" >&2
    exit 2
fi
prog=$1
root=${2:-.}
case $prog in
    /*) ;;
    *) prog=$(pwd)/$prog ;;
esac

if [ "$(uname -s)" != Linux ]; then
    echo "SKIP: loader-error checks use LD_LIBRARY_PATH (Linux only)"
    exit 77
fi
cc=${CC:-cc}
if ! command -v "$cc" >/dev/null 2>&1; then
    echo "SKIP: C compiler '$cc' not found (needed to build the fake libraries)"
    exit 77
fi
libdir=$(pkg-config --variable=libdir polycall 2>/dev/null || true)
if [ -z "$libdir" ] || [ ! -e "$libdir/libpolycall.so.1" ]; then
    echo "FAIL: pkg-config cannot find the installed core (libpolycall.so.1)" >&2
    exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/polycall-loader.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/abi2" "$work/v10" "$work/none"
"$cc" -shared -fPIC -Wl,-soname,libpolycall.so.1 -DSTUB_ABI2 \
    -o "$work/abi2/libpolycall.so.1" "$root/tests/loader/stub_polycall.c"
"$cc" -shared -fPIC -Wl,-soname,libpolycall.so.1 \
    -o "$work/v10/libpolycall.so.1" "$root/tests/loader/stub_polycall.c"

echo "loader-errors: program $prog"
if command -v readelf >/dev/null 2>&1; then
    dyn=$(readelf -d "$prog")
    printf '%s\n' "$dyn" | grep -E 'NEEDED|RPATH|RUNPATH' | sed 's/^/loader-errors:   /' || true
    real=$(cd "$libdir" && pwd -P)
    case $(printf '%s\n' "$dyn" | grep -E 'RPATH|RUNPATH' || true) in
        *"$real"*)
            echo "FAIL: $prog has a run path to the installed core ($real): the" \
                 "missing-library check needs a program built without one" >&2
            exit 1 ;;
    esac
fi

pass=0
fail=0
out=""
rc=0
check() {
    if [ "$1" -eq 0 ]; then
        pass=$((pass + 1))
        echo "PASS $2"
    else
        fail=$((fail + 1))
        echo "FAIL $2"
        printf '%s\n' "$out" | sed 's/^/    | /'
    fi
}
has() {
    case $out in
        *"$1"*) return 0 ;;
        *) return 1 ;;
    esac
}
run_with() {
    set +e
    out=$(cd "$root" && LD_LIBRARY_PATH=$1 "$prog" 2>&1)
    rc=$?
    set -e
    printf '%s\n' "$out" | sed 's/^/    > /'
    echo "    exit=$rc"
}

echo "-- 1. real core ($libdir)"
run_with "$libdir"
ok=1
[ "$rc" -eq 0 ] && has "check_abi=0" && has "run_config=0" && has "call=-5" \
    && has "peer_open=0" && ok=0
check $ok "loader: the real core loads and passes the ABI check"

echo "-- 2. library that reports binding ABI 2"
run_with "$work/abi2"
ok=1
[ "$rc" -eq 0 ] && has "abi=2" && has "check_abi=-15" && has "POLYCALL_E_UNSUPPORTED" \
    && has "ABI 2" && ok=0
check $ok "loader: ABI 2 library -> check_abi raises E_UNSUPPORTED naming the ABI"
ok=1
has "run_config=-15" && has "call=-15" && has "peer_open=-15" && ok=0
check $ok "loader: ABI 2 library -> run_config / call / peer open refuse it (E_UNSUPPORTED), no crash"

echo "-- 3. old library without the binding ABI v1 symbols"
run_with "$work/v10"
ok=1
[ "$rc" -eq 127 ] && has "undefined symbol: polycall_" && ok=0
check $ok "loader: old 1.0 library -> dynamic loader names the missing symbol (exit 127, no crash)"

echo "-- 4. no library"
run_with "$work/none"
ok=1
[ "$rc" -eq 127 ] && has "libpolycall.so.1" && has "cannot open shared object file" && ok=0
check $ok "loader: missing library -> dynamic loader names libpolycall.so.1 (exit 127, no crash)"

echo "SUMMARY pass=$pass fail=$fail skip=0"
[ "$fail" -eq 0 ]
