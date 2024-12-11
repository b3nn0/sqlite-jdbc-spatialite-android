#!/bin/bash

set -e
set -x

stat sqlite-jdbc || git clone https://github.com/xerial/sqlite-jdbc.git

if [ ! -d sqlite-amalgamation-3470200.zip ]; then
    wget -N https://sqlite.org/2024/sqlite-amalgamation-3470200.zip
    unzip sqlite-amalgamation-3470200.zip
fi


if [ ! -d libiconv-1.17 ]; then
    wget -N https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz
    tar xzf libiconv-1.17.tar.gz
fi


stat librttopo-1.1.0 || git clone https://git.osgeo.org/gitea/rttopo/librttopo.git -b librttopo-1.1.0 librttopo-1.1.0

if [ ! -d tiff-4.7.0 ]; then
    wget -N https://download.osgeo.org/libtiff/tiff-4.7.0.tar.gz
    tar xzf tiff-4.7.0.tar.gz
fi

if [ ! -d geos-3.13.0 ]; then
    wget -N https://download.osgeo.org/geos/geos-3.13.0.tar.bz2
    tar xjf geos-3.13.0.tar.bz2
fi

if [ ! -d proj-9.5.1 ]; then
    wget -N https://download.osgeo.org/proj/proj-9.5.1.tar.gz
    tar xzf proj-9.5.1.tar.gz
fi


if [ ! -d libspatialite-fossil ]; then
    fossil clone https://www.gaia-gis.it/fossil/libspatialite
    mv libspatialite libspatialite-fossil
fi
#if [ ! -d libspatialite-5.0.1 ]; then
#    wget -N http://www.gaia-gis.it/gaia-sins/libspatialite-5.0.1.tar.gz
#    tar xzf libspatialite-5.0.1.tar.gz
#fi


