#include <Magick++.h>
#include <string>
#include <sstream>
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

fs::path working_dir;

void change_wp(std::pair<int,std::string>& position, int d)
{
	int& tpos = position.first;
	tpos = tpos + d;
	if (tpos < 1) return;
	int dir = (d > 0) - (d < 0);
	auto data = wpl::get_data(tpos);
	while (!data) {
		tpos += dir;
		data = wpl::get_data(tpos);
	}
	const fs::path& path = data->first;
	const string& hash = data->second;
	if (!wpc::convertWP(path, working_dir / L"wallpaper"))
	{
		wpl::remove(tpos);
		return change_wp(position,dir);
	}
	wstring wppath( (working_dir / L"wallpaper").wstring() );
	wpc::setWP(&*wppath.begin());
	wpl::set_position(tpos,hash);
	position.second = hash;
}

int wmain( int argc, wchar_t ** argv)
{
	try {
		working_dir = fs::absolute(argv[0]).parent_path();
		// Initialize ImageMagick install location for Windows
		InitializeMagick(working_dir.string().c_str());

		wpl::init(working_dir / L"wp.db");
		wpc::setRegistry();
		auto position = wpl::get_position();
		const unsigned long& pos(position.first);
		const string& hash(position.second);
		for (int i = 1; i < argc; ++i)
		{
			wstring cmd(argv[i]);
			if (false);
			else if (cmd == L"next") change_wp(position,1);
			else if (cmd == L"prev") change_wp(position,-1);
			else if (cmd == L"voteup") wpl::vote(hash,1);
			else if (cmd == L"votedown") wpl::vote(hash,-1);
			else if (cmd == L"fav") wpl::set_fav(hash);
			else if (cmd == L"purge") wpl::purge(hash);
			else 
			{
				fs::path dir(cmd);
				if(fs::exists(dir)) {
					cout << dir << endl;
					wpl::add_directory(dir);
					wpl::determine_order();
				}
			}
		}
		wpl::close();
	}
	catch( exception &error_ )
	{
		cout << "Caught exception: " << error_.what() << endl;
		return 1;
	}
	return 0;
}

int APIENTRY wWinMain(HINSTANCE hInstance,
                     HINSTANCE hPrevInstance,
                     LPTSTR    lpCmdLine,
                     int       nCmdShow)
{
	 return wmain(__argc,__wargv);
}


