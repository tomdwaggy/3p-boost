#!/bin/sh

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

BOOST_SOURCE_DIR="boost"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

BOOST_BJAM_OPTIONS="address-model=32 architecture=x86 --layout=tagged \
                            --with-date_time --with-filesystem \
                            --with-iostreams --with-program_options \
                            --with-regex --with-signals --with-system \
                            --with-thread  -sNO_BZIP2=1"
top="$(pwd)"
cd "$BOOST_SOURCE_DIR"
stage="$(pwd)/stage"
                                                     
if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
    # Bjam doesn't know about cygwin paths, so convert them!
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage_lib="$stage/lib"
stage_release="$stage_lib/release"
stage_debug="$stage_lib/debug"
mkdir -p "$stage_release"
mkdir -p "$stage_debug"

# bjam doesn't support a -sICU_LIBPATH to point to the location
# of the icu libraries like it does for zlib. Instead, it expects
# the library files to be immediately in the ./lib directory
# and the headres to be in the ./include directory and doesn't
# provide a way to work around this. Because of this, we break
# the standard packaging layout, with the debug library files
# in ./lib/debug and the release in ./lib/release and instead
# only package the release build of icu4c in the ./lib directory.
# If a way to work around this is found, uncomment the
# corresponding blocks in the icu4c build and fix it here.

case "$AUTOBUILD_PLATFORM" in
    "windows")

    cmd.exe /C bootstrap.bat
	INCLUDE_PATH=$(cygpath -m $stage/packages/include)
	ZLIB_RELEASE_PATH=$(cygpath -m $stage/packages/lib/release)
	ZLIB_DEBUG_PATH=$(cygpath -m $stage/packages/lib/debug)
	ICU_PATH=$(cygpath -m $stage/packages)

	# Windows build of viewer expects /Zc:wchar_t-, have to match that
	WINDOWS_BJAM_OPTIONS="--toolset=msvc-10.0 stage -j2 \
	    include=$INCLUDE_PATH -sICU_PATH=$ICU_PATH \
	    cxxflags=-Zc:wchar_t- \
	    $BOOST_BJAM_OPTIONS"

	RELEASE_BJAM_OPTIONS="$WINDOWS_BJAM_OPTIONS -sZLIB_LIBPATH=$ZLIB_RELEASE_PATH"
	./bjam variant=release $RELEASE_BJAM_OPTIONS

	DEBUG_BJAM_OPTIONS="$WINDOWS_BJAM_OPTIONS -sZLIB_LIBPATH=$ZLIB_DEBUG_PATH"
	./bjam variant=debug $DEBUG_BJAM_OPTIONS

	# Move the debug libs first, then the leftover release libs
	mv ${stage_lib}/*-gd.lib "$stage_debug"
	mv ${stage_lib}/*.lib "$stage_release"

        ;;
    "darwin")
	stage_lib="$stage/lib"
	./bootstrap.sh --prefix=$(pwd) --with-icu=$stage/packages

    RELEASE_BJAM_OPTIONS="include=$stage/packages/include \
        -sZLIB_LIBPATH=$stage/packages/lib/release $BOOST_BJAM_OPTIONS"

	./bjam toolset=darwin variant=release $RELEASE_BJAM_OPTIONS stage

	mv $stage_lib/*.a "$stage_release"
	mv $stage_lib/*dylib* "$stage_release"


    DEBUG_BJAM_OPTIONS="include=$stage/packages/include \
        -sZLIB_LIBPATH=$stage/packages/lib/debug $BOOST_BJAM_OPTIONS"

	./bjam toolset=darwin variant=debug $DEBUG_BJAM_OPTIONS stage

	mv $stage_lib/*.a "$stage_debug"
	mv $stage_lib/*dylib* "$stage_debug"

        ;;
    "linux")
	./bootstrap.sh --prefix=$(pwd) --with-icu=$stage/packages/

    RELEASE_BOOST_BJAM_OPTIONS="toolset=gcc-4.1 include=$stage/packages/include \
        -sZLIB_LIBPATH=$stage/packages/lib/release $BOOST_BJAM_OPTIONS"
	./bjam  variant=release $RELEASE_BOOST_BJAM_OPTIONS stage
	stage_release="$stage_lib/release"

	mv $stage_lib/*.a "$stage_release"
	mv $stage_lib/*so* "$stage_release"

	DEBUG_BOOST_BJAM_OPTIONS="toolset=gcc-4.1 include=$stage/packages/include \
        -sZLIB_LIBPATH=$stage/packages/lib/debug $BOOST_BJAM_OPTIONS"
	./bjam variant=debug $DEBUG_BOOST_BJAM_OPTIONS stage
	mv $stage_lib/*.a "$stage_debug"
	mv $stage_lib/*so* "$stage_debug"
        ;;
esac
    
mkdir -p "$stage/include"
cp -R boost "$stage/include"
mkdir -p "$stage/LICENSES"
cp LICENSE_1_0.txt "$stage/LICENSES/"boost.txt

cd "$top"

pass

