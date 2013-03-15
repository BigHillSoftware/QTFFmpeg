*** How to build ffmpeg for iOS 6 and Mac OS X Lion using Xcode 4.5.2 (tested against a 01/22/2013 github checkout) ***

1. Create a new directory of choice to hold all of the files involved in this HOWTO (well call this directory <FFMPEG>).

2. Clone ffmpeg from github, placing the ffmpeg directory inside <FFMPEG>. In other words, the ffmpeg source should reside at <FFMPEG>/ffmpeg.

3. Copy the gas-preprocessor.pl into the /usr/local/bin directory.

4. Install MacPorts. (http://www.macports.org/install.php)

5. Install pkg-config with the command: 

sudo port install pkgconfig

6. Copy the build-ffmpeg-iOS6-MacOSX-libs.sh into the <FFMPEG> directory. 

7. Open Terminal, navigate to the <FFMPEG> directory. 

8. Execute 
./build-ffmpeg-iOS5-MacOSX-libs.sh

9. Here's what should have taken place: 
  
- An output directory structure should have been created to hold built iOS6, Mac OSX, and Universal libraries.
- The FFMPEG source should have been compiled and libraries built for iOS6, Mac OSX, and Universal. The built libraries and headers should have been copied into their respective output directories.
