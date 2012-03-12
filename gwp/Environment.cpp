#include "Environment.h"


bool wpc::setRegistry()
{
	HKEY hKey=NULL;
	DWORD dwDisposition=0;
											//m_SUBKEY_TILEWALLPAPER( TEXT() ),
											//m_SUBKEY_WALLPAPERSTYLE( TEXT() ),
											//m_SUBKEY_WALLPAPER( TEXT("Wallpaper") ),


	if(RegCreateKeyExW(	HKEY_CURRENT_USER, 
									L"Control Panel\\Desktop", 
									0, 
									NULL, 
									REG_OPTION_NON_VOLATILE, 
									KEY_CREATE_SUB_KEY | KEY_ALL_ACCESS, 
									NULL, 
									&hKey, 
									&dwDisposition) != ERROR_SUCCESS) return false;
	

	/******************************************************************************** 
		Edit windows register settings in : [HKEY_CURRENT_USER\Control Panel\Desktop] 
		Value name : "TileWallpaper"
		this will activate tiling which is used to display different parts of the 
		image on different monitors
	*********************************************************************************/
	if(RegSetValueExW(	hKey,
										L"TileWallpaper",
										0,
										REG_SZ,
										(CONST BYTE *)L"1",
										2) != ERROR_SUCCESS) return false;
	


	/*********************************************************************************
		Edit windows register settings in : [HKEY_CURRENT_USER\Control Panel\Desktop] 
		Value name :"WallpaperStyle"
		this will position the wallpaper
	**********************************************************************************/
	if(RegSetValueExW(	hKey,
										L"WallpaperStyle",
										0,
										REG_SZ,
										(CONST BYTE *)L"0",
										2) != ERROR_SUCCESS) return false;
		
	RegCloseKey(hKey);

	// SUCCESS
	return TRUE;
}

int wpc::setWP(wchar_t* wp)
{
	return SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, wp, SPIF_UPDATEINIFILE);
}


BOOL CALLBACK MonitorEnumProc(
  __in  HMONITOR hMonitor,
  __in  HDC hdcMonitor,
  __in  LPRECT lprcMonitor,
  __in  LPARAM dwData
) 
{
	auto rect = (std::vector<RECT> *)dwData;
	rect->push_back(*lprcMonitor);
	return TRUE;
}

std::tuple<int,int,int,std::vector<RECT>> wpc::getScreens() 
{
	using namespace std;
	tuple<int,int,int,vector<RECT>> result;
	get<0>(result) = GetSystemMetrics(SM_CMONITORS);
	get<1>(result) = GetSystemMetrics(SM_CXVIRTUALSCREEN);
	get<2>(result) = GetSystemMetrics(SM_CYVIRTUALSCREEN);

	EnumDisplayMonitors(NULL,NULL,MonitorEnumProc,(LPARAM)&get<3>(result));

	/*for (auto it = get<3>(result).begin(); it != get<3>(result).end(); ++it) 
	{
		cout << it->left << " " << it->top << " " << it->right << " " << it->bottom << endl;
	}*/
	return result;
}