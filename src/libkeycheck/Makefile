CC = gcc
CFLAGS = -fPIC -Wall -O2 -fvisibility=hidden
LDFLAGS = -shared -lcurl -lcrypto
TARGET = libkeycheck.so

SRCS = keycheck.c antidebug.c firebase.c
OBJS = $(SRCS:.c=.o)

PREFIX = /usr/local
LIBDIR = $(PREFIX)/lib
BINDIR = $(PREFIX)/bin

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

install: $(TARGET)
	install -d $(DESTDIR)$(LIBDIR)
	install -m 755 $(TARGET) $(DESTDIR)$(LIBDIR)/
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(DESTDIR)/../../scripts/keycheck.sh $(DESTDIR)$(BINDIR)/keycheck 2>/dev/null || true

uninstall:
	rm -f $(DESTDIR)$(LIBDIR)/$(TARGET)
	rm -f $(DESTDIR)$(BINDIR)/keycheck

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all install uninstall clean
