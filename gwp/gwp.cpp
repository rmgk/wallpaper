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
	fs::path working_dir(fs::absolute(argv[0]).parent_path());
	// Initialize ImageMagick install location for Windows
	InitializeMagick(working_dir.string().c_str());
	wpl::init((working_dir / "wp.db").string().c_str());

	if (argc > 1) 
	{
		fs::path dir(argv[1]);
		if(fs::exists(dir)) {
			cout << dir.string().c_str() << endl;
			wpl::add_directory(dir.string().c_str());
		}
	}
	
	int cur = wpl::get_position();
	string path(wpl::get_path(++cur));
	cout << path << endl;
	wpl::set_position(cur);
	wpc::setRegistry();
	try {
		wpc::convertWP(path.c_str());
		string wppath( (working_dir / "wallpaper").string() );
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


