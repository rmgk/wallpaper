#include "WallpaperList.h"
#include "sqlite3.h"
#include <iostream>

sqlite3* dbh;

bool wpl::init(const char* file) 
{
    return !sqlite3_open(file, &dbh);
}

void wpl::list()
{
	std::cout << "list" << std::endl;
	sqlite3_stmt* sth; 
	sqlite3_prepare_v2(dbh,"SELECT path,sha1 FROM wallpaper WHERE fav IS NOT NULL",-1,&sth,NULL);
	int rc;
	while( rc = sqlite3_step(sth) == SQLITE_ROW) 
	{
		std::cout << sqlite3_column_text(sth,0) << " " << sqlite3_column_text(sth,1) << std::endl;
	}
	sqlite3_finalize(sth);
	
}

std::string wpl::get_path(int position)
{
	sqlite3_stmt* sth; 
	sqlite3_prepare_v2(dbh,"SELECT path FROM wallpaper WHERE position = ?",-1,&sth,NULL);
	sqlite3_bind_int(sth,1,position);
	sqlite3_step(sth);
	const unsigned char* str = sqlite3_column_text(sth,0);
	std::string result;
	if (str)
		result.assign((char*)str);
	sqlite3_finalize(sth);
	return result;
}

void wpl::close()
{
	sqlite3_close(dbh);
}