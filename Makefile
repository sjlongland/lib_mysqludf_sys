# Source for lib_mysqludf_sys sources, we just need the one file.
RELEASE ?= master
SOURCE_URI=https://raw.githubusercontent.com/mysqludf/lib_mysqludf_sys/$(RELEASE)/lib_mysqludf_sys.c

MYSQL_INCLUDE ?= $(shell pkg-config --cflags libmariadb)
MYSQL_CFLAGS ?= $(shell pkg-config --cflags libmariadb) \
		-DHAVE_DLOPEN \
		-DSTANDARD
MYSQL_LIBS ?= $(shell mysql_config --libs)

# For the plug-in directory, we get that from pkg-config
MYSQL_PLUGINDIR ?= $(shell pkg-config --variable=plugindir mariadb)

# BSD-compatible install tool
INSTALL ?= $(shell which install)

# Output file name
OUTPUT = lib_mysqludf_sys.so

# Source file name
SOURCE = lib_mysqludf_sys.c

# Object files
OBJECTS = $(patsubst %.c,%.o,$(SOURCE))

# Version
VERSION = $(shell date -r lib_mysqludf_sys.c +%Y%m%d)

.PHONY: all fetch install clean realclean sourcetar

all: $(OUTPUT)
fetch: $(SOURCE)

install: all
	$(INSTALL) -o root -g root -m 0755 -d $(DESTDIR)$(MYSQL_PLUGINDIR)
	$(INSTALL) -o root -g root -m 0755 -t $(DESTDIR)$(MYSQL_PLUGINDIR) \
		$(OUTPUT)

clean:
	-rm -f $(OUTPUT) $(OBJECTS)

realclean: clean
	-rm -f $(SOURCE)

$(OUTPUT): $(OBJECTS)
	gcc -Wl,--no-as-needed -Wall $(MYSQL_CFLAGS) $(MYSQL_LIBS) \
		-shared -o $@ -fPIC $^

.c.o:
	gcc -Wall $(MYSQL_CFLAGS) -c $^ -o $@

$(SOURCE): $(SOURCE).orig
	sed 	-e '/^#include <m_ctype.h>/ s/m_ctype/mariadb_ctype/' \
		-e '/^#include <m_string.h>/ d' \
		-e '/^#include <my_global.h>/ d' \
		-e '/^#include <stdlib.h>/ i #include <stdio.h>' \
		$< > $@

$(SOURCE).orig:
	wget -O $@ $(SOURCE_URI)
