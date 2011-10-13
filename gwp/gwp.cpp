#include <Magick++.h>
#include <string>
#include <iostream>
#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
// Windows Header Files:
#include <windows.h>
#include <shellapi.h>
#include "Wallpaper.h"
#include "Environment.h"
#include <boost/filesystem.hpp>
#include <numeric>
#include "WallpaperList.h"

using namespace Magick;
using namespace std;
namespace fs = boost::filesystem;

bool convertWP(const char* src) 
{
	auto env = wpc::getScreens();
	int numScreens = get<0>(env);
	auto screens = get<3>(env);
	vector<int> width;
	vector<int> height;
	for (int i = 0; i < numScreens; ++i)
	{
		width.push_back(screens[i].right - screens[i].left);
		height.push_back(screens[i].bottom - screens[i].top);
	}
	int min_width = accumulate(width.begin(),width.end(),0) / get<0>(env) / 2;
	int min_height = accumulate(height.begin(),height.end(),0) / get<0>(env) / 2;
	double abw = 0.2;
	int width_total = get<1>(env);
	int height_total = get<2>(env);

	Image canvas( src );
	//discard small images
	if(canvas.rows() < min_height || canvas.columns() < min_width)
		return false;
	//add white background for transparent images
	canvas.extent(Geometry(canvas.columns(),canvas.rows()),"white");

	Image orig;
	if (numScreens > 1)
		orig = Image(canvas);

	wpc::retarget(canvas,width[0],height[0],abw);
	if (numScreens > 1) {
		canvas.backgroundColor("pink");
		canvas.extent(Geometry(width_total,height_total));
		for (int i = 1; i < numScreens; ++i)
		{
			Image temp(orig);
			wpc::retarget(temp,width[i],height[i],abw);
			int x = screens[i].left;
			int y = screens[i].top;
			/* when in tiling wallpaper mode, the origin is at the upper left corner of the
			 * primary monitor. if any secondary monitor is left or above the primary its 
			 * coordinates will be negative. adding the total size to the negative position
			 * gives the correct position but that may cause the image to overflow. 
			 * if it overflows it needs to be drawn again at the original position which
			 * causes the oveflown part to be drawn at the correct position.
			 */
			if (x < 0) x += width_total;
			if (y < 0) y += height_total;
			canvas.composite(temp,x,y);
			if (x + width[i] > width_total)
				canvas.composite(temp,x-width_total,y);
			if (y + height[i] > height_total)
				canvas.composite(temp,x,y-height_total);
		}
			
	}
	//wpc::annotate(img,"dies ist ein test","+0+2");

	canvas.magick("BMP3");
	canvas.write("wallpaper");

	return true;
}

int main( int argc, char ** argv)
{
	// Initialize ImageMagick install location for Windows
	InitializeMagick(*argv);
	
	//if (argc < 2) 
	//	return 1;

	wpl::init("wp.db");

	string path(wpl::get_path(2));
	cout << path << endl;
	wpc::setRegistry();
	try {
		convertWP(argv[1]);
		string wppath(fs::current_path().string() + "\\wallpaper");
		char* wpcstr = const_cast<char*>(wppath.c_str());
		cout << wpc::setWP(wpcstr) << endl;
	}
	catch( exception &error_ )
	{
		cout << "Caught exception: " << error_.what() << endl;
		return 1;
	}
	
	wpl::close();

	return 0;
}

int APIENTRY _tWinMain(HINSTANCE hInstance,
                     HINSTANCE hPrevInstance,
                     LPTSTR    lpCmdLine,
                     int       nCmdShow)
{
	 return main(__argc,__argv);
}


