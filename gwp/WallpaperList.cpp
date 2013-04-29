#include "WallpaperList.h"
#include <iostream>
#include <boost/filesystem.hpp>
#include "polarssl\sha1.h"
#define SOCI_USE_BOOST
#include <soci.h>
#include <backends\sqlite3\soci-sqlite3.h>
#include <string>
#include <algorithm>
#include <boost\optional.hpp>
#include <vector>
#include <boost\iterator\counting_iterator.hpp>
#include <atlstr.h>
#include <atlconv.h>

namespace fs = boost::filesystem;
using namespace soci;
using namespace std;
using namespace boost;

namespace wpl
{
	session sql;
	std::string hexdigest(const wstring& file);
}

std::string wpl::hexdigest(const wstring& file) 
{
	unsigned char sum[20];
	sha1_file(file.c_str(),sum);
	std::string hash(40,'X');
	auto it = hash.begin();
	for( int i = 0; i < 20; i++ ) 
	{
		*(it++) = "0123456789abcdef"[sum[i] >> 4];
		*(it++) = "0123456789abcdef"[sum[i] & 0x0f];
	}
	return hash;
}

bool wpl::init(const fs::path& file)
{
	sql.open(sqlite3,file.string());
	sql << "SELECT name FROM sqlite_master WHERE type='table' AND name='wallpaper'";
	if (sql.got_data())
	{
		return true;
	}
	transaction tr(sql); 
	sql << "CREATE TABLE wallpaper (position INT UNIQUE, sha1 CHAR UNIQUE, path CHAR UNIQUE, vote INT, fav INT, nsfw INT, remove INT)";
	sql << "CREATE TABLE config (position INT, current CHAR, wpdir CHAR)";
	sql << "INSERT INTO config VALUES (0,'',NULL)";
	tr.commit();
	return true;
}

void wpl::clear()
{
	sql << "DELETE FROM wallpaper";
	sql << "UPDATE config SET position = 0";
}

void wpl::list()
{
	std::cout << "list" << std::endl;
	rowset<row> rs = sql.prepare << "SELECT path,sha1 FROM wallpaper WHERE fav IS NOT NULL";
	for_each(rs.begin(), rs.end(), [](const row & r)
	{ 
		std::cout << r.get<string>(0) << " " << r.get<string>(1) << std::endl;
	});
}

fs::path wpl::get_path(int position)
{
	string path;
	sql << "SELECT path FROM wallpaper WHERE position = ?", into(path), use(position);
	return fs::path(CA2W(path.c_str(),CP_UTF8));
}

optional<std::pair<fs::path, string> > wpl::get_data(int position)
{
	optional<string> path;
	optional<string> hash;
	sql << "SELECT path, sha1 FROM wallpaper WHERE position = ? AND remove IS NULL", into(path), into(hash), use(position);
	if (!path) return optional<pair<fs::path,string> >();
	wstring wpath(CA2W(path->c_str(),CP_UTF8));
	if (hash) return make_optional(make_pair(fs::path(wpath),*hash));
	// generate unknown hash
	hash = hexdigest(wpath);
	optional<string> opath;
	sql << "SELECT path FROM wallpaper WHERE sha1 = ?", into(opath), use(*hash);
	if(!opath)
	{
		sql << "UPDATE wallpaper SET sha1 = ? WHERE position = ?", use(*hash), use(position);
		return make_optional(make_pair(fs::path(wpath),*hash));
	}
	// hash already present in db mark as remove
	sql << "UPDATE wallpaper SET remove = 1, sha1 = ? WHERE position = ?", use(*hash), use(position);
	return optional<pair<fs::path,string> >();
}

void wpl::remove(int pos)
{
	sql << "UPDATE wallpaper SET remove = 1 WHERE position = ?", use(pos);
}

std::pair<int,std::string> wpl::get_position()
{
	int pos;
	string hash;
	sql << "SELECT position, current FROM config", into(pos), into(hash);
	return make_pair(pos,hash);
}

void wpl::set_position(int pos, const string& hash)
{
	sql << "UPDATE config SET position = ?, current = ?", use(pos), use(hash);
}

void wpl::close()
{
	sql.close();
}

int wpl::max_position()
{
	int pos;
	sql << "SELECT max(position) FROM wallpaper", into(pos);
	return pos;
}

void wpl::set_wpdir(const fs::path& dir)
{
	string utf8_path(CW2A(dir.wstring().c_str(),CP_UTF8));
	sql << "UPDATE config SET wpdir = ?", use(utf8_path);
}

fs::path wpl::get_wpdir()
{
	string dir;
	sql << "SELECT wpdir FROM config", into(dir);
	return fs::path(CA2W(dir.c_str(),CP_UTF8));
}

void wpl::add_directory(const fs::path& dir)
{
	fs::recursive_directory_iterator iter(dir);
	fs::recursive_directory_iterator end;
	string path;
	transaction tr(sql);
	statement st = (sql.prepare << "INSERT OR IGNORE INTO wallpaper (path) VALUES (?)", use(path));
	for(; iter != end; ++iter)
	{
		auto p = iter->path();
		if (fs::is_directory(p))
		{
			std::cout << p << std::endl;
		}
		else if (fs::is_regular_file(p))
		{
			string ext(p.extension().string());
			if (ext == ".jpg" || ext == ".jpeg" 
			    || ext == ".png" || ext == ".bmp"
			    || ext == ".gif") {
				path.assign(CW2A(p.wstring().c_str(),CP_UTF8));
				st.execute(true);
			}
		}
	}
	tr.commit();
}

void wpl::determine_order()
{
	int rowid;
	statement st = (sql.prepare << "SELECT _rowid_ FROM wallpaper", into(rowid));
	st.execute();
	vector<int> ids;
	while(st.fetch()) 
	{
		ids.push_back(rowid);
	}
	vector<int> pos(counting_iterator<int>(1),counting_iterator<int>(ids.size() + 1));
	random_shuffle(pos.begin(),pos.end());
	transaction tr(sql);
	sql << "UPDATE wallpaper SET position = ? WHERE _rowid_ = ?", use(pos), use(ids);
	tr.commit();
}

void wpl::vote(const string& hash, int v)
{
	sql << "UPDATE wallpaper SET vote = ? WHERE sha1 = ?", use(v), use(hash);
}

void wpl::set_fav(const string& hash)
{
	sql << "UPDATE wallpaper SET fav = 1 WHERE sha1 = ?", use(hash);
}

void wpl::purge(const string& hash)
{
	sql << "UPDATE wallpaper SET nsfw = NULL, fav = NULL, vote = NULL, remove = NULL WHERE sha1 = ?", use(hash);
}
