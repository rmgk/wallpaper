#pragma once

#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
#include <windows.h>

#include <vector>
#include <tuple>

namespace wpc 
{
	bool setRegistry();
	int setWP(char* wp);
	std::tuple<int,int,int,std::vector<RECT>> getScreens();
}