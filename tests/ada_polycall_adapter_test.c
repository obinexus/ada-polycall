#include "ada_polycall.h"
#include "polycall_ffi_mock.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    const char *config_path = "ada-polycallrc";
    int status;

    polycall_ffi_mock_reset();
    status = ada_polycall_run_config(config_path);

    assert(status == 0);
    assert(polycall_ffi_mock_call_count() == 1);
    assert(polycall_ffi_mock_last_run() == 1);
    assert(strcmp(polycall_ffi_mock_last_config(), config_path) == 0);

    polycall_ffi_mock_return_status(37);
    status = ada_polycall_run_config(config_path);

    assert(status == 37);
    assert(polycall_ffi_mock_call_count() == 2);

    puts("ada-polycall native adapter test: PASS");
    return 0;
}
