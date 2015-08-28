#!/bin/bash

cd "$(dirname "$0")"
top="$(pwd)"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

BOOST_SOURCE_DIR="boost"
BOOST_VERSION="1.59.0"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

# Libraries on which we depend - please keep alphabetized for maintenance
BOOST_LIBS=(atomic context coroutine date_time filesystem iostreams program_options \
            regex signals system thread)

BOOST_BJAM_OPTIONS="--layout=tagged -sNO_BZIP2=1 ${BOOST_LIBS[*]/#/--with-}"

# Optionally use this function in a platform build to SUPPRESS running unit
# tests on one or more specific libraries: sadly, it happens that some
# libraries we care about might fail their unit tests on a particular platform
# for a particular Boost release.
# Usage: suppress_tests date_time regex
function suppress_tests {
  set +x
  for lib
  do for ((i=0; i<${#BOOST_LIBS[@]}; ++i))
     do if [[ "${BOOST_LIBS[$i]}" == "$lib" ]]
        then unset BOOST_LIBS[$i]
             # From -x trace output, it appears that the above 'unset' command
             # doesn't immediately close the gaps in the BOOST_LIBS array. In
             # fact it seems that although the count ${#BOOST_LIBS[@]} is
             # decremented, there's a hole at [$i], and subsequent elements
             # remain at their original subscripts. Reset the array: remove
             # any such holes.
             BOOST_LIBS=("${BOOST_LIBS[@]}")
             break
        fi
     done
  done
  echo "BOOST_LIBS=${BOOST_LIBS[*]}"
  set -x
}

BOOST_BUILD_SPAM="-d2 -d+4"             # -d0 is quiet, "-d2 -d+4" allows compilation to be examined

top="$(pwd)"
cd "$BOOST_SOURCE_DIR"
bjam="$(pwd)/bjam"
stage="$(pwd)/stage"

[ -f "$stage"/packages/include/zlib/zlib.h ] || fail "You haven't installed the zlib package yet."

echo "${BOOST_VERSION}" > "${stage}/VERSION.txt"

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
    # Bjam doesn't know about cygwin paths, so convert them!
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage_lib="${stage}"/lib
stage_release="${stage_lib}"/release
stage_debug="${stage_lib}"/debug
mkdir -p "${stage_release}"
mkdir -p "${stage_debug}"

# Restore all .sos
restore_sos ()
{
    for solib in "${stage}"/packages/lib/debug/libz.so*.disable "${stage}"/packages/lib/release/libz.so*.disable; do
        if [ -f "$solib" ]; then
            mv -f "$solib" "${solib%.disable}"
        fi
    done
}

# Restore all .dylibs
restore_dylibs ()
{
    for dylib in "$stage/packages/lib"/{debug,release}/*.dylib.disable; do
        if [ -f "$dylib" ]; then
            mv "$dylib" "${dylib%.disable}"
        fi
    done
}

case "$AUTOBUILD_PLATFORM" in

    "windows")
        mkdir -p "$stage/packages/bin"
        mkdir -p "$stage/packages/lib"
        cp -a $stage/packages/lib/debug/*d.lib $stage/packages/lib/
        cp -a $stage/packages/lib/release/*.lib $stage/packages/lib/
        INCLUDE_PATH="$(cygpath -m "${stage}"/packages/include)"
        ZLIB_RELEASE_PATH="$(cygpath -m "${stage}"/packages/lib/release)"
        ZLIB_DEBUG_PATH="$(cygpath -m "${stage}"/packages/lib/debug)"

        # Odd things go wrong with the .bat files:  branch targets
        # not recognized, file tests incorrect.  Inexplicable but
        # dropping 'echo on' into the .bat files seems to help.
        cmd.exe /C bootstrap.bat vc14

        WINDOWS_BJAM_OPTIONS="--toolset=msvc-14.0 -j8 \
            --abbreviate-paths \
            include=$INCLUDE_PATH \
            -sZLIB_INCLUDE=$INCLUDE_PATH/zlib \
            address-model=32 architecture=x86 \
            $BOOST_BJAM_OPTIONS"

        DEBUG_BJAM_OPTIONS="$WINDOWS_BJAM_OPTIONS -sZLIB_LIBPATH=$ZLIB_DEBUG_PATH -sZLIB_LIBRARY_PATH=$ZLIB_DEBUG_PATH -sZLIB_NAME=zlibd -sZLIB_BINARY=zlib"
        "${bjam}" link=static variant=debug --abbreviate-paths \
            --prefix="${stage}" --libdir="${stage_debug}" $DEBUG_BJAM_OPTIONS $BOOST_BUILD_SPAM stage


        suppress_tests thread 

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"$blib"/test
                    # link=static
                    "${bjam}" variant=debug --hash \
                        --prefix="${stage}" --libdir="${stage_debug}" \
                        $DEBUG_BJAM_OPTIONS $BOOST_BUILD_SPAM -a -q
                popd
            done
        fi

        # Move the debug libs first then clean to avoid tainting release build
        mv "${stage_lib}"/*-gd.lib "${stage_debug}"
        "${bjam}" --clean
        rm bin.v2/project-cache.jam

        RELEASE_BJAM_OPTIONS="$WINDOWS_BJAM_OPTIONS -sZLIB_LIBPATH=$ZLIB_RELEASE_PATH -sZLIB_LIBRARY_PATH=$ZLIB_RELEASE_PATH -sZLIB_NAME=zlib -sZLIB_BINARY=zlib"
        "${bjam}" link=static variant=release --abbreviate-paths \
            --prefix="${stage}" --libdir="${stage_release}" $RELEASE_BJAM_OPTIONS $BOOST_BUILD_SPAM stage

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"$blib"/test
                    # link=static
                    "${bjam}" variant=release --hash \
                        --prefix="${stage}" --libdir="${stage_release}" \
                        $RELEASE_BJAM_OPTIONS $BOOST_BUILD_SPAM -a -q
                popd
            done
        fi

        # Move release libs
        mv "${stage_lib}"/*.lib "${stage_release}"
     ;;
     "windows64")
        mkdir -p "$stage/packages/bin64"
        mkdir -p "$stage/packages/lib64"
        cp -a $stage/packages/lib/debug/*d.lib $stage/packages/lib64/
        cp -a $stage/packages/lib/release/*.lib $stage/packages/lib64/
        INCLUDE_PATH="$(cygpath -m "${stage}"/packages/include)"
        ZLIB_RELEASE_PATH="$(cygpath -m "${stage}"/packages/lib/release)"
        ZLIB_DEBUG_PATH="$(cygpath -m "${stage}"/packages/lib/debug)"

        # Odd things go wrong with the .bat files:  branch targets
        # not recognized, file tests incorrect.  Inexplicable but
        # dropping 'echo on' into the .bat files seems to help.
        cmd.exe /C bootstrap.bat vc14

        WINDOWS_BJAM_OPTIONS="--toolset=msvc-14.0 -j8 \
            include=$INCLUDE_PATH \
            -sZLIB_INCLUDE=$INCLUDE_PATH/zlib \
            address-model=64 architecture=x86 \
            $BOOST_BJAM_OPTIONS"

        DEBUG_BJAM_OPTIONS="$WINDOWS_BJAM_OPTIONS -sZLIB_LIBPATH=$ZLIB_DEBUG_PATH -sZLIB_LIBRARY_PATH=$ZLIB_DEBUG_PATH -sZLIB_NAME=zlibd -sZLIB_BINARY=zlibd"
        "${bjam}" link=static variant=debug --abbreviate-paths \
            --prefix="${stage}" --libdir="${stage_debug}" $DEBUG_BJAM_OPTIONS $BOOST_BUILD_SPAM stage

        suppress_tests thread 

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"$blib"/test
                    # link=static 
                    "${bjam}" variant=debug --hash \
                        --prefix="${stage}" --libdir="${stage_debug}" \
                        $DEBUG_BJAM_OPTIONS $BOOST_BUILD_SPAM -a -q
                popd
            done
        fi

        # Move the debug libs first then clean to avoid tainting release build
        mv "${stage_lib}"/*-gd.lib "${stage_debug}"
        "${bjam}" --clean-all
        rm bin.v2/project-cache.jam
        
        RELEASE_BJAM_OPTIONS="$WINDOWS_BJAM_OPTIONS -sZLIB_LIBPATH=$ZLIB_RELEASE_PATH -sZLIB_LIBRARY_PATH=$ZLIB_RELEASE_PATH -sZLIB_NAME=zlib -sZLIB_BINARY=zlib"
        "${bjam}" link=static variant=release --abbreviate-paths \
            --prefix="${stage}" --libdir="${stage_release}" $RELEASE_BJAM_OPTIONS $BOOST_BUILD_SPAM stage

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"$blib"/test
                    # link=static 
                    "${bjam}" variant=release --hash \
                        --prefix="${stage}" --libdir="${stage_release}" \
                        $RELEASE_BJAM_OPTIONS $BOOST_BUILD_SPAM -a -q
                popd
            done
        fi

        # Move release libs
        mv "${stage_lib}"/*.lib "${stage_release}"
     ;;
    "darwin")
        # boost::future appears broken on 32-bit Mac (see boost bug 9558).
        # Disable the class in the unit test runs and *don't use it* in 
        # production until it's known to be good.
        BOOST_CXXFLAGS="-gdwarf-2 -std=c++0x -stdlib=libc++"
        BOOST_LDFLAGS="-stdlib=libc++"

        # Force zlib static linkage by moving .dylibs out of the way
        trap restore_dylibs EXIT
        for dylib in "${stage}"/packages/lib/{debug,release}/*.dylib; do
            if [ -f "$dylib" ]; then
                mv "$dylib" "$dylib".disable
            fi
        done

        stage_lib="${stage}"/lib
        ./bootstrap.sh --prefix=$(pwd) --without-icu

        DEBUG_BJAM_OPTIONS="include=\"${stage}\"/packages/include include=\"${stage}\"/packages/include/zlib/ \
            -sZLIB_LIBPATH=\"${stage}\"/packages/lib/debug \
            -sZLIB_INCLUDE=\"${stage}\"/packages/include/zlib/ \
            address-model=32_64 architecture=x86 \
            ${BOOST_BJAM_OPTIONS}"

        "${bjam}" toolset=darwin variant=debug --disable-icu $DEBUG_BJAM_OPTIONS $BOOST_BUILD_SPAM cxxflags="$BOOST_CXXFLAGS" linkflags="$BOOST_LDFLAGS" stage

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"${blib}"/test
                    "${bjam}" toolset=darwin variant=debug link=static  -a -q \
                        $DEBUG_BJAM_OPTIONS $BOOST_BUILD_SPAM cxxflags="$BOOST_CXXFLAGS"
                popd
            done
        fi

        mv "${stage_lib}"/*.a "${stage_debug}"

        RELEASE_BJAM_OPTIONS="include=\"${stage}\"/packages/include include=\"${stage}\"/packages/include/zlib/ \
            -sZLIB_LIBPATH=\"${stage}\"/packages/lib/release \
            -sZLIB_INCLUDE=\"${stage}\"/packages/include/zlib/ \
            address-model=32_64 architecture=x86 \
            ${BOOST_BJAM_OPTIONS}"

        "${bjam}" toolset=darwin variant=release --disable-icu $RELEASE_BJAM_OPTIONS $BOOST_BUILD_SPAM cxxflags="$BOOST_CXXFLAGS" linkflags="$BOOST_LDFLAGS" stage
        
        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"${blib}"/test
                    "${bjam}" toolset=darwin variant=release link=static  -a -q \
                        $RELEASE_BJAM_OPTIONS $BOOST_BUILD_SPAM cxxflags="$BOOST_CXXFLAGS"
                popd
            done
        fi

        mv "${stage_lib}"/*.a "${stage_release}"
     ;;
    "linux")
        # Force static linkage to libz by moving .sos out of the way
        trap restore_sos EXIT
        for solib in "${stage}"/packages/lib/debug/libz.so* "${stage}"/packages/lib/release/libz.so*; do
            if [ -f "$solib" ]; then
                mv -f "$solib" "$solib".disable
            fi
        done
            
        ./bootstrap.sh --prefix=$(pwd) --without-icu

        DEBUG_BOOST_BJAM_OPTIONS="--disable-icu toolset=gcc cxxflags=-std=c++11 \
             include=$stage/packages/include/zlib/ \
            -sZLIB_LIBPATH=$stage/packages/lib/debug \
            -sZLIB_INCLUDE=\"${stage}\"/packages/include/zlib/ \
            address-model=32 architecture=x86 \
            $BOOST_BJAM_OPTIONS"
        "${bjam}" variant=debug --reconfigure \
            --prefix="${stage}" --libdir="${stage}"/lib/debug \
            $DEBUG_BOOST_BJAM_OPTIONS $BOOST_BUILD_SPAM stage

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"${blib}"/test
                    "${bjam}" variant=debug -a -q \
                        --prefix="${stage}" --libdir="${stage}"/lib/debug \
                        $DEBUG_BOOST_BJAM_OPTIONS $BOOST_BUILD_SPAM
                popd
            done
        fi

        mv "${stage_lib}"/libboost* "${stage_debug}"

        "${bjam}" --clean

        RELEASE_BOOST_BJAM_OPTIONS="toolset=gcc cflags=-fstack-protector-strong \
            cflags=-D_FORTIFY_SOURCE=2 cxxflags=-std=c++11 \
            include=$stage/packages/include/zlib/ \
            -sZLIB_LIBPATH=$stage/packages/lib/release \
            -sZLIB_INCLUDE=\"${stage}\"/packages/include/zlib/ \
            address-model=32 architecture=x86 \
            $BOOST_BJAM_OPTIONS"
        "${bjam}" variant=release --reconfigure \
            --prefix="${stage}" --libdir="${stage}"/lib/release \
            $RELEASE_BOOST_BJAM_OPTIONS $BOOST_BUILD_SPAM stage

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"${blib}"/test
                    "${bjam}" variant=release -a -q \
                        --prefix="${stage}" --libdir="${stage}"/lib/release \
                        $RELEASE_BOOST_BJAM_OPTIONS $BOOST_BUILD_SPAM
                popd
            done
        fi

        mv "${stage_lib}"/libboost* "${stage_release}"

        "${bjam}" --clean
    ;;
    "linux64")
        # Force static linkage to libz by moving .sos out of the way
        trap restore_sos EXIT
        for solib in "${stage}"/packages/lib/debug/libz.so* "${stage}"/packages/lib/release/libz.so*; do
            if [ -f "$solib" ]; then
                mv -f "$solib" "$solib".disable
            fi
        done

        ./bootstrap.sh --prefix=$(pwd) --without-icu

        DEBUG_BOOST_BJAM_OPTIONS="--disable-icu toolset=gcc cxxflags=-fPIC cxxflags=-std=c++11 \
             include=$stage/packages/include/zlib/ \
            -sZLIB_LIBPATH=$stage/packages/lib/debug \
            -sZLIB_INCLUDE=\"${stage}\"/packages/include/zlib/ \
            address-model=64 architecture=x86 \
            $BOOST_BJAM_OPTIONS"
        "${bjam}" link=static variant=debug --reconfigure \
            --prefix="${stage}" --libdir="${stage}"/lib/debug \
            $DEBUG_BOOST_BJAM_OPTIONS $BOOST_BUILD_SPAM stage

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"${blib}"/test
                    "${bjam}" variant=debug -a -q \
                        --prefix="${stage}" --libdir="${stage}"/lib/debug \
                        $DEBUG_BOOST_BJAM_OPTIONS $BOOST_BUILD_SPAM
                popd
            done
        fi

        mv "${stage_lib}"/libboost* "${stage_debug}"

        "${bjam}" --clean

        RELEASE_BOOST_BJAM_OPTIONS="toolset=gcc cflags=-fstack-protector-strong \
            cflags=-D_FORTIFY_SOURCE=2 cxxflags=-fPIC cxxflags=-std=c++11 \
            include=$stage/packages/include/zlib/ \
            -sZLIB_LIBPATH=$stage/packages/lib/release \
            -sZLIB_INCLUDE=\"${stage}\"/packages/include/zlib/ \
            address-model=64 architecture=x86 \
            $BOOST_BJAM_OPTIONS"
        "${bjam}" link=static variant=release --reconfigure \
            --prefix="${stage}" --libdir="${stage}"/lib/release \
            $RELEASE_BOOST_BJAM_OPTIONS $BOOST_BUILD_SPAM stage

        # conditionally run unit tests
        if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
            for blib in "${BOOST_LIBS[@]}"; do
                pushd libs/"${blib}"/test
                    "${bjam}" variant=release -a -q \
                        --prefix="${stage}" --libdir="${stage}"/lib/release \
                        $RELEASE_BOOST_BJAM_OPTIONS $BOOST_BUILD_SPAM
                popd
            done
        fi

        mv "${stage_lib}"/libboost* "${stage_release}"

        "${bjam}" --clean
        ;;
esac
    
mkdir -p "${stage}"/include
cp -a boost "${stage}"/include/
mkdir -p "${stage}"/LICENSES
cp -a LICENSE_1_0.txt "${stage}"/LICENSES/boost.txt
mkdir -p "${stage}"/docs/boost/
cp -a "$top"/README.Linden "${stage}"/docs/boost/

cd "$top"

pass

