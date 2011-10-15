#include "WallpaperList.h"
#include "sqlite3.h"
#include <iostream>
#include <boost/filesystem.hpp>
#include "polarssl\sha1.h"

namespace fs = boost::filesystem;

namespace wpl {
	typedef sqlite3_stmt* stmtp;
	sqlite3* dbh;
	auto noop = [](stmtp){};
	template<class B, class F> void exec(const char* query, B bind, F fun);
	std::string hexdigest(const char* file);
}

std::string wpl::hexdigest(const char* file) 
{
	unsigned char sum[20];
	sha1_file(file,sum);
	std::string hash(40,'X');
	auto it = hash.begin();
	for( int i = 0; i < 20; i++ ) 
	{
		*(it++) = "0123456789abcdef"[sum[i] >> 4];
		*(it++) = "0123456789abcdef"[sum[i] & 0x0f];
	}
	return hash;
}

template<class B, class F> void wpl::exec(const char* query, B bind, F fun)
{
	sqlite3_stmt* sth;
	int rc;
	if( (rc = sqlite3_prepare(dbh,query,-1,&sth,NULL)) != 0) 
	{
		std::cout << sqlite3_errmsg(dbh) << std::endl;
	}
	bind(sth);
	while ( (rc = sqlite3_step(sth)) == SQLITE_ROW )
	{
		fun(sth);
	}
	if (rc != SQLITE_DONE) 
	{
		std::cout << sqlite3_errmsg(dbh) << std::endl;
	}
	sqlite3_finalize(sth);
}

bool wpl::init(const char* file) 
{
    if (int rc = sqlite3_open(file, &dbh)) 
	{
		return false;
	}
	sqlite3_stmt* sth;
	sqlite3_prepare(dbh,"SELECT name FROM sqlite_master WHERE type='table' AND name='wallpaper'",-1,&sth,NULL);
	if (sqlite3_step(sth) == SQLITE_ROW)
	{
		sqlite3_finalize(sth);
		return true;
	}
	sqlite3_finalize(sth);
	sqlite3_exec(dbh,"CREATE TABLE wallpaper (position INT UNIQUE, sha1 CHAR UNIQUE, path CHAR UNIQUE, discard INT, fav INT, nsfw INT, remove INT)",NULL,NULL,NULL);
	sqlite3_exec(dbh,"CREATE TABLE config (position INT, current CHAR, wppath CHAR)",NULL,NULL,NULL);
	sqlite3_exec(dbh,"INSERT INTO config VALUES (0,NULL,NULL)",NULL,NULL,NULL);
	return true;
}

void wpl::list()
{
	std::cout << "list" << std::endl;
	exec("SELECT path,sha1 FROM wallpaper WHERE fav IS NOT NULL",noop,
		[](sqlite3_stmt* sth)
		{ 
			std::cout << sqlite3_column_text(sth,0) << " " << sqlite3_column_text(sth,1) << std::endl; 
		});
}

std::string wpl::get_path(int position)
{
	std::string result;
	exec("SELECT path FROM wallpaper WHERE position = ?",
		[position](stmtp sth){ sqlite3_bind_int(sth,1,position); },
		[&result](stmtp sth)
		{
			result.assign(reinterpret_cast<const char*>(sqlite3_column_text(sth,0)));
		});
	return result;
}

int wpl::get_position()
{
	int res;
	exec("SELECT position FROM config",noop,[&res](sqlite3_stmt* sth){ res = sqlite3_column_int(sth,0); });
	return res;
}

void wpl::set_position(int position)
{
	exec("UPDATE config SET position = ?", 
		[position](stmtp sth){ sqlite3_bind_int(sth,1,position); }, 
		noop);
}


void wpl::close()
{
	sqlite3_close(dbh);
}

int wpl::max_position()
{
	int pos;
	exec("SELECT max(position) FROM wallpaper",noop,
		[&pos](stmtp sth){
			pos = sqlite3_column_int(sth,0);
		});
	return pos;
}

void wpl::add_directory(const std::string& dir)
{
	fs::recursive_directory_iterator iter(dir);
	fs::recursive_directory_iterator end;
	int last = max_position();
	exec("BEGIN",noop,noop);
	sqlite3_stmt* sth;
	sqlite3_prepare(dbh,"INSERT OR REPLACE INTO wallpaper (position,path) VALUES (?,?)",-1,&sth,NULL);
	for(; iter != end; ++iter)
	{
		auto p = iter->path();
		if (fs::is_directory(p))
		{
			std::cout << p << std::endl;
		}
		else if (fs::is_regular_file(p))
		{
			std::string path(p.generic_string().substr(dir.length(),-1));
			const char* cpath(path.c_str());
			int path_length = path.length() + 1;
			sqlite3_bind_int(sth, 1, ++last);
			sqlite3_bind_text(sth, 2, cpath, path_length, SQLITE_STATIC);
			sqlite3_step(sth);
			sqlite3_reset(sth);
		}
	}
	sqlite3_finalize(sth);
	exec("COMMIT",noop,noop);
}

