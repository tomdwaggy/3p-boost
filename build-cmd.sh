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
    #Bjam doesn't know about cygwin paths, so convert them!
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage_lib="$stage/lib"
stage_release="$stage_lib/release"
stage_debug="$stage_lib/debug"
mkdir -p "$stage_release"
mkdir -p "$stage_debug"

case "$AUTOBUILD_PLATFORM" in
    "windows")

    cmd.exe /C bootstrap.bat
	INCLUDE_PATH=$(cygpath -m $stage/packages/include)
	ZLIB_PATH=$(cygpath -m $stage/packages/lib/release)
	ICU_PATH=$(cygpath -m $stage/packages)
	
	BOOST_BJAM_OPTIONS="--toolset=msvc-10.0 include=$INCLUDE_PATH \
        -sZLIB_LIBPATH=$ZLIB_PATH -sICU_PATH=$ICU_PATH \
        $BOOST_BJAM_OPTIONS"
        
	./bjam variant=release $BOOST_BJAM_OPTIONS stage -j2
	./bjam variant=debug $BOOST_BJAM_OPTIONS stage -j2

	# Move the debug libs first, then the leftover release libs
	mv ${stage_lib}/*-gd.lib "$stage_debug"
	mv ${stage_lib}/*.lib "$stage_release"

        ;;
    "darwin")
	stage_lib="$stage/lib"
	./bootstrap.sh --prefix=$(pwd)

	./bjam toolset=darwin variant=release $BOOST_BJAM_OPTIONS stage
	mv "$stage_lib/libboost_program_options.a" "$stage_release"
	mv "$stage_lib/libboost_regex.a" "$stage_release"
	mv "$stage_lib/libboost_date_time.a" "$stage_release"
	mv "$stage_lib/libboost_filesystem.a" "$stage_release"
	mv "$stage_lib/libboost_system.a" "$stage_release"

	./bjam toolset=darwin variant=debug $BOOST_BJAM_OPTIONS stage
	mv "$stage_lib/libboost_program_options.a" "$stage_debug"
	mv "$stage_lib/libboost_regex.a" "$stage_debug"
	mv "$stage_lib/libboost_date_time.a" "$stage_debug"
	mv "$stage_lib/libboost_filesystem.a" "$stage_debug"
	mv "$stage_lib/libboost_system.a" "$stage_debug"
        ;;
    "linux")
	BOOST_BJAM_OPTIONS="toolset=gcc-4.1 include=$stage/packages/include \
        -sZLIB_LIBPATH=$stage/packages/lib/release $BOOST_BJAM_OPTIONS"
	./bootstrap.sh --prefix=$(pwd) --with-icu=$stage/packages/
	./bjam  variant=release $BOOST_BJAM_OPTIONS stage
	stage_release="$stage_lib/release"

	mv $stage_lib/*.a "$stage_release"
	mv $stage_lib/*so* "$stage_release"

	./bjam variant=debug $BOOST_BJAM_OPTIONS stage
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

