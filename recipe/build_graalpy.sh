#!/bin/bash

set -exo pipefail

# set up paths for mx build
export MX_DIR=$SRC_DIR/mx
export PATH=$PATH:$MX_DIR
export MX_PRIMARY_SUITE_PATH=$SRC_DIR/graal/vm

# mx ninja build templates hardcode ar, gcc, g++; symlink these to the conda
# compilers
ln -sf $AR $MX_DIR/ar
ln -sf $CC $MX_DIR/gcc
ln -sf $CXX $MX_DIR/g++

# sulong toolchain wrappers are not recognized and cmake is making trouble
# getting them to compile anything. Make sure to use the sysroot flag, and
# symlink build environment objects
export CFLAGS="$CFLAGS --sysroot $CONDA_BUILD_SYSROOT"
export CXXFLAGS="$CXXFLAGS --sysroot $CONDA_BUILD_SYSROOT"
export LDFLAGS="$LDFLAGS --sysroot $CONDA_BUILD_SYSROOT"
export CPATH="$BUILD_PREFIX/include"
export LIBRARY_PATH="$BUILD_PREFIX/lib"
if [ -z "${MACOS}" ]; then
    for filename in $CONDA_BUILD_SYSROOT/../lib/libgcc_s.so*; do
        ln -s $filename $CONDA_BUILD_SYSROOT/lib/
    done
    ln -s $CONDA_BUILD_SYSROOT/../../lib/gcc/x86_64-conda-linux-gnu/*/crtbegin.o $CONDA_BUILD_SYSROOT/lib/
    ln -s $CONDA_BUILD_SYSROOT/../../lib/gcc/x86_64-conda-linux-gnu/*/crtbeginS.o $CONDA_BUILD_SYSROOT/lib/
    ln -s $CONDA_BUILD_SYSROOT/../../lib/gcc/x86_64-conda-linux-gnu/*/crtend.o $CONDA_BUILD_SYSROOT/lib/
    ln -s $CONDA_BUILD_SYSROOT/../../lib/gcc/x86_64-conda-linux-gnu/*/crtendS.o $CONDA_BUILD_SYSROOT/lib/
    ln -s $CONDA_BUILD_SYSROOT/../../lib/gcc/x86_64-conda-linux-gnu/*/libgcc.a $CONDA_BUILD_SYSROOT/lib/
fi

# git init an empty repo inside graal, to force mx to pick graal download as
# siblings dir
git init $SRC_DIR/graal
git -C $SRC_DIR/graal config --local user.name "none"
git -C $SRC_DIR/graal config --local user.email "none@example.org"
git -C $SRC_DIR/graal commit --allow-empty -m "dummy commit"

# set correct jdk paths
if [ -z "${MACOS}" ]; then
    export JAVA_HOME=$SRC_DIR/labsjdk
else
    export JAVA_HOME=$SRC_DIR/labsjdk/Contents/Home
fi

# run the build
mx -p $SRC_DIR/graal/vm/ --env ce-python graalvm-show
mx -p $SRC_DIR/graal/vm/ --env ce-python build --dep $GRAALPY_DISTRIBUTION

# move the standalone build artifact into $PREFIX
STANDALONE=`mx -p $SRC_DIR/graal/vm/ --env ce-python standalone-home --type $GRAALPY_DISTRIBUTION_TYPE python`
cp -r $STANDALONE/* $PREFIX

rm -rf "$PREFIX/lib/sulong"
rm -rf "$PREFIX/lib/llvm-toolchain"

# license is packaged by the build process
cat $PREFIX/LICENSE_GRAALPY.txt $PREFIX/THIRD_PARTY_LICENSE_GRAALPY.txt > $SRC_DIR/LICENSE_GRAALPY.txt
rm $PREFIX/LICENSE_GRAALPY.txt $PREFIX/THIRD_PARTY_LICENSE_GRAALPY.txt

# ensure python{PY_VERSION} launcher exists, even though graalpy only ships "python" and "python3"
if [ ! -e "${PREFIX}/bin/python${PY_VERSION}" ]; then
    ln -s "${PREFIX}/bin/graalpy" "${PREFIX}/bin/python${PY_VERSION}"
fi
