#pragma once

#include <Magick++.h>
#include <string>

namespace wpc
{
	void annotate(Magick::Image& image, const std::string& text, const Magick::Geometry& geo);
	void retarget(Magick::Image& image, int x, int y, double abw);

	void frame(Magick::Image& image,int x, int y);
	Magick::Color getBorderColor(Magick::Image& image, Magick::GravityType border);
};

