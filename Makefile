## Tests

CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

BUILD = build
TEST_BUILD = $(BUILD)/test
FAKE_INIT = $(TEST_BUILD)/tools/fake-init

# Static: the root of the boot test has no libraries.
$(FAKE_INIT): tests/tools/fake-init.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -static -o $@ $<

check-unit:
	@rc=0; for t in tests/unit/t-*.sh; do echo "# $$t"; bash $$t || rc=1; done; exit $$rc

check: check-unit $(FAKE_INIT)
	@rc=0; for t in tests/boot/t-*.sh; do echo "# $$t"; bash $$t || rc=1; done; exit $$rc

clean:
	rm -rf $(BUILD)

.PHONY: check check-unit clean
