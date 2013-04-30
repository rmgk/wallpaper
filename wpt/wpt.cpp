#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
#include <atlconv.h>
#include <atlstr.h>
#include <iostream>
#include <iostream>
#include <Magick++.h>
#include <numeric>
#include <shellapi.h>
#include <sstream>
#include <string>
#include <tuple>
#include <vector>
#include <vector>
#include <Windows.h>

using namespace Magick;
using namespace std;

const DWORD filenameBufferLength = 1024;

namespace wpc
{
	void annotate(Magick::Image& image, const std::string& text, const Magick::Geometry& geo);
	void retarget(Magick::Image& image, int x, int y, double abw);
	bool convertWP(const std::wstring& src, const std::wstring& target);

	void frame(Magick::Image& image,int x, int y);
	Magick::Color getBorderColor(Magick::Image& image, Magick::GravityType border);


  // environment 
  bool setRegistry();
	int setWP(wchar_t* wp);
	std::tuple<int,int,int,std::vector<RECT>> getScreens();
};


wstring make_absolute(const std::wstring& path) {
  wchar_t buf[filenameBufferLength];
  GetFullPathName(path.c_str(),filenameBufferLength,buf,NULL);
  return wstring(buf);
}

void change_wp(const std::wstring& path)
{
  wstring out = make_absolute(L"wallpaper");
  wstring in = make_absolute(path);
	if (!wpc::convertWP(in, out))
	{
    throw exception("failed to convert wp");
	}
	wpc::setWP(&*out.begin());
}

