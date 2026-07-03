CC ?= gcc
AR ?= ar
GNATMAKE ?= gnatmake
GPRBUILD ?= gprbuild

CPPFLAGS ?=
CPPFLAGS += -Iinclude -Igenerated
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic

BUILD_DIR := build
ADA_BUILD_DIR := $(BUILD_DIR)/ada
ADA_EXAMPLE_BUILD_DIR := $(BUILD_DIR)/ada-example
LIB_DIR := lib
ADAPTER_OBJ := $(BUILD_DIR)/ada_polycall.o
MOCK_OBJ := $(BUILD_DIR)/polycall_ffi_mock.o
STATIC_LIB := $(LIB_DIR)/libada_polycall_ffi.a
NATIVE_TEST_BIN := $(BUILD_DIR)/ada_polycall_adapter_test
ADA_TEST_BIN := $(BUILD_DIR)/ada_polycall_smoke
ADA_EXAMPLE_BIN := $(BUILD_DIR)/basic

ifeq ($(OS),Windows_NT)
EXE_EXT := .exe
NATIVE_TEST_BIN := $(NATIVE_TEST_BIN)$(EXE_EXT)
ADA_TEST_BIN := $(ADA_TEST_BIN)$(EXE_EXT)
ADA_EXAMPLE_BIN := $(ADA_EXAMPLE_BIN)$(EXE_EXT)
endif

.DEFAULT_GOAL := all

.PHONY: all
all: $(STATIC_LIB)

$(BUILD_DIR) $(ADA_BUILD_DIR) $(ADA_EXAMPLE_BUILD_DIR) $(LIB_DIR):
ifeq ($(OS),Windows_NT)
	@if not exist "$@" mkdir "$@"
else
	@mkdir -p $@
endif

$(ADAPTER_OBJ): src/ada_polycall.c include/ada_polycall.h generated/polycall/polycall_ffi.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

$(MOCK_OBJ): tests/polycall_ffi_mock.c tests/polycall_ffi_mock.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) -Itests $(CFLAGS) -c $< -o $@

$(STATIC_LIB): $(ADAPTER_OBJ) | $(LIB_DIR)
	$(AR) rcs $@ $^

.PHONY: ada
ada:
	$(GPRBUILD) -P ada_polycall.gpr

$(NATIVE_TEST_BIN): src/ada_polycall.c tests/polycall_ffi_mock.c tests/ada_polycall_adapter_test.c | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) -Itests $(CFLAGS) $^ -o $@

.PHONY: test test-native
test: test-native

test-native: $(NATIVE_TEST_BIN)
	$(NATIVE_TEST_BIN)

.PHONY: test-ada
test-ada: $(ADAPTER_OBJ) $(MOCK_OBJ) | $(ADA_BUILD_DIR)
	$(GNATMAKE) -q -gnat12 -Isrc -D $(ADA_BUILD_DIR) \
		-o $(ADA_TEST_BIN) tests/ada_polycall_smoke.adb \
		-largs $(ADAPTER_OBJ) $(MOCK_OBJ)
	$(ADA_TEST_BIN)

.PHONY: example
example: $(ADAPTER_OBJ) | $(ADA_EXAMPLE_BUILD_DIR)
ifeq ($(OS),Windows_NT)
	@if "$(strip $(POLYCALL_LDFLAGS))"=="" (echo Set POLYCALL_LDFLAGS to the libpolycall v1.5 linker flags & exit /b 2)
else
	@test -n "$(POLYCALL_LDFLAGS)" || (echo "Set POLYCALL_LDFLAGS to the libpolycall v1.5 linker flags" && exit 2)
endif
	$(GNATMAKE) -q -gnat12 -Isrc -D $(ADA_EXAMPLE_BUILD_DIR) \
		-o $(ADA_EXAMPLE_BIN) examples/basic.adb \
		-largs $(ADAPTER_OBJ) $(POLYCALL_LDFLAGS)
	$(ADA_EXAMPLE_BIN)

.PHONY: verify-dry
verify-dry:
ifeq ($(OS),Windows_NT)
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-dry.ps1
else
	sh scripts/verify-dry.sh
endif

.PHONY: clean
clean:
ifeq ($(OS),Windows_NT)
	@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
	@if exist "$(LIB_DIR)" rmdir /s /q "$(LIB_DIR)"
else
	rm -rf $(BUILD_DIR) $(LIB_DIR)
endif

-include $(ADAPTER_OBJ:.o=.d)
