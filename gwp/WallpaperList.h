#pragma once
#include <string>

namespace wpl
{
	bool init(const char* file);
	void close();
	void list();
	std::string get_path(int position);
}