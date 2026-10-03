/*
 * Loader-error fixture for tests/loader-errors.sh -- NOT a mock of the core
 * and never used by the real-core tests. It is compiled into a fake
 * libpolycall.so.1 to show what the binding does with a wrong library:
 *
 *   cc -shared -fPIC -Wl,-soname,libpolycall.so.1 stub_polycall.c
 *       an "old 1.0 library": only the 1.0 symbols, none of binding ABI v1
 *   cc -shared -fPIC -Wl,-soname,libpolycall.so.1 -DSTUB_ABI2 stub_polycall.c
 *       every ABI v1 symbol, but polycall_ffi_abi_version() returns 2
 *       (every other call fails with POLYCALL_E_INTERNAL)
 */
#include <stddef.h>
#include <stdint.h>

/* the 1.0 surface (signatures reduced to what a loader needs) */
const char *polycall_get_version(void) { return "1.0.0-loader-stub"; }
int polycall_init_with_config(void **ctx, const void *config) { (void)ctx; (void)config; return 4; }
void polycall_cleanup(void *ctx) { (void)ctx; }
const char *polycall_get_last_error(void *ctx) { (void)ctx; return "loader stub"; }

#ifdef STUB_ABI2
#define STUB_FAIL (-18) /* POLYCALL_E_INTERNAL */

int polycall_ffi_abi_version(void) { return 2; }
int polycall_ffi_version(char *buf, int len)
{
    static const char v[] = "2.0.0-loader-stub";
    int i;
    if (len < 0) return -1;
    for (i = 0; buf && i < len - 1 && v[i]; ++i) buf[i] = v[i];
    if (buf && len > 0) buf[i] = '\0';
    return (int)sizeof v - 1;
}
const char *polycall_strerror(int status)
{
    return status == -15 ? "POLYCALL_E_UNSUPPORTED: valid, but not supported by this build"
                         : "POLYCALL_E_INTERNAL: binding ABI 2 loader stub";
}
int polycall_last_error(char *buf, size_t cap) { if (buf && cap) buf[0] = '\0'; return 0; }
int polycall_ffi_run_config(const char *p, int run) { (void)p; (void)run; return STUB_FAIL; }
int polycall_ffi_describe(const char *p, char *b, int l) { (void)p; (void)b; (void)l; return STUB_FAIL; }
int polycall_call(const char *e, const char *s, const char *o, const char *i, uint32_t t,
                  char *out, size_t cap, size_t *len)
{ (void)e; (void)s; (void)o; (void)i; (void)t; (void)out; (void)cap; (void)len; return STUB_FAIL; }
int polycall_peer_open(const char *n, const char *b, const char *a, int32_t *h)
{ (void)n; (void)b; (void)a; if (h) *h = 0; return STUB_FAIL; }
int polycall_peer_close(int32_t h) { (void)h; return STUB_FAIL; }
int polycall_peer_endpoint(int32_t h, char *b, size_t c) { (void)h; (void)b; (void)c; return STUB_FAIL; }
int polycall_peer_node_id(int32_t h, char *b, size_t c) { (void)h; (void)b; (void)c; return STUB_FAIL; }
int polycall_peer_register(int32_t h, const char *p, const char *e) { (void)h; (void)p; (void)e; return STUB_FAIL; }
int polycall_peer_unregister(int32_t h, const char *p) { (void)h; (void)p; return STUB_FAIL; }
int polycall_peer_list(int32_t h, char *b, size_t c, size_t *l) { (void)h; (void)b; (void)c; (void)l; return STUB_FAIL; }
int polycall_peer_ping(int32_t h, const char *p, uint32_t t) { (void)h; (void)p; (void)t; return STUB_FAIL; }
int polycall_peer_send(int32_t h, const char *p, const void *d, size_t n, const char *m, uint32_t t)
{ (void)h; (void)p; (void)d; (void)n; (void)m; (void)t; return STUB_FAIL; }
int polycall_peer_recv(int32_t h, uint32_t t, char *s, size_t sc, char *m, size_t mc, void *p,
                       size_t pc, size_t *pl)
{ (void)h; (void)t; (void)s; (void)sc; (void)m; (void)mc; (void)p; (void)pc; (void)pl; return STUB_FAIL; }
int polycall_peer_cancel(int32_t h) { (void)h; return STUB_FAIL; }
int polycall_peer_health(int32_t h, char *b, size_t c, size_t *l) { (void)h; (void)b; (void)c; (void)l; return STUB_FAIL; }
#endif
