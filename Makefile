# ada-polycall -- GNAT + GPRbuild. The installed Polycall core (>= 1.1.0,
# binding ABI 1) is linked with -lpolycall; its library directory comes from
# pkg-config (PKG_CONFIG_PATH=<prefix>/lib/pkgconfig).
GPRBUILD ?= gprbuild
PKG_CONFIG ?= pkg-config

POLYCALL_LDFLAGS ?= $(shell $(PKG_CONFIG) --libs-only-L polycall 2>/dev/null)
GPRFLAGS ?= -p
GPRFLAGS += -XPOLYCALL_LDFLAGS="$(POLYCALL_LDFLAGS)"

TEST_BIN := build/ada_polycall_test
LOADER_BIN := build/loader_check
EXAMPLE_BIN := build/basic
ifeq ($(OS),Windows_NT)
TEST_BIN := $(TEST_BIN).exe
LOADER_BIN := $(LOADER_BIN).exe
EXAMPLE_BIN := $(EXAMPLE_BIN).exe
endif
VALGRIND ?= valgrind
VALGRIND_FLAGS ?= --error-exitcode=99 --leak-check=full --errors-for-leak-kinds=definite --track-origins=yes

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

# Missing library, old library without ABI v1 symbols, ABI mismatch
# (Linux; exit 77 = SKIP elsewhere). See tests/loader-errors.sh.
.PHONY: test-loader
test-loader: check-toolchain check-core
	$(GPRBUILD) $(GPRFLAGS) -R -P tests/loader_check.gpr
	sh tests/loader-errors.sh $(LOADER_BIN) .

# The real-core test under valgrind memcheck (exit 77 = SKIP without it).
.PHONY: memcheck
memcheck: build-tests
	@command -v $(VALGRIND) >/dev/null 2>&1 || { echo "SKIP: $(VALGRIND) not found"; exit 77; }
	sh tests/run-real.sh $(VALGRIND) $(VALGRIND_FLAGS) $(TEST_BIN) .

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
