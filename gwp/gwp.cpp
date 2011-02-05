#include <Magick++.h>
#include <string>
#include <iostream>
#include <list>
#include <cstdio>
#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
// Windows Header Files:
#include <windows.h>
#include <tchar.h>
#include <stdio.h>
#include <shellapi.h>
#include "Manipulator.h"


using namespace Magick;
using namespace std;

int main( int argc, char ** argv)
{

  // Initialize ImageMagick install location for Windows
  InitializeMagick(*argv);

  if (argc < 18) 
	return 1;
  
  try {

		int x1 = atoi(argv[3]);
		int y1 = atoi(argv[4]);
		int x2 = atoi(argv[5]);
		int y2 = atoi(argv[6]);
		int mx = atoi(argv[7]);
		int my = atoi(argv[8]);
		double abw = atof(argv[9]);
		int xc = atoi(argv[10]); //composition position
		int yc = atoi(argv[11]);
		int xt = atoi(argv[12]); //composition position
		int yt = atoi(argv[13]);

		Image img( argv[1] );
		if(img.rows() < my || img.columns() < mx)
			return 2;

		img.extent(Geometry(img.columns(),img.rows()),"white");

		Image img2;
		if (x2 && y2)
			img2 = Image(img);

		Manipulator::retarget(img,x1,y1,abw);
		if (x2 && y2)
			Manipulator::retarget(img2,x2,y2,abw);
		img.backgroundColor(argv[14]);
		img.extent(Geometry(xt,yt));
		if (x2 && y2) 
			img.composite(img2,xc,yc);

		Manipulator::annotate(img,argv[15],argv[16]);

		img.magick(argv[17]);
		img.write(argv[2]);


  }
  catch( exception &error_ )
    {
      cout << "Caught exception: " << error_.what() << endl;
      return 1;
    }

  return 0;
}

int APIENTRY _tWinMain(HINSTANCE hInstance,
                     HINSTANCE hPrevInstance,
                     LPTSTR    lpCmdLine,
                     int       nCmdShow)
{
	 return main(__argc,__argv);
}
