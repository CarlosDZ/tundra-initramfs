NAME = tundra-initramfs

all:

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

.PHONY: all install uninstall check check-unit clean


## Installation

PREFIX ?= /usr
SYSCONFDIR ?= /etc
DESTDIR ?=

LIBDIR = $(PREFIX)/lib/$(NAME)
KERNELDIR = $(PREFIX)/lib/kernel

install:
	install -d $(DESTDIR)$(PREFIX)/bin
	sed 's|/usr/lib/$(NAME)/init|$(LIBDIR)/init|' src/$(NAME) \
		>$(DESTDIR)$(PREFIX)/bin/$(NAME)
	chmod 755 $(DESTDIR)$(PREFIX)/bin/$(NAME)
	install -Dm755 src/init $(DESTDIR)$(LIBDIR)/init
	install -Dm755 src/50-$(NAME).install \
		$(DESTDIR)$(KERNELDIR)/install.d/50-$(NAME).install
	install -Dm644 src/install.conf \
		$(DESTDIR)$(KERNELDIR)/install.conf.d/50-$(NAME).conf
	install -Dm755 src/kernel.d/post-install \
		$(DESTDIR)$(SYSCONFDIR)/kernel.d/post-install/50-$(NAME)
	install -Dm755 src/kernel.d/post-remove \
		$(DESTDIR)$(SYSCONFDIR)/kernel.d/post-remove/50-$(NAME)
	install -Dm644 LICENSE $(DESTDIR)$(PREFIX)/share/licenses/$(NAME)/LICENSE

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(NAME)
	rm -rf $(DESTDIR)$(LIBDIR)
	rm -f $(DESTDIR)$(KERNELDIR)/install.d/50-$(NAME).install
	rm -f $(DESTDIR)$(KERNELDIR)/install.conf.d/50-$(NAME).conf
	rm -f $(DESTDIR)$(SYSCONFDIR)/kernel.d/post-install/50-$(NAME)
	rm -f $(DESTDIR)$(SYSCONFDIR)/kernel.d/post-remove/50-$(NAME)
	rm -rf $(DESTDIR)$(PREFIX)/share/licenses/$(NAME)
