#!/bin/sh

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

BOOST_VERSION="1_45_0"
BOOST_SOURCE_DIR="boost_$BOOST_VERSION"
BOOST_ARCHIVE="$BOOST_SOURCE_DIR.tar.gz"
BOOST_URL="http://sourceforge.net/projects/boost/files/boost/1.45.0/$BOOST_ARCHIVE/download"
BOOST_MD5="739792c98fafb95e7a6b5da23a30062c" # for boost_1_45_0.tar.gz

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

fetch_archive "$BOOST_URL" "$BOOST_ARCHIVE" "$BOOST_MD5"
extract "$BOOST_ARCHIVE"

top="$(pwd)"
cd "$BOOST_SOURCE_DIR"
	stage="$(pwd)/stage"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
	    #install bjam, the boost build tool, to the extracted boost folder.
	    BJAM_URL_WINDOWS="http://sourceforge.net/projects/boost/files/boost-jam/3.1.18/boost-jam-3.1.18-1-ntx86.zip/download"
	    BJAM_ARCHIVE_WINDOWS="boost-jam-3.1.18-1-ntx86.zip"
	    BJAM_MD5_WINDOWS="15ec7ae2c8354e4d070a67660f022c5b" # for bjam 3.1.18-1-ntx86
	    
	    fetch_archive "$BJAM_URL_WINDOWS" "$BJAM_ARCHIVE_WINDOWS" "$BJAM_MD5_WINDOWS"
	    extract "$BJAM_ARCHIVE_WINDOWS'

	    
	    (cd contrib/masmx86 ; cmd.exe /C "bld_ml32.bat")
            build_sln "contrib/vstudio/vc10/zlibvc.sln" "Debug|Win32" "zlibstat"
            build_sln "contrib/vstudio/vc10/zlibvc.sln" "Release|Win32" "zlibstat"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp "contrib/vstudio/vc10/x86/ZlibStatDebug/zlibstat.lib" \
                "$stage/lib/debug/zlibd.lib"
            cp "contrib/vstudio/vc10/x86/ZlibStatRelease/zlibstat.lib" \
                "$stage/lib/release/zlib.lib"
            mkdir -p "stage/include/zlib"
            cp {zlib.h,zconf.h} "$stage/include/zlib"
        ;;
        "darwin")
            ./configure --prefix="$stage"
            make
            make install
			mkdir -p "$stage/include/zlib"
			mv "$stage/include/"*.h "$stage/include/zlib/"
        ;;
        "linux")
            CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$stage"
            make
            make install
			mkdir -p "$stage/include/zlib"
			mv "$stage/include/"*.h "$stage/include/zlib/"
        ;;
    esac
    mkdir -p stage/LICENSES
    tail -n 31 README > stage/LICENSES/zlib.txt
cd "$top"

pass

