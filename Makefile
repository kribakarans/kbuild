
# GNU Makefile for KBuild

TARGET := kbuild
PREFIX := $(HOME)/.local
BINDIR := $(PREFIX)/bin
ETCDIR := $(PREFIX)/etc/$(TARGET)

SRCDIR := src
SRCS   := $(SRCDIR)/$(TARGET).sh

all:
	bash -n $(SRCS)

install:
	@echo "Oops! Need to implement."

install-local:
	mkdir -p $(DESTDIR)$(BINDIR)
	mkdir -p $(DESTDIR)$(ETCDIR)
	install -D $(SRCS) $(DESTDIR)$(BINDIR)/$(TARGET)
	cp -f share/kbuild-checkpoints.in $(DESTDIR)$(ETCDIR)

uninstall-local:
	rm -rf $(DESTDIR)$(ETCDIR)
	rm -f  $(DESTDIR)$(BINDIR)/$(TARGET)

clean:
	@#Nothing to be done

.PHONY: all clean install install-local uninstall uninstall-local
