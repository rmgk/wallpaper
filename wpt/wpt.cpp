#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
#include <atlconv.h>
#include <atlstr.h>
#include <iostream>
#include <Magick++.h>
#include <numeric>
#include <shellapi.h>
#include <sstream>
#include <string>
#include <tuple>
#include <vector>
#include <Windows.h>
#include <conio.h>
#include <stdio.h>
#include <fcntl.h>
#include <io.h>

using namespace Magick;
using namespace std;

const DWORD filenameBufferLength = 1024;

namespace wpc
{

  wstring make_absolute(const std::wstring& path);


  // image manipulation
  void annotate(Magick::Image& image, const std::string& text, const Magick::Geometry& geo, Magick::GravityType gravity);
  void positionAnnotation(const RECT& area, const RECT& warea, Magick::Image& image, const std::string& text, const Magick::Geometry& geo, Magick::GravityType gravity);
  void retarget(Magick::Image& image, int x, int y);
  bool convertWP(const std::wstring& src, const std::wstring& target, const Magick::Geometry& textPlacementPosition, Magick::GravityType textGravity);

  void frame(Magick::Image& image,int x, int y);
  Magick::Color getBorderColor(Magick::Image& image, Magick::GravityType border);
  bool similarAspect(int ox, int oy, int tx, int ty);


  // environment

  struct screenInfo {
    int count;
    int virtual_x;
    int virtual_y;
    vector<RECT> areas;
    vector<RECT> working_areas;
  };

  bool setRegistry();
  int setWP(wchar_t* wp);
  screenInfo getScreens();
  bool isWin8orLater();
};


wstring wpc::make_absolute(const std::wstring& path) {
  wchar_t buf[filenameBufferLength];
  GetFullPathName(path.c_str(),filenameBufferLength,buf,NULL);
  return wstring(buf);
}

int wmain( int argc, wchar_t ** argv)
{
  try {
    wstring working_dir = wpc::make_absolute(argv[0]);
    // Initialize ImageMagick install location for Windows
    InitializeMagick(CW2A(working_dir.c_str(),CP_UTF8));
    wpc::setRegistry();

    wstring infile;
    wstring outfile = wpc::make_absolute(L"wallpaper");

	auto annotationPosition = Geometry(0,0,1,3);
	Magick::GravityType annotationGravity = Magick::SouthEastGravity;

	if (argc > 5) {
		annotationPosition = Geometry(CW2A(argv[4], CP_UTF8));
		annotationGravity = static_cast<GravityType>(std::stoi(argv[5]));
	}

    if (argc == 1) {
      cout << L"<path>" << endl;
      return -1;
    }
    else if (argc == 2) {
      infile = wpc::make_absolute(argv[1]);
      wpc::convertWP(infile, outfile, annotationPosition, annotationGravity);
      wpc::setWP(&*outfile.begin());
      infile[0];
    }
    else {
      wstring command(argv[1]);
      if (command == L":convert") {
        if (argc < 4) {
          cout << L"<inpath> <outpath>" << endl;
          return -1;
        }
        infile = wpc::make_absolute(argv[2]);
        outfile = wpc::make_absolute(argv[3]);
        wpc::convertWP(infile,outfile, annotationPosition, annotationGravity);
      }
      else if (command == L":convertset") {
        if (argc < 4) {
          cout << L"<inpath> <outpath>" << endl;
          return -1;
        }
        infile = wpc::make_absolute(argv[2]);
        outfile = wpc::make_absolute(argv[3]);
        wpc::convertWP(infile,outfile, annotationPosition, annotationGravity);
        wpc::setWP(&*outfile.begin());
      }
      else if (command == L":set") {
        if (argc < 3) {
          cout << L"<outpath>" << endl;
          return -1;
        }
        outfile = wpc::make_absolute(argv[2]);
        wpc::setWP(&*outfile.begin());
      }
    }

  }
  catch( exception &error_ )
  {
    cout << "Caught exception: " << error_.what() << endl;
    return 1;
  }
  return 0;
}

int APIENTRY wWinMain(HINSTANCE /*hInstance*/,
                     HINSTANCE /*hPrevInstance*/,
                     LPTSTR    /*lpCmdLine*/,
                     int       /*nCmdShow*/)
{

  int hConHandle;
  long lStdHandle;
  FILE *fp;
  int iVar;

  // Try to attach to a console
  if (AttachConsole (ATTACH_PARENT_PROCESS)) {

    // redirect unbuffered STDOUT to the console
    lStdHandle = (long)GetStdHandle(STD_OUTPUT_HANDLE);
    hConHandle = _open_osfhandle(lStdHandle, _O_TEXT);
    fp = _fdopen( hConHandle, "w" );
    *stdout = *fp;
    setvbuf( stdout, NULL, _IONBF, 0 );

    // redirect unbuffered STDIN to the console
    lStdHandle = (long)GetStdHandle(STD_INPUT_HANDLE);
    hConHandle = _open_osfhandle(lStdHandle, _O_TEXT);
    fp = _fdopen( hConHandle, "r" );
    *stdin = *fp;
    setvbuf( stdin, NULL, _IONBF, 0 );

    // redirect unbuffered STDERR to the console
    lStdHandle = (long)GetStdHandle(STD_ERROR_HANDLE);
    hConHandle = _open_osfhandle(lStdHandle, _O_TEXT);
    fp = _fdopen( hConHandle, "w" );
    *stderr = *fp;
    setvbuf( stderr, NULL, _IONBF, 0 );

  }

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
    short r = c.quantumRed()/16;
    short g = c.quantumGreen()/16;
    short b = c.quantumBlue()/16;
    int j = ++count[r][g][b];
    if (j > most_count) {
      most_count = j;
      most[0] = r;
      most[1] = g;
      most[2] = b;
    }
    red[r][g][b] += c.quantumRed();
    green[r][g][b] += c.quantumGreen();
    blue[r][g][b] += c.quantumBlue();

    average[0] += c.quantumRed();
    average[1] += c.quantumGreen();
    average[2] += c.quantumBlue();
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

void wpc::retarget(Image& image, int x, int y)
{
  if (similarAspect(image.columns(), image.rows(), x, y)) {
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

void wpc::annotate(Image& image, const std::string& text, const Geometry& geo, Magick::GravityType gravity)
{
  image.strokeAntiAlias(true);
  Color old = image.strokeColor();
  image.font("Arial");
  image.fontPointsize(14);
  image.strokeColor("rgba(0,0,0,0.3)");
  image.strokeWidth(3);
  image.annotate(text,geo, gravity);
  image.strokeColor(old);
  old = image.fillColor();
  image.fillColor("rgba(255,255,255,0.9)");
  image.strokeWidth(2);
  image.annotate(text,geo, gravity);
  image.fillColor(old);
}

void wpc::positionAnnotation(const RECT& area, const RECT& warea, Magick::Image& image, const std::string& text, const Magick::Geometry& geo, Magick::GravityType gravity) 
{
	auto geoCopy(geo);
	if (gravity % 3 == 0) {
		geoCopy.xOff(geoCopy.xOff() + area.right - warea.right);
	}
	if (gravity % 3 == 1) {
		geoCopy.xOff(geoCopy.xOff() - area.left + warea.left);
	}
	if ((gravity - 1) / 3 == 0) {
		geoCopy.yOff(geoCopy.yOff() - area.top + warea.top);
	}
	if ((gravity - 1) / 3 == 2) {
		geoCopy.yOff(geoCopy.yOff() + area.bottom - warea.bottom);
	}
	
	wpc::annotate(image, text, geoCopy, gravity);
}

bool wpc::convertWP(const wstring& src, const wstring& target, const Geometry& textPlacementPosition, Magick::GravityType textGravity)
{
  using namespace std;

  auto env = getScreens();
  int numScreens = env.count;
  auto screens = env.areas;
  vector<int> width;
  vector<int> height;
  int width_total = env.virtual_x;
  int height_total = env.virtual_y;
  int leftmost_coordinate = 0;
  int topmost_coordinate = 0;
  // std::cout << "number of screens: " << numScreens << "\n total width: " << width_total << " total height: " << height_total << std::endl;
  for (int i = 0; i < numScreens; ++i)
  {
    width.push_back(screens[i].right - screens[i].left);
    height.push_back(screens[i].bottom - screens[i].top);
    if (screens[i].left < leftmost_coordinate)
      leftmost_coordinate = screens[i].left;
    if (screens[i].top < topmost_coordinate)
      topmost_coordinate = screens[i].top;
    // std::cout << "screen " << i << "\n width: " << width[i] << " height: " << height[i] << "\n x: " << screens[i].left << " y: " << screens[i].top << endl;
  }
  size_t min_accepted_width = accumulate(width.begin(),width.end(),0) / numScreens / 2;
  size_t min_accepted_height = accumulate(height.begin(),height.end(),0) / numScreens / 2;

  string utf8_path(CW2A(src.c_str(),CP_UTF8));

  Image orig( utf8_path );
  //discard small images
  if(orig.rows() < min_accepted_height || orig.columns() < min_accepted_width)
    throw exception("image too small");
  //add white background for transparent images
  orig.extent(Geometry(orig.columns(),orig.rows()),"white");

  // std::cout << "leftmost: " << leftmost_coordinate << endl;
  // std::cout << "topmost: " << topmost_coordinate << endl;

  string annotation(CW2A(src.c_str(),CP_UTF8));

  bool win8 = isWin8orLater();
  Image canvas("1x1", "pink");
  // first case tries to handle multi monitor images … experimental!
  if (similarAspect(orig.columns(), orig.rows(), width_total, height_total) && win8 && numScreens > 1) {
    wpc::retarget(orig, width_total, height_total);
    const auto& ls = env.working_areas[numScreens - 1];
    auto geo = Geometry(ls.right - leftmost_coordinate,ls.bottom - topmost_coordinate,1,3);
    wpc::annotate(orig,annotation,geo, textGravity);
    canvas = orig;
  }
  else if (numScreens > 1) {
    canvas.backgroundColor("pink");
    canvas.extent(Geometry(width_total,height_total));
    for (int i = 0; i < numScreens; ++i)
    {
      Image temp(orig);
      wpc::retarget(temp,width[i],height[i]);
      if (i == numScreens - 1) {
        const auto& area = env.areas[i];
        const auto& warea = env.working_areas[i];
		positionAnnotation(area, warea, temp, annotation, textPlacementPosition, textGravity);
      }

      int x = screens[i].left;
      int y = screens[i].top;
      /* when in tiling wallpaper mode, the origin is at the upper left corner of the
       * primary monitor. if any secondary monitor is left or above the primary its
       * coordinates will be negative. adding the total size to the negative position
       * gives the correct position but that may cause the image to overflow.
       * if it overflows it needs to be drawn again at the original position which
       * causes the oveflown part to be drawn at the correct position.
       *
       * this is no longer true for windows 8
       */
      if (!win8) {
        if (x < 0) x += width_total;
        if (y < 0) y += height_total;
        canvas.composite(temp,x,y);
        if (x + width[i] > width_total)
          canvas.composite(temp,x-width_total,y);
        if (y + height[i] > height_total)
          canvas.composite(temp,x,y-height_total);
      }
      /* win8 has the origin of the wallpaper at the upper left edge of the total virtual space.
       * but the screen coordinates still have the origin at the upper left edge of the primary monitor.
       * thus we subtract the leftmost and topmost coordinates any screen has from the x and y coordinates,
       * to get the correct positions. be aware that these are negative
       */
      else {
        canvas.composite(temp, x - leftmost_coordinate, y - topmost_coordinate);
      }
    }

  }
  else {
    wpc::retarget(orig,width[0],height[0]);
    const auto& area = env.areas[0];
    const auto& warea = env.working_areas[0];
	positionAnnotation(area, warea, orig, annotation, textPlacementPosition, textGravity);
    canvas = orig;
  }

  canvas.magick("BMP3");
  canvas.write(string(CW2A(target.c_str(),CP_UTF8)));

  return true;
}

bool wpc::similarAspect(int ox, int oy, int tx, int ty) {
  float abw = 1.2f;
  float iz = (float)ox / (float)oy;
  float tz = (float)tx / (float)ty;
  return ((iz < tz * abw) && (iz > tz / abw));
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


  if(RegCreateKeyEx(  HKEY_CURRENT_USER,
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
  if(RegSetValueEx( hKey,
                    L"TileWallpaper",
                    0,
                    REG_SZ,
                    (CONST BYTE *)L"1", //"1" activates tiling
                    3) != ERROR_SUCCESS) return false;



  /*********************************************************************************
    Edit windows register settings in : [HKEY_CURRENT_USER\Control Panel\Desktop]
    Value name :"WallpaperStyle"
    this will position the wallpaper
  **********************************************************************************/
  if(RegSetValueEx( hKey,
                    L"WallpaperStyle",
                    0,
                    REG_SZ,
                    (CONST BYTE *)L"0", // "22" displays „spanning“
                    3) != ERROR_SUCCESS) return false;

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
  __in  HDC /*hdcMonitor*/,
  __in  LPRECT /*lprcMonitor*/,
  __in  LPARAM dwData
)
{
  auto rect = (wpc::screenInfo *)dwData;
  MONITORINFO mi;
  mi.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(hMonitor, &mi);
  rect->areas.push_back(mi.rcMonitor);
  rect->working_areas.push_back(mi.rcWork);
  return TRUE;
}

wpc::screenInfo wpc::getScreens()
{
  using namespace std;
  screenInfo result;
  result.count = GetSystemMetrics(SM_CMONITORS);
  result.virtual_x = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  result.virtual_y = GetSystemMetrics(SM_CYVIRTUALSCREEN);
  result.areas.reserve(result.count);
  result.working_areas.reserve(result.count);


  EnumDisplayMonitors(NULL,NULL,MonitorEnumProc,(LPARAM)&result);

  /*for (auto it = get<3>(result).begin(); it != get<3>(result).end(); ++it)
  {
    cout << it->left << " " << it->top << " " << it->right << " " << it->bottom << endl;
  }*/
  return result;
}


bool wpc::isWin8orLater() {
    OSVERSIONINFO osvi;
    bool bIsWin8orLater;

    ZeroMemory(&osvi, sizeof(OSVERSIONINFO));
    osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);

    GetVersionEx(&osvi);

    bIsWin8orLater =
       ( (osvi.dwMajorVersion > 6) ||
       ( (osvi.dwMajorVersion == 6) && (osvi.dwMinorVersion >= 2) ));

    return bIsWin8orLater;
}
