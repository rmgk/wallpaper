#pragma once
#include <string>
#include <boost/filesystem.hpp>

namespace wpl
{
	bool init(const boost::filesystem::path& file);
	void close();
	void list();
	boost::filesystem::path get_path(int position);
	int get_position();
	void set_position(int pos);
	void add_directory(const boost::filesystem::path& dir);
	int max_position();
	void set_wpdir(const boost::filesystem::path& dir);
	boost::filesystem::path get_wpdir();
	void determine_order();
	bool clear();
}
