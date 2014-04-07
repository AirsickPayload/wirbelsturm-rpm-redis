#!/usr/bin/env bash
#
# This script packages Redis release as RHEL6/CentOS6 RPM using fpm.

### CONFIGURATION BEGINS ###

MAINTAINER="<michael@michael-noll.com>"
INSTALL_BASE_DIR=/usr

# Normally you do not need to change this variable
DOWNLOAD_ROOT_URL=http://download.redis.io/releases

# License download URL
LICENSE_URL=https://raw.github.com/antirez/redis/unstable/COPYING

### CONFIGURATION ENDS ###

SOFTWARE="redis"

function print_usage() {
    myself=`basename $0`
    echo "Usage: $myself <version>"
    echo
    echo "Examples:"
    echo "  \$ $myself 2.8.8"
}

if [ $# -ne 1 ]; then
    print_usage
    exit 1
fi

VERSION="$1"

echo "Building an RPM for Redis release version $VERSION ..."

# Prepare environment
OLD_PWD=`pwd`
BUILD_DIR=`mktemp -d /tmp/${SOFTWARE}-build.XXXXXXXXXX`
cd $BUILD_DIR

cleanup_and_exit() {
  local exitCode=$1
  rm -rf $BUILD_DIR
  cd $OLD_PWD
  exit $exitCode
}

# Configure download location
TARBALL=${SOFTWARE}-${VERSION}.tar.gz
DOWNLOAD_URL=$DOWNLOAD_ROOT_URL/$TARBALL

# Download and build
wget $DOWNLOAD_URL || cleanup_and_exit $?
tar -xzf $TARBALL || cleanup_and_exit $?
cd ${SOFTWARE}-${VERSION} || cleanup_and_exit $?
make || cleanup_and_exit $?
make test || cleanup_and_exit $?

SANDBOX_INSTALL_DIR=$BUILD_DIR/installdir
BIN_DIR=${SANDBOX_INSTALL_DIR}${INSTALL_BASE_DIR}/bin
mkdir -p $BIN_DIR
SBIN_DIR=${SANDBOX_INSTALL_DIR}${INSTALL_BASE_DIR}/sbin
mkdir -p $SBIN_DIR
ETC_DIR=$SANDBOX_INSTALL_DIR/etc/$SOFTWARE
mkdir -p $ETC_DIR
DOC_DIR=$SANDBOX_INSTALL_DIR/usr/share/doc/redis
mkdir -p $DOC_DIR
cp `find src/ -perm /u+x -type f | egrep -v "(redis-server|mkreleasehdr.sh)$"` $BIN_DIR || cleanup_and_exit $?
cp src/redis-server $SBIN_DIR || cleanup_and_exit $?
cp `find . -maxdepth 1 -name "*conf"` $ETC_DIR || cleanup_and_exit $?
cd $DOC_DIR || cleanup_and_exit $?
wget --no-check-certificate $LICENSE_URL || cleanup_and_exit $?
cd $SANDBOX_INSTALL_DIR

fpm -s dir -t rpm -a all \
    --name ${SOFTWARE} \
    --version ${VERSION} \
    --iteration "1.miguno" \
    -C $SANDBOX_INSTALL_DIR/ \
    --maintainer "$MAINTAINER" \
    --vendor Redis.io \
    --url http://redis.io/ \
    --description "Redis is an advanced key-value store.\nIt is often referred to as a data structure server since keys can contain strings, hashes, lists, sets and sorted sets." \
    -p $OLD_PWD/${SOFTWARE}-VERSION.el6.ARCH.rpm \
    -d "glibc" \
    -a "x86_64" \
    . || cleanup_and_exit $?

echo "You can verify the proper creation of the RPM file with:"
echo "  \$ rpm -qpi ${SOFTWARE}-*.rpm    # show package info"
echo "  \$ rpm -qpR ${SOFTWARE}-*.rpm    # show package dependencies"
echo "  \$ rpm -qpl ${SOFTWARE}-*.rpm    # show contents of package"

# Clean up
cleanup_and_exit $?