int wmain( int argc, wchar_t ** argv)
{
	try {
		wstring working_dir = make_absolute(argv[0]);
		// Initialize ImageMagick install location for Windows
		InitializeMagick(CW2A(working_dir.c_str(),CP_UTF8));

		wpc::setRegistry();

		wstring file(argv[1]);

    change_wp(file);


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








/*********************************************************************************************************

wallpaper modifying stuff

**********************************************************************************************************/


Color wpc::getBorderColor(Image& image, GravityType border) 
{
	int red[16][16][16] = {0};
	int green[16][16][16] = {0};
	int blue[16][16][16] = {0};
	int count[16][16][16] = {0};
	int most_count = 0;
	short most[3] = {0};
	int average[3] = {0};
	int i_max;
	if (border == EastGravity || border == WestGravity)
		i_max = image.rows();
	else if (border == NorthGravity || border == SouthGravity)
		i_max = image.columns();
	else
		return Color("green");

	for (int i = 0; i < i_max ; i++) {
		Color c;
		switch(border)
		{
			case EastGravity : c = image.pixelColor(image.columns()-1,i); break; //rechts
			case WestGravity : c = image.pixelColor(0,i); break; //links
			case NorthGravity : c = image.pixelColor(i,0); break; //oben
			case SouthGravity : c = image.pixelColor(i,image.rows()-1); break; //unten
			default: c = Color("green");
		}
		short r = c.redQuantum()/16;
		short g = c.greenQuantum()/16;
		short b = c.blueQuantum()/16;
		int j = ++count[r][g][b];
		if (j > most_count) {
			most_count = j;
			most[0] = r;
			most[1] = g;
			most[2] = b;
		}
		red[r][g][b] += c.redQuantum();
		green[r][g][b] += c.greenQuantum();
		blue[r][g][b] += c.blueQuantum();

		average[0] += c.redQuantum();
		average[1] += c.greenQuantum();
		average[2] += c.blueQuantum();
	}

	if (most_count > i_max/20.0)
	{
		return Color(red[most[0]][most[1]][most[2]] / most_count, green[most[0]][most[1]][most[2]] / most_count, blue[most[0]][most[1]][most[2]] / most_count);
	}
	else
	{
		return Color(average[0] / i_max , average[1] / i_max , average[2] / i_max);
	}
}

void wpc::frame(Image& image,int x, int y)
{
	int w = image.columns();
	int h = image.rows();

	if ((float)w/(float)h < (float)x/(float)y)
	{
		//linksrechts
		//rechts
		image.backgroundColor(getBorderColor(image,EastGravity));
		image.splice(Geometry((x - w) / 2, 0, w, 0));

		//links
		image.backgroundColor(getBorderColor(image,WestGravity));
		image.splice(Geometry((x-w)/2,0,0,0));

	}
	else 
	{
		//obenunten
		//unten
		image.backgroundColor(getBorderColor(image,SouthGravity));
		image.splice(Geometry(0, (y-h)/2, 0, h));

		//oben
		image.backgroundColor(getBorderColor(image,NorthGravity));
		image.splice(Geometry(0, (y-h)/2, 0, 0));

	}
}

void wpc::retarget(Image& image, int x, int y, double abw)
{
	float iz = (float)image.columns() / (float)image.rows();
	float tz = (float)x/(float)y;
	if ((iz < tz * abw) && (iz > tz / abw)) {
		Geometry geo(x,y);
		geo.aspect(true);
		image.resize(geo);
	}
	else 
	{
		image.resize(Geometry(x,y));
		frame(image,x,y);
	}
}

void wpc::annotate(Image& image, const std::string& text, const Geometry& geo)
{
	image.strokeAntiAlias(true);
	Color old = image.strokeColor();
	image.font("Arial");
	image.fontPointsize(14);
	image.strokeColor("rgba(0,0,0,0.3)");
	image.strokeWidth(3);
	image.annotate(text,geo,SouthEastGravity);
	image.strokeColor(old);
	old = image.fillColor();
	image.fillColor("rgba(255,255,255,0.9)");
	image.strokeWidth(2);
	image.annotate(text,geo,SouthEastGravity);
	image.fillColor(old);
}


bool wpc::convertWP(const wstring& src, const wstring& target)
{
	using namespace std;

	auto env = getScreens();
	int numScreens = get<0>(env);
	auto screens = get<3>(env);
	vector<int> width;
	vector<int> height;
	int width_total = get<1>(env);
	int height_total = get<2>(env);
	//std::cout << "number of screens: " << numScreens << "\n total width: " << width_total << " total height: " << height_total << std::endl;
	for (int i = 0; i < numScreens; ++i)
	{
		width.push_back(screens[i].right - screens[i].left);
		height.push_back(screens[i].bottom - screens[i].top);
		//std::cout << "screen " << i << "\n width: " << width[i] << " height: " << height[i] << "\n x: " << screens[i].left << " y: " << screens[i].top << endl;
	}
	int min_width = accumulate(width.begin(),width.end(),0) / get<0>(env) / 2;
	int min_height = accumulate(height.begin(),height.end(),0) / get<0>(env) / 2;
	double abw = 1.2;

	//string utf8_path(boost::locale::conv::utf_to_utf<char,wchar_t>(src.wstring()));
	string utf8_path(CW2A(src.c_str(),CP_UTF8));

	Image orig( utf8_path );
	//discard small images
	if(orig.rows() < min_height || orig.columns() < min_width)
		return false;
	//add white background for transparent images
	orig.extent(Geometry(orig.columns(),orig.rows()),"white");

	Image canvas;
	if (numScreens > 1) {
		canvas.backgroundColor("pink");
		canvas.extent(Geometry(width_total,height_total));
		for (int i = 0; i < numScreens; ++i)
		{
			Image temp(orig);
			wpc::retarget(temp,width[i],height[i],abw);
			if (i == numScreens - 1)
			{
				string text(CW2A(src.c_str(),CP_UTF8));
				wpc::annotate(temp,text,"+0+2");
			}
			
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
	else {
		wpc::retarget(orig,width[0],height[0],abw);
		canvas = orig;
	}

	canvas.magick("BMP3");
	canvas.write(string(CW2A(target.c_str(),CP_UTF8)));

	return true;
}









/*********************************************************************************************************

environmental stuff below here

**********************************************************************************************************/


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