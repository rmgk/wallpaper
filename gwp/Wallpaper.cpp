#include "Wallpaper.h"

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