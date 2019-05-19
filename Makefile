# Source for lib_mysqludf_sys sources, we just need the one file.
RELEASE ?= master
SOURCE_URI=https://raw.githubusercontent.com/mysqludf/lib_mysqludf_sys/$(RELEASE)/lib_mysqludf_sys.c

# Debian put the required files in a `server` sub-directory, so we must
# do this rather than blindly trusting the CFLAGS that `mysql_config` emits.
MYSQL_INCLUDE ?= $(shell pkg-config --variable=includedir mariadb)
MYSQL_CFLAGS ?= -I$(MYSQL_INCLUDE)/server \
		-I$(MYSQL_INCLUDE) \
		-I$(MYSQL_INCLUDE)/server/private
MYSQL_LIBS ?= $(shell mysql_config --libs)

# For the plug-in directory, we get that from pkg-config
MYSQL_PLUGINDIR ?= $(shell pkg-config --variable=plugindir mariadb)

# BSD-compatible install tool
INSTALL ?= $(shell which install)

# Output file name
OUTPUT = lib_mysqludf_sys.so

# Source file name
SOURCE = lib_mysqludf_sys.c

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
	-rm -f $(OUTPUT)

realclean: clean
	-rm -f $(SOURCE)

$(OUTPUT): $(SOURCE)
	gcc -Wall $(MYSQL_CFLAGS) $(MYSQL_LIBS) \
		-shared $^ -o $@ -fPIC

$(SOURCE):
	wget -O $@ $(SOURCE_URI)
