#! /bin/bash
set -e

absdir="$(cd "${0%/*}" 2>/dev/null; echo "$PWD")"
abspath="${absdir}/"${0##*/}""

if [ -z "${PROJECT}" ]; then
  echo "I need a project to build!"
  exit 1
fi

# Setup environment
# Environment setup - things that can be overridden by the scripts
BUILD_ARCH=${BUILD_ARCH:-x86_64-pc-linux}
HOST_ARCH=${HOST_ARCH:-${BUILD_ARCH}}
TARGET_ARCH=${TARGET_ARCH:-${HOST_ARCH}}

REPOROOT=${REPOROOT:-/opt/src/repos}
BUILDROOT=${BUILDROOT:-/opt/build/${HOST_ARCH}}

BUILDDIR=${BUILDDIR:-${BUILDROOT}/${PROJECT}}
STAGEDIR=${STAGEDIR:-${BUILDROOT}/staging/${PROJECT}}
TARDIR=${TARDIR:-${BUILDROOT}/tarballs}

PREFIX=${PREFIX:-/opt/devtools}
EXECPREFIX=${EXECPREFIX:-${PREFIX}/${HOST_ARCH}}

# My machine is a core2 which works best with 3 subprocs
MAKEPARALLELFLAGS=${MAKEPARELLELFLAGS:--j3}
# Project specific settings
. "${absdir}/${PROJECT}.setup"

# Get the version into project_version
project_getversion

echo Building ${PROJECT} ${project_version}

# Run from clean source tree?
if [ x"${REBUILD_CLEAN}" = xyes ]; then
  project_cleansource
  # Clean build directory
  rm -rf ${BUILDDIR}
fi

# Make and change to build directory
mkdir -p ${BUILDDIR}
cd ${BUILDDIR}

if [ ! -f config.status -o x"${RECONFIGURE}" = xyes ]; then
  # DEFAULT configuration flags passed to configure
  defaultconfigflags="--prefix=${PREFIX} \
    --exec-prefix=${EXECPREFIX} \
    --mandir=\${datarootdir}/man \
    --infodir=\${datarootdir}/man \
    --localedir=\${datarootdir}/locale \
    --includedir=\${exec_prefix}/include \
    --enable-silent-rules \
    --disable-option-checking \
    --build=${BUILD_ARCH} \
    --host=${HOST_ARCH} \
    --target=${TARGET_ARCH}"

  # Mainly for libelf.  Note that libgmp can only be built
  # shared or static.  Our lib*.setup generally uses
  # sharedonly
  libraryconfigflags=
  if [ x"${project_static_libs_only}" = xyes ]; then
      libraryconfigflags="--enable-static=yes --enable-shared=no"
  elif [ x"${project_shared_libs_only}" = xyes ]; then
      libraryconfigflags="--enable-static=no --enable-shared=yes"
  fi
  # Otherwise, just use the defaults ...

  ${projsource}/configure   \
      ${defaultconfigflags} \
      ${libraryconfigflags} \
      ${projectconfigflags} \
      ${EXTRACONFIGFLAGS}
fi

# Make
make ${MAKEPARALLELFLAGS} \
  LIBTOOLFLAGS=--quiet \
  ${buildmakeflags}

# Clean staging directory
rm -rf ${STAGEDIR}
# Install into staging directory
make install \
  LIBTOOLFLAGS=--quiet \
  DESTDIR=${STAGEDIR} \
  ${installmakeflags}

# Post staging cleanup (remove .la, etc)
cd ${STAGEDIR}${PREFIX}
find . -name \*.la -delete

# Project specific poststage cleanup
project_poststage

# Skip tar creation?
if [ ! x"${SKIPTAR}" = xyes ]; then
  # create the build tarball
  cd ${STAGEDIR}/${PREFIX}
  mkdir -p ${TARDIR}
  tar vcjf ${TARDIR}/${PROJECT}-${project_version}.tar.bz2 *

  # Really install? Only useful if tarball created...
  if [ x"${DOINSTALL}" = xyes ]; then
    cd ${PREFIX}
    sudo tar xvjf ${TARDIR}/${PROJECT}-${project_version}.tar.bz2
    sudo ldconfig
  fi
fi
