#pragma once
#include <string>
#include <tuple>
#include <boost/filesystem.hpp>
#include <boost/optional.hpp>

namespace wpl
{
	bool init(const boost::filesystem::path& file);
	void close();
	void list();
	boost::filesystem::path get_path(int position);
	std::pair<int,std::string> get_position();
	void set_position(int pos, const std::string& hash);
	void add_directory(const boost::filesystem::path& dir);
	int max_position();
	void set_wpdir(const boost::filesystem::path& dir);
	boost::filesystem::path get_wpdir();
	void determine_order();
	void clear();
	void vote(const std::string& hash, int v);
	void set_fav(const std::string& hash);
	void purge(const std::string& hash);
	boost::optional<std::pair<boost::filesystem::path, std::string> > get_data(int position);
	void remove(int pos);
}
