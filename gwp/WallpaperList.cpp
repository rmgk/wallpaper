#include "WallpaperList.h"
#include "sqlite3.h"
#include <iostream>

namespace wpl {
	typedef sqlite3_stmt* stmtp;
	sqlite3* dbh;
	auto noop = [](stmtp){};
	template<class B, class F> void exec(const char* query, B bind, F fun = noop)
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