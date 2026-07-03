#include "polycall_ffi_mock.h"

#include <string.h>

static int mock_status;
static int mock_calls;
static int mock_run;
static char mock_config[1024];

int polycall_ffi_run_config(const char *config_path, int run) {
    ++mock_calls;
    mock_run = run;

    if (config_path) {
        strncpy(mock_config, config_path, sizeof(mock_config) - 1);
        mock_config[sizeof(mock_config) - 1] = '\0';
    } else {
        mock_config[0] = '\0';
    }

    return mock_status;
}

void polycall_ffi_mock_reset(void) {
    mock_status = 0;
    mock_calls = 0;
    mock_run = 0;
    mock_config[0] = '\0';
}

void polycall_ffi_mock_return_status(int status) {
    mock_status = status;
}

int polycall_ffi_mock_call_count(void) {
    return mock_calls;
}

int polycall_ffi_mock_last_run(void) {
    return mock_run;
}

const char *polycall_ffi_mock_last_config(void) {
    return mock_config;
}
