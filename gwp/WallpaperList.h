#pragma once
#include <string>

namespace wpl
{
	bool init(const char* file);
	void close();
	void list();
	std::string get_path(int position);
	bool create_tables();
	int get_position();
	void set_position(int pos);
	void add_directory(const std::string& dir);
	int max_position();
}