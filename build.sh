#!/bin/bash
set -e

SQLITE_PATH=sqlite-amalgamation-3380000
SPATIALITE_PATH=libspatialite-5.0.1
RTTOPO_PATH=librttopo-1.1.0
TIFF_PATH=tiff-4.3.0
ICONV_PATH=libiconv-1.16
GEOS_PATH=geos-3.10.2
PROJ_PATH=proj-8.2.0


SQLITE_JDBC_PATH=sqlite-jdbc

TARGETS=(
    aarch64-linux-android
    armv7a-linux-androideabi
    i686-linux-android
    x86_64-linux-android
)

SQLITE_FLAGS=(
    -DHAVE_USLEEP=1
    #-DSQLITE_DEFAULT_JOURNAL_SIZE_LIMIT=1048576
    #-DSQLITE_THREADSAFE=1
    #-DNDEBUG=1
    -DSQLITE_ENABLE_MEMORY_MANAGEMENT=1
    -DSQLITE_HAS_COLUMN_METADATA=1
    -DSQLITE_DEFAULT_AUTOVACUUM=1
    -DSQLITE_TEMP_STORE=3
    -DSQLITE_ENABLE_FTS3
    -DSQLITE_ENABLE_FTS3_BACKWARDS
    -DSQLITE_ENABLE_RTREE=1
    #-DSQLITE_ENABLE_JSON1=1 # not needed as of sqlite 3.38.0
    -DSQLITE_ENABLE_COLUMN_METADATA=1 
    #-DSQLITE_DISABLE_LFS=1 
    -DSQLITE_ENABLE_FTS5=1
)



prepare() {
    export TOOLCHAIN=$NDKROOT/toolchains/llvm/prebuilt/linux-x86_64
    export TARGET=$1

    # Set this to your minSdkVersion.
    export API=21

    # Configure and build.
    export AR=$TOOLCHAIN/bin/llvm-ar
    export CC=$TOOLCHAIN/bin/$TARGET$API-clang
    export AS=$CC
    export CXX=$TOOLCHAIN/bin/$TARGET$API-clang++
    export LD=$TOOLCHAIN/bin/ld
    export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
    export STRIP=$TOOLCHAIN/bin/llvm-strip
    arch=$(echo $TARGET | cut -f1 -d'-')
    export INSTALLDIR="$(pwd)/install/$arch"
    export TARGETDIR="$(pwd)/target/$arch"
    mkdir -p $INSTALLDIR/lib
    mkdir -p $INSTALLDIR/include
    mkdir -p $TARGETDIR
}

build_sqlite() {
    prepare $1

    # SQLite
    echo "BUILDING SQLITE"
    cd $SQLITE_PATH
    $CC ${SQLITE_FLAGS[*]} -fPIC -c -o sqlite3.o sqlite3.c
    $CC -shared sqlite3.o -o $INSTALLDIR/lib/libsqlite3.so
    $AR rcs $INSTALLDIR/lib/libsqlite3.a sqlite3.o
    cp sqlite3.h $INSTALLDIR/include
    cp sqlite3ext.h $INSTALLDIR/include
    cd ..
}


build_iconv() {
    prepare $1
    # ICONV
    echo "BUILDING LIBICONV"
    cd $ICONV_PATH
    make clean || true
    ./configure --host $TARGET --enable-static=yes --enable-shared=yes --prefix=$INSTALLDIR --with-pic
    make clean || true
    make -j16
    make install
    cd ..
}


build_geos() {
    prepare $1
    # GEOS
    echo "BUILDING GEOS"
    mkdir -p $GEOS_PATH/$TARGET-shared $GEOS_PATH/$TARGET-static
    cd $GEOS_PATH/$TARGET-shared
    cmake --toolchain $NDKROOT/build/cmake/android.toolchain.cmake .. -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$INSTALLDIR -DCMAKE_CXX_FLAGS=-fPIC
    make -j16
    make install
    cd ../$TARGET-static
    cmake --toolchain $NDKROOT/build/cmake/android.toolchain.cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=$INSTALLDIR -DCMAKE_CXX_FLAGS=-fPIC -DCMAKE_EXE_LINKER_FLAGS="-static"
    make -j16
    make install
    cd ../..
}

build_rttopo() {
    prepare $1

    # RTTOPO
    echo "BUILDING LIBRTTOPO"
    cd $RTTOPO_PATH
    make clean || true
    rm -f config.status Makefile # force clean..
    ./autogen.sh
    CFLAGS="-I$INSTALLDIR/include" LIBS+="-L$INSTALLDIR/lib -lgeos_c -lgeos -lm" ./configure --prefix=$INSTALLDIR --host $TARGET --with-pic --enable-static=yes --enable-shared=yes --with-geosconfig=$INSTALLDIR/bin/geos-config
    make clean || true
    make clean
    make -j16 install
    cd ..
}


build_libtiff() {
    prepare $1
    # LIBTIFF http://download.osgeo.org/libtiff/tiff-4.3.0.tar.gz
    echo "BUILDING LIBTIFF"
    cd $TIFF_PATH
    mkdir -p $TARGET-static $TARGET-shared
    cd $TARGET-shared
    cmake --toolchain $NDKROOT/build/cmake/android.toolchain.cmake .. -DCMAKE_CXX_FLAGS="-fPIC" -DCMAKE_C_FLAGS="-fPIC" -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$INSTALLDIR -DCMAKE_EXE_LINKER_FLAGS=-lm
    make -j16
    make install
    cd ../$TARGET-static
    cmake --toolchain $NDKROOT/build/cmake/android.toolchain.cmake .. -DCMAKE_CXX_FLAGS="-fPIC" -DCMAKE_C_FLAGS="-fPIC" -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=$INSTALLDIR -DCMAKE_EXE_LINKER_FLAGS=-lm
    make -j16
    make install
    cd ../..
}


build_proj() {
    prepare $1

    # PROJ
    echo "BUILDING LIBPROJ"
    cd $PROJ_PATH
    mkdir -p $TARGET-static $TARGET-shared
    cd $TARGET-shared
    cmake --toolchain $NDKROOT/build/cmake/android.toolchain.cmake .. -DCMAKE_CXX_FLAGS="-I$INSTALLDIR/include -fPIC" -DCMAKE_C_FLAGS="-fPIC" -DCMAKE_INSTALL_PREFIX=$INSTALLDIR -DCMAKE_EXE_LINKER_FLAGS=-lm -DENABLE_CURL=OFF -DBUILD_PROJSYNC=OFF
    make -j16
    make install
    cd ../$TARGET-static
    cmake --toolchain $NDKROOT/build/cmake/android.toolchain.cmake .. -DBUILD_SHARED_LIBS=OFF -DBUILD_LIBPROJ_SHARED=off -DCMAKE_CXX_FLAGS="-I$INSTALLDIR/include -fPIC" -DCMAKE_C_FLAGS="-fPIC" -DCMAKE_INSTALL_PREFIX=$INSTALLDIR -DCMAKE_EXE_LINKER_FLAGS=-lm  -DENABLE_CURL=OFF -DBUILD_PROJSYNC=OFF
    make -j16
    make install
    cd ../..
}


build_spatialite() {
    prepare $1
    
    # SPATIALITE
    echo "BUILDING SPATIALITE"
    cd $SPATIALITE_PATH
    # spatialite uses outdated config.sub/guess files.. update
    cp ../$PROJ_PATH/config.{sub,guess} .
    make clean || true
    CFLAGS="-I$INSTALLDIR/include $SQLITE_FLAGS" LDFLAGS="-L$INSTALLDIR/lib -llog" ./configure --prefix=$INSTALLDIR --host $TARGET --target=android --enable-static=yes --enable-shared=yes --with-pic \
        --enable-rttopo --enable-geos --enable-iconv --with-geosconfig=$INSTALLDIR/bin/geos-config \
        --disable-minizip  --disable-freexl --disable-libxml2
    make clean || true
    make -j16
    make install
    cd ..
}


build_jdbc() {
    prepare $1
    # Now build sqlite-jdbc native interface, adding all the static libs from above
    echo "BUILDING SQLITE-JDBC"
    cd $SQLITE_JDBC_PATH
    # Patch it.. ignore errors if patched already
    git apply ../patches/sqlite-jdbc-init-spatialite.patch || true

    make jni-header
    mkdir -p $TARGET
    $CC -fPIC $CCFLAGS -I$INSTALLDIR/include -I target/common-lib -c -o $TARGET/NativeDB.o src/main/java/org/sqlite/core/NativeDB.c
    #$CC $CCFLAGS -I$INSTALLDIR/include -I target/common-lib -c -o $TARGET/extension-functions.o src/main/ext/extension-functions.c

    $CXX -shared -lm -llog -lz -static-libstdc++ -o $TARGETDIR/libsqlitejdbc.so $TARGET/*.o \
        $INSTALLDIR/lib/libcharset.a \
        $INSTALLDIR/lib/libgeos.a \
        $INSTALLDIR/lib/libgeos_c.a \
        $INSTALLDIR/lib/libiconv.a \
        $INSTALLDIR/lib/libproj.a \
        $INSTALLDIR/lib/librttopo.a \
        $INSTALLDIR/lib/libsqlite3.a \
        $INSTALLDIR/lib/libtiff.a \
        $INSTALLDIR/lib/libtiffxx.a \
        $INSTALLDIR/lib/libspatialite.a 
    
    $STRIP $TARGETDIR/libsqlitejdbc.so
        
        #$INSTALLDIR/lib/mod_spatialite.a
    
    cd ..
}

create_jar() {
    olddir=$(pwd)
    prepare ${TARGETS[0]} # to set any environment, so we get a usable INSTALLDIR
    TARGETDIR="$(pwd)/target/"

    # Building jar
    cd $SQLITE_JDBC_PATH
    mvn package -DskipTests

    cp target/sqlite-jdbc-*.jar $TARGETDIR/
    cd $TARGETDIR

    # Remove the "basic" native libraries
    zip -d sqlite-jdbc-*.jar "/org/sqlite/native/*"

    #mkdir -p tmp/org/sqlite/native/Linux-Android
    rm -rf tmp
    mkdir -p tmp/lib/x86_64 tmp/lib/arm64-v8a tmp/lib/armeabi-v7a tmp/lib/x86
    cp -f x86_64/* tmp/lib/x86_64 || true
    cp -f aarch64/* tmp/lib/arm64-v8a || true
    cp -f armv7a/* tmp/lib/armeabi-v7a || true
    cp -f i686/* tmp/lib/x86/ || true
    cp -f x86_64/* tmp/lib/x86_64 || true

    # proj.db is same for all..
    
    cp -r $INSTALLDIR/share/proj/proj.db tmp/


    # Add the spatialite-included binaries
    cd tmp
    zip -r $TARGETDIR/sqlite-jdbc-*.jar *

    sqlitever=$(echo $SQLITE_PATH | rev | cut -d'-' -f1 | rev)
    spatialitever=$(echo $SPATIALITE_PATH | rev | cut -d'-' -f1 | rev)
    rm -f $TARGETDIR/sqlite-jdbc-$sqlitever-spatialite-$spatialitever.jar
    mv $TARGETDIR/sqlite-jdbc-*.jar $TARGETDIR/sqlite-jdbc-$sqlitever-spatialite-$spatialitever.jar

    cd $olddir
}


build_all() {
    build_sqlite $1
    build_iconv $1
    build_libtiff $1
    build_proj $1
    build_geos $1
    build_rttopo $1
    build_spatialite $1
    build_jdbc $1
}




for target in ${TARGETS[*]}; do
    echo $target
    build_all $target
done

create_jar


