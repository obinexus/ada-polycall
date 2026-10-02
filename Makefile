# ada-polycall -- GNAT + GPRbuild. The installed Polycall core (>= 1.1.0,
# binding ABI 1) is linked with -lpolycall; its library directory comes from
# pkg-config (PKG_CONFIG_PATH=<prefix>/lib/pkgconfig).
GPRBUILD ?= gprbuild
PKG_CONFIG ?= pkg-config

POLYCALL_LDFLAGS ?= $(shell $(PKG_CONFIG) --libs-only-L polycall 2>/dev/null)
GPRFLAGS ?= -p
GPRFLAGS += -XPOLYCALL_LDFLAGS="$(POLYCALL_LDFLAGS)"

TEST_BIN := build/ada_polycall_test
EXAMPLE_BIN := build/basic
ifeq ($(OS),Windows_NT)
TEST_BIN := $(TEST_BIN).exe
EXAMPLE_BIN := $(EXAMPLE_BIN).exe
endif

.DEFAULT_GOAL := all

.PHONY: all ada
all ada: check-toolchain
	$(GPRBUILD) $(GPRFLAGS) -P ada_polycall.gpr

# A missing toolchain is a SKIP (exit 77), never a success.
.PHONY: check-toolchain
check-toolchain:
	@command -v $(GPRBUILD) >/dev/null 2>&1 || { echo "SKIP: $(GPRBUILD) (GNAT) not found"; exit 77; }

.PHONY: check-core
check-core:
	@$(PKG_CONFIG) --exists 'polycall >= 1.1.0' || { echo "ada-polycall: pkg-config cannot find polycall >= 1.1.0; set PKG_CONFIG_PATH=<prefix>/lib/pkgconfig" >&2; exit 2; }

.PHONY: build-tests
build-tests: check-toolchain check-core
	$(GPRBUILD) $(GPRFLAGS) -P tests/ada_polycall_tests.gpr

# Real-core test incl. interop with the C CLI (exit 77 = SKIP without it).
.PHONY: test test-ada
test test-ada: build-tests
	sh tests/run-real.sh $(TEST_BIN) .

.PHONY: example
example: check-toolchain check-core
	$(GPRBUILD) $(GPRFLAGS) -P examples/ada_polycall_examples.gpr
	$(EXAMPLE_BIN)

.PHONY: verify-dry
verify-dry:
	sh scripts/verify-dry.sh

.PHONY: clean
clean:
	rm -rf build lib
