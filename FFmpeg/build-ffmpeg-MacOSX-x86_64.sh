#!/bin/bash

# *** GENERAL SETUP ***

# Set the root directory path
FFMPEG=$( cd "$( dirname "$0" )" && pwd )

# Remove any existing output directory
if [ -d $FFMPEG/output/MacOSX/x86_64 ]; then
	rm -r $FFMPEG/output/MacOSX/x86_64
	echo Removed the old output directories.
fi

# Create the i386 output directory
mkdir -p $FFMPEG/output/MacOSX/x86_64
echo Created the output directory: $FFMPEG/output/MacOSX/i386

# Change to the source directory
cd $FFMPEG/ffmpeg

# *** BUILD FOR Mac OSX ***

# * BUILD FOR x86_64 *

# Configure
echo Configure for x86_64
./configure \
--cc=clang \
--as='/usr/local/bin/gas-preprocessor.pl /Applications/Xcode.app/Contents/Developer/usr/bin/gcc' \
--sysroot=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk \
--target-os=darwin \
--arch=x86_64 \
--cpu=x86_64 \
--extra-cflags='-arch x86_64 -I/usr/local/include' \
--extra-ldflags='-arch x86_64 -L/usr/local/lib -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk' \
--prefix=../output/MacOSX/x86_64 \
--enable-cross-compile \
--disable-swscale-alpha \
--disable-doc \
--disable-ffmpeg \
--disable-ffplay \
--disable-ffprobe \
--disable-ffserver \
--disable-asm \
--disable-debug \
--enable-libmp3lame

# Make
make clean
#make
make && make install

