#!/bin/bash

GLOBAL_OUTDIR="`pwd`/dependencies"
LOCAL_OUTDIR="./outdir"
LEPTON_LIB="`pwd`/leptonica-1.69"
TESSERACT_LIB="`pwd`/tesseract-ocr"

IOS_BASE_SDK="6.1"
IOS_DEPLOY_TGT="6.1"

setenv_all()
{
	# Add internal libs
	export CFLAGS="$CFLAGS -I$GLOBAL_OUTDIR/include -L$GLOBAL_OUTDIR/lib"
	
	export CXX="xcrun g++"
 	export CC="xcrun gcc"

	export LD="xcrun ld"
	export AR="xcrun ar"
	export AS="xcrun as"
	export NM="xcrun nm"
	export RANLIB="xcrun ranlib"
	export LDFLAGS="-L$SDKROOT/usr/lib/"
	
	export CPPFLAGS=$CFLAGS
	export CXXFLAGS=$CFLAGS
}

setenv_arm7()
{
	unset DEVROOT SDKROOT CFLAGS CC LD CPP CXX AR AS NM CXXCPP RANLIB LDFLAGS CPPFLAGS CXXFLAGS
	
  	export DEVROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer
	export SDKROOT=$DEVROOT/SDKs/iPhoneOS$IOS_BASE_SDK.sdk
	
	export CFLAGS="-arch armv7 -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$IOS_DEPLOY_TGT -I$SDKROOT/usr/include/"
	
	setenv_all
}

setenv_i386()
{
	unset DEVROOT SDKROOT CFLAGS CC LD CPP CXX AR AS NM CXXCPP RANLIB LDFLAGS CPPFLAGS CXXFLAGS
	
	export DEVROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer
	export SDKROOT=$DEVROOT/SDKs/iPhoneSimulator$IOS_BASE_SDK.sdk
	
	export CFLAGS="-arch i386 -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$IOS_DEPLOY_TGT"
	
	setenv_all
}

create_outdir_lipo()
{
	for lib_i386 in `find $LOCAL_OUTDIR/i386 -name "lib*\.a"`; do
		lib_arm7=`echo $lib_i386 | sed "s/i386/arm7/g"`
		lib=`echo $lib_i386 | sed "s/i386\///g"`
		lipo -arch armv7 $lib_arm7 -arch i386 $lib_i386 -create -output $lib
	done
}

merge_libfiles()
{
	DIR=$1
	LIBNAME=$2
	
	cd $DIR
	for i in `find . -name "lib*.a"`; do
		$AR -x $i
	done
	$AR -r $LIBNAME *.o
	rm -rf *.o __*
	cd -
}


#######################
# LEPTONLIB
#######################
cd $LEPTON_LIB
rm -rf $LOCAL_OUTDIR
mkdir -p $LOCAL_OUTDIR/arm7 $LOCAL_OUTDIR/i386

# armv7
echo 'Compiling LEPTONLIB for armv7'

make clean &> /dev/null
make distclean &> /dev/null
setenv_arm7
./configure --host=arm-apple-darwin6 --enable-shared=no --disable-programs --without-zlib --without-libpng --without-jpeg --without-giflib --without-libtiff &> /dev/null || exit;

make -j4 &> /dev/null
cp -rf src/.libs/lib*.a $LOCAL_OUTDIR/arm7

# i386
echo 'Compiling LEPTONLIB for i386'

make clean &> /dev/null
make distclean &> /dev/null
setenv_i386
./configure --enable-shared=no --disable-programs --without-zlib --without-libpng --without-jpeg --without-giflib --without-libtiff &> /dev/null || exit;
make -j4 &> /dev/null
cp -rf src/.libs/lib*.a $LOCAL_OUTDIR/i386

create_outdir_lipo
mkdir -p $GLOBAL_OUTDIR/include/leptonica && cp -rf src/*.h $GLOBAL_OUTDIR/include/leptonica
mkdir -p $GLOBAL_OUTDIR/lib && cp -rf $LOCAL_OUTDIR/lib*.a $GLOBAL_OUTDIR/lib
cd ..

#######################
# TESSERACT-OCR (v3)
#######################
cd $TESSERACT_LIB
rm -rf $LOCAL_OUTDIR
mkdir -p $LOCAL_OUTDIR/arm7 $LOCAL_OUTDIR/i386

# armv7
echo 'Compiling TESSERACT-OCR for armv7'

make clean &> /dev/null
make distclean &> /dev/null
setenv_arm7
bash autogen.sh &> /dev/null
./configure --host=arm-apple-darwin6 --enable-shared=no LIBLEPT_HEADERSDIR=$GLOBAL_OUTDIR/include/ &> /dev/null || exit;

make -j4 &> /dev/null
for i in `find . -name "lib*.a"`; do cp -rf $i $LOCAL_OUTDIR/arm7; done
merge_libfiles $LOCAL_OUTDIR/arm7 libtesseract_all.a

# i386
echo 'Compiling TESSERACT-OCR for i386'
make clean &> /dev/null
make distclean &> /dev/null
setenv_i386
bash autogen.sh &> /dev/null
./configure --enable-shared=no LIBLEPT_HEADERSDIR=$GLOBAL_OUTDIR/include/ &> /dev/null || exit;
make -j4 &> /dev/null
for i in `find . -name "lib*.a" | grep -v arm`; do cp -rf $i $LOCAL_OUTDIR/i386; done
merge_libfiles $LOCAL_OUTDIR/i386 libtesseract_all.a

create_outdir_lipo
mkdir -p $GLOBAL_OUTDIR/include/tesseract
tess_inc=( api/*.h ccmain/*.h ccstruct/*.h ccutil/*.h )
for i in "${tess_inc[@]}"; do
   cp -rf $i $GLOBAL_OUTDIR/include/tesseract
done
mkdir -p $GLOBAL_OUTDIR/lib && cp -rf $LOCAL_OUTDIR/lib*.a $GLOBAL_OUTDIR/lib
make clean &> /dev/null
make distclean &> /dev/null
rm -rf $LOCAL_OUTDIR
cd ..

echo "Finished!"
