#!/bin/sh

# Debian package build script

set -e

# Begin by ensuring we have up-to-date sources

if [ -z "${SKIP_FETCH}" ]; then
	make fetch
fi

# Set some directory locations
: ${SRCDIR:=$( realpath $( dirname "$0" ))}
: ${WORKDIR:=${SRCDIR}/work}
: ${DISTDIR:=${SRCDIR}/dist}

[ ! -d ${WORKDIR} ] || rm -fr ${WORKDIR}
mkdir ${WORKDIR}

[ ! -d ${DISTDIR} ] || rm -fr ${DISTDIR}
mkdir ${DISTDIR}

# Take the version from the mtime of the file
: ${VERSION:=$( date -r lib_mysqludf_sys.c +%Y%m%d )}

# Debian version information
: ${DEBVER:=1}

# Maintainer information
: ${MAINTAINER:=$( sed -ne '/^Maintainer:/ { s/^Maintainer: //; p; }' \
	${SRCDIR}/debian/control )}

# Build flags
: ${BUILD_FLAGS:=-us -uc}

# Package name and version
PACKAGE_VER=lib-mysqludf-sys-${VERSION}

# Create the package source directory
mkdir ${WORKDIR}/${PACKAGE_VER}
cp lib_mysqludf_sys.c Makefile ${WORKDIR}/${PACKAGE_VER}

# Create the "original" tarball
tar -C ${WORKDIR} \
	-cvf ${WORKDIR}/lib-mysqludf-sys_${VERSION}.orig.tar \
	${PACKAGE_VER}
xz -9 ${WORKDIR}/lib-mysqludf-sys_${VERSION}.orig.tar

# Now put the Debian package files in
tar -C ${SRCDIR} -cf - debian \
	| tar -C ${WORKDIR}/${PACKAGE_VER} -xf -

# Generate the changelog
cat > ${WORKDIR}/${PACKAGE_VER}/debian/changelog <<EOF
lib-mysqludf-sys (${VERSION}-${DEBVER}) unstable; urgency=low

  * Automatic build from source
 
 -- ${MAINTAINER}  $( date -R )
EOF

# Build the package
( cd ${WORKDIR}/${PACKAGE_VER} && dpkg-buildpackage ${BUILD_FLAGS} )

# Clean up the source tree
rm -fr ${WORKDIR}/${PACKAGE_VER}

# Move out the distributed files
mv ${WORKDIR}/* ${DISTDIR}
