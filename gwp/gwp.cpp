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

#include "WallpaperList.h"

using namespace Magick;
using namespace std;
namespace fs = boost::filesystem;


int main( int argc, char ** argv)
{
	// Initialize ImageMagick install location for Windows
	InitializeMagick(*argv);

	//if (argc < 2) 
	//	return 1;

	wpl::init("wp.db");
	int cur = wpl::get_position();

	wpl::add_directory("D:\\Pictures\\");

	string path("D:\\Pictures\\");
	path += wpl::get_path(++cur);
	cout << path << endl;
	wpl::set_position(cur);
	wpc::setRegistry();
	try {
		wpc::convertWP(path.c_str());
		string wppath(fs::current_path().string() + "\\wallpaper");
		char* wpcstr = const_cast<char*>(wppath.c_str());
		wpc::setWP(wpcstr);
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


