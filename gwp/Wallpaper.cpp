#include "Wallpaper.h"
#include "Environment.h"
#include <vector>
#include <numeric>
using namespace Magick;


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


bool wpc::convertWP(const char* src) 
{
	using namespace std;

	auto env = getScreens();
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
	double abw = 1.2;
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
