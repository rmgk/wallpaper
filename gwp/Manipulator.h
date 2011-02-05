#pragma once

#include <Magick++.h>
#include <string>

class Manipulator
{
public:
	Manipulator(void);
	~Manipulator(void);

	static void retarget(Magick::Image& image, int x, int y, double abw);
	static void annotate(Magick::Image& image, const std::string& text, const Magick::Geometry& geo);

private:
	static void frame(Magick::Image& image,int x, int y);
	static Magick::Color getBorderColor(Magick::Image& image, Magick::GravityType border);
};

