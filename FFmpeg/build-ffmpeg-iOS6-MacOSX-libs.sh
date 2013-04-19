#!/bin/bash

# *** GENERAL SETUP ***

# Set the root directory path
FFMPEG=$( cd "$( dirname "$0" )" && pwd )

# Remove and recreate the libs directory
if [ -d $FFMPEG/output ]; then
	rm -r $FFMPEG/output
	echo Removed the old output directory structure.
fi
mkdir $FFMPEG/output
mkdir $FFMPEG/output/iOS6
mkdir $FFMPEG/output/iOS6/armv7
mkdir $FFMPEG/output/MacOSX
mkdir $FFMPEG/output/MacOSX/i386
mkdir $FFMPEG/output/MacOSX/x86_64
mkdir $FFMPEG/output/Universal
echo Created the output directory structure.

# Change to the source directory
cd $FFMPEG/ffmpeg

# *** BUILD FOR iOS 6 ***

# * BUILD FOR armv7 *

# Configure
echo Configure for armv7 build
./configure \
--cc=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc \
--as='/usr/local/bin/gas-preprocessor.pl /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc' \
--sysroot=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.1.sdk \
--target-os=darwin \
--arch=arm \
--cpu=cortex-a8 \
--extra-cflags='-arch armv7 -strict -2' \
--extra-ldflags='-arch armv7 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.1.sdk' \
--prefix=../output/iOS6/armv7 \
--enable-cross-compile \
--disable-armv5te \
--disable-swscale-alpha \
--disable-doc \
--disable-ffmpeg \
--disable-ffplay \
--disable-ffprobe \
--disable-ffserver \
--disable-asm \
--disable-debug

# Make
make clean
#make
make && make install

# *** BUILD FOR Mac OSX ***

# * BUILD FOR i386 *

# Configure
echo Configure for i386
./configure \
--cc=/Applications/Xcode.app/Contents/Developer/usr/bin/gcc \
--as='/usr/local/bin/gas-preprocessor.pl /Applications/Xcode.app/Contents/Developer/usr/bin/gcc' \
--sysroot=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk \
--target-os=darwin \
--arch=i386 \
--cpu=i386 \
--extra-cflags='-arch i386 -strict -2' \
--extra-ldflags='-arch i386 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk' \
--prefix=../output/MacOSX/i386 \
--enable-cross-compile \
--disable-swscale-alpha \
--disable-doc \
--disable-ffmpeg \
--disable-ffplay \
--disable-ffprobe \
--disable-ffserver \
--disable-asm \
--disable-debug

# Make
make clean
#make
make && make install

# * BUILD FOR x86_64 *

# Configure
echo Configure for x86_64
./configure \
--cc=/Applications/Xcode.app/Contents/Developer/usr/bin/gcc \
--as='/usr/local/bin/gas-preprocessor.pl /Applications/Xcode.app/Contents/Developer/usr/bin/gcc' \
--sysroot=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk \
--target-os=darwin \
--arch=x86_64 \
--cpu=x86_64 \
--extra-cflags='-arch x86_64 -strict -2' \
--extra-ldflags='-arch x86_64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk' \
--prefix=../output/MacOSX/x86_64 \
--enable-cross-compile \
--disable-swscale-alpha \
--disable-doc \
--disable-ffmpeg \
--disable-ffplay \
--disable-ffprobe \
--disable-ffserver \
--disable-asm \
--disable-debug

# Make
make clean
#make
make && make install

# *** BUILD Universal ***

lipo -output $FFMPEG/output/Universal/libavcodec.a  -create \
-arch armv7 $FFMPEG/output/iOS6/armv7/lib/libavcodec.a \
-arch i386 $FFMPEG/output/MacOSX/i386/lib/libavcodec.a \
-arch x86_64 $FFMPEG/output/MacOSX/x86_64/lib/libavcodec.a

lipo -output $FFMPEG/output/Universal/libavdevice.a  -create \
-arch armv7 $FFMPEG/output/iOS6/armv7/lib/libavdevice.a \
-arch i386 $FFMPEG/output/MacOSX/i386/lib/libavdevice.a \
-arch x86_64 $FFMPEG/output/MacOSX/x86_64/lib/libavcodec.a

lipo -output $FFMPEG/output/Universal/libavformat.a  -create \
-arch armv7 $FFMPEG/output/iOS6/armv7/lib/libavformat.a \
-arch i386 $FFMPEG/output/MacOSX/i386/lib/libavformat.a \
-arch x86_64 $FFMPEG/output/MacOSX/x86_64/lib/libavcodec.a

lipo -output $FFMPEG/output/Universal/libavutil.a  -create \
-arch armv7 $FFMPEG/output/iOS6/armv7/lib/libavutil.a \
-arch i386 $FFMPEG/output/MacOSX/i386/lib/libavutil.a \
-arch x86_64 $FFMPEG/output/MacOSX/x86_64/lib/libavcodec.a

lipo -output $FFMPEG/output/Universal/libswresample.a  -create \
-arch armv7 $FFMPEG/output/iOS6/armv7/lib/libswresample.a \
-arch i386 $FFMPEG/output/MacOSX/i386/lib/libswresample.a

#lipo -output $FFMPEG/output/Universal/libpostproc.a  -create \
#-arch armv7 $FFMPEG/output/iOS6/armv7/lib/libpostproc.a \
#-arch i386 $FFMPEG/output/MacOSX/i386/lib/libpostproc.a \
#-arch x86_64 $FFMPEG/output/MacOSX/x86_64/lib/libavcodec.a

lipo -output $FFMPEG/output/Universal/libswscale.a  -create \
-arch armv7 $FFMPEG/output/iOS6/armv7/lib/libswscale.a \
-arch i386 $FFMPEG/output/MacOSX/i386/lib/libswscale.a \
-arch x86_64 $FFMPEG/output/MacOSX/x86_64/lib/libavcodec.a

lipo -output $FFMPEG/output/Universal/libavfilter.a  -create \
-arch armv7 $FFMPEG/output/iOS6/armv7/lib/libavfilter.a \
-arch i386 $FFMPEG/output/MacOSX/i386/lib/libavfilter.a \
-arch x86_64 $FFMPEG/output/MacOSX/x86_64/lib/libavcodec.a
