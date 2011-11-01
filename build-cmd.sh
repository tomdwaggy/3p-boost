#!/bin/sh

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

BOOST_VERSION="1_45_0"
BOOST_SOURCE_DIR="boost_$BOOST_VERSION"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

top="$(pwd)"
cd "$BOOST_SOURCE_DIR"
stage="$(pwd)/stage"
BOOST_BJAM_OPTIONS="include=$stage/packages/include --layout=tagged --with-date_time --with-filesystem --with-iostreams --with-program_options --with-regex --with-signals --with-system --with-thread -sZLIB_LIBPATH=$stage/packages/lib/release -sNO_BZIP2=1"
#BJAM_RELEASE_OPTIONS="-sICU_LINK='-L $stage/packages/lib/release'"
#BJAM_DEBUG_OPTIONS="-sICU_LINK='-L $stage/packages/lib/debug'"
case "$AUTOBUILD_PLATFORM" in
    "windows")
	stage_lib="$stage/lib"
	stage_release="$stage_lib/release"
	stage_debug="$stage/lib/debug"
	mkdir -p "$stage_release"
	mkdir -p "$stage_debug"

	cmd.exe /C bootstrap.bat --with-icu
	./bjam --toolset=msvc-10.0 $BOOST_BJAM_OPTIONS stage
	mv "$stage_lib/libboost_program_options-vc100-mt-1_45.lib" "$stage_release"
	mv "$stage_lib/libboost_regex-vc100-mt-1_45.lib" "$stage_release"
	mv "$stage_lib/libboost_date_time-vc100-mt-1_45.lib" "$stage_release"
	mv "$stage_lib/libboost_filesystem-vc100-mt-1_45.lib" "$stage_release"
	mv "$stage_lib/libboost_system-vc100-mt-1_45.lib" "$stage_release"

	mv "$stage_lib/libboost_program_options-vc100-mt-gd-1_45.lib" "$stage_debug"
	mv "$stage_lib/libboost_regex-vc100-mt-gd-1_45.lib" "$stage_debug"
	mv "$stage_lib/libboost_date_time-vc100-mt-gd-1_45.lib" "$stage_debug"
	mv "$stage_lib/libboost_filesystem-vc100-mt-gd-1_45.lib" "$stage_debug"
	mv "$stage_lib/libboost_system-vc100-mt-gd-1_45.lib" "$stage_debug"
        ;;
    "darwin")
	stage_lib="$stage/lib"
	./bootstrap.sh --prefix=$(pwd)

	./bjam toolset=darwin address-model=32 architecture=x86 variant=release $BOOST_BJAM_OPTIONS stage
	stage_release="$stage_lib/release"
	mkdir -p "$stage_release"
	mv "$stage_lib/libboost_program_options.a" "$stage_release"
	mv "$stage_lib/libboost_regex.a" "$stage_release"
	mv "$stage_lib/libboost_date_time.a" "$stage_release"
	mv "$stage_lib/libboost_filesystem.a" "$stage_release"
	mv "$stage_lib/libboost_system.a" "$stage_release"

	./bjam toolset=darwin  address-model=32 architecture=x86 variant=debug $BOOST_BJAM_OPTIONS stage
	stage_debug="$stage/lib/debug"
	mkdir -p "$stage_debug"
	mv "$stage_lib/libboost_program_options.a" "$stage_debug"
	mv "$stage_lib/libboost_regex.a" "$stage_debug"
	mv "$stage_lib/libboost_date_time.a" "$stage_debug"
	mv "$stage_lib/libboost_filesystem.a" "$stage_debug"
	mv "$stage_lib/libboost_system.a" "$stage_debug"
        ;;
    "linux")
	stage_lib="$stage/lib"
	./bootstrap.sh --prefix=$(pwd) --with-icu=$stage/packages/
	./bjam toolset=gcc-4.1 address-model=32 architecture=x86 variant=release $BOOST_BJAM_OPTIONS stage
	stage_release="$stage_lib/release"

	mkdir -p "$stage_release"
	mv "$stage_lib/libboost_program_options.a" "$stage_release"
	mv "$stage_lib/libboost_regex.a" "$stage_release"
	mv "$stage_lib/libboost_date_time.a" "$stage_release"
	mv "$stage_lib/libboost_filesystem.a" "$stage_release"
	mv "$stage_lib/libboost_system.a" "$stage_release"

	./bjam toolset=gcc-4.1 address-model=32 architecture=x86 variant=debug $BOOST_BJAM_OPTIONS stage
	stage_debug="$stage/lib/debug"
	mkdir -p "$stage_debug"
	mv "$stage_lib/libboost_program_options.a" "$stage_debug"
	mv "$stage_lib/libboost_regex.a" "$stage_debug"
	mv "$stage_lib/libboost_date_time.a" "$stage_debug"
	mv "$stage_lib/libboost_filesystem.a" "$stage_debug"
	mv "$stage_lib/libboost_system.a" "$stage_debug"
        ;;
esac
    
mkdir -p "$stage/include"
cp -R boost "$stage/include"
mkdir -p "$stage/LICENSES"
cp LICENSE_1_0.txt "$stage/LICENSES/"boost.txt

cd "$top"

pass

