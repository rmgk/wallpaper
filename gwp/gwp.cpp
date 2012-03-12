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

int wmain( int argc, wchar_t ** argv)
{
	fs::path working_dir(fs::absolute(argv[0]).parent_path());
	// Initialize ImageMagick install location for Windows
	InitializeMagick(working_dir.string().c_str());

	wpl::init(working_dir / L"wp.db");
	wpl::clear();

	if (argc > 1) 
	{
		//wcout << L"argv1 " <<  argv[1] << endl;
		fs::path dir(argv[1]);
		if(fs::exists(dir)) {
			cout << dir << endl;
			wpl::add_directory(dir);
		}
		
		wpl::determine_order();
	}
	
	while(true) {
		int cur = wpl::get_position();
		fs::path path(wpl::get_path(++cur));
		cout <<   "switch to: " << path << endl;
		wpl::set_position(cur);
		wpc::setRegistry();
		try {
			wpc::convertWP(path, working_dir / L"wallpaper");
			wstring wppath( (working_dir / "wallpaper").wstring() );
			wchar_t* wpcstr = const_cast<wchar_t*>(wppath.c_str());
			wpc::setWP(wpcstr);
		}
		catch( exception &error_ )
		{
			cout << "Caught exception: " << error_.what() << endl;
			return 1;
		}
	}
	
	wpl::close();

	return 0;
}

int APIENTRY wWinMain(HINSTANCE hInstance,
                     HINSTANCE hPrevInstance,
                     LPTSTR    lpCmdLine,
                     int       nCmdShow)
{
	 return wmain(__argc,__wargv);
}


