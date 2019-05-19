#!/bin/sh

# Debian package build script

set -e

# Set some directory locations
: ${SRCDIR:=$( realpath $( dirname "$0" ))}
: ${WORKDIR:=${SRCDIR}/work}
: ${DISTDIR:=${SRCDIR}/dist}

# Begin by ensuring we have up-to-date sources

if [ -z "${SKIP_FETCH}" ]; then
	make -C ${SRCDIR} fetch
fi

# Take the version from the mtime of the file
: ${VERSION:=$( date -r lib_mysqludf_sys.c +%Y%m%d )}

# Debian version information
: ${DEBVER:=1}

# Maintainer information
if [ -z "${MAINTAINER}" ]; then
	MAINTAINER="$(
		sed -ne '/^Maintainer:/ { s/^Maintainer: //; p; }' \
		${SRCDIR}/debian/control
	)"
fi

# Build flags
: ${BUILD_FLAGS:=-us -uc}

# Parse command-line arguments
: ${RECYCLE_ORIG:=n}
: ${CLEAN_DIST:=y}
: ${CLEAN_WORK:=y}
: ${APPEND_RELEASE:=y}
: ${DOCKER:=n}

while [ $# -gt 0 ]; do
	case "$1" in
		--work)
			WORKDIR="$2"
			shift
			;;
		--dist)
			DISTDIR="$2"
			shift
			;;
		--debver)
			DEBVER="$2"
			shift
			;;
		--recycle-orig)
			RECYCLE_ORIG=y
			CLEAN_DIST=n
			;;
		--docker)
			DOCKER=y
			;;
		--docker-image)
			DOCKER_IMAGE="$2"
			shift
			;;
		--no-append-release)
			APPEND_RELEASE=n
			;;
		--no-clean)
			case $2 in
				work)
					CLEAN_WORK=n
					;;
				dist)
					CLEAN_DIST=n
					;;
				*)
					echo "Unknown area $2"
					exit 1
					;;
			esac
			shift
			;;
	esac
	shift
done

if [ ${CLEAN_WORK} = y ]; then
	# Create a work directory
	[ ! -d ${WORKDIR} ] || rm -fr ${WORKDIR}
	mkdir ${WORKDIR}
else
	[ -d ${WORKDIR} ] || mkdir ${WORKDIR}
fi

if [ ${CLEAN_DIST} = y ]; then
	# Re-create the distribution directory
	[ ! -d ${DISTDIR} ] || rm -fr ${DISTDIR}
	mkdir ${DISTDIR}
else
	[ -d ${DISTDIR} ] || mkdir ${DISTDIR}
fi

# Are we using `docker` for this?
if [ "${DOCKER}" = y ]; then
	exec docker run --rm \
		-v ${SRCDIR}:/tmp/src \
		-v ${DISTDIR}:/tmp/dist \
		-e MAINTAINER="${MAINTAINER}" \
		-e VERSION=${VERSION} \
		-e DEBVER=${DEBVER} \
		-e BUILD_FLAGS="${BUILD_FLAGS}" \
		-e RECYCLE_ORIG="${RECYCLE_ORIG}" \
		-e WORKDIR=/tmp/work \
		-e DISTDIR=/tmp/dist \
		-e SRCDIR=/tmp/src \
		${DOCKER_IMAGE:-sjlongland/debian-pkg-build-env} \
		/usr/sbin/gosu $( id -u ):$( id -g ) \
		/bin/sh -xe /tmp/src/mkdeb.sh --no-clean dist
fi

# Package name and version
PACKAGE_VER=lib-mysqludf-sys-${VERSION}

if [ ${APPEND_RELEASE} = y ]; then
	# Append the Debian release information
	DEBVER=${DEBVER}$( \
		lsb_release -si | tr A-Z a-z \
	)$( \
		lsb_release -sr | tr . p \
	)
fi

if [ ${RECYCLE_ORIG} = n ] || \
		[ ! -f ${DISTDIR}/lib-mysqludf-sys_${VERSION}.orig.tar.xz ]
then
	# Create the package source directory
	mkdir ${WORKDIR}/${PACKAGE_VER}
	cp ${SRCDIR}/lib_mysqludf_sys.c ${SRCDIR}/Makefile \
		${WORKDIR}/${PACKAGE_VER}

	# Create the "original" tarball
	tar -C ${WORKDIR} \
		-cvf ${WORKDIR}/lib-mysqludf-sys_${VERSION}.orig.tar \
		${PACKAGE_VER}
	xz -9 ${WORKDIR}/lib-mysqludf-sys_${VERSION}.orig.tar
else
	# Copy the pre-made tarball to our work area
	cp ${DISTDIR}/lib-mysqludf-sys_${VERSION}.orig.tar.xz \
		${WORKDIR}

	# Unpack it here
	tar -C ${WORKDIR} -xJvf \
		${WORKDIR}/lib-mysqludf-sys_${VERSION}.orig.tar.xz
fi

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
