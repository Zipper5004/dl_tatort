#! /bin/ksh

sqlite3 tatorte.db <<EOSQL
	create table if not exists tartort_history (
		movie_name TEXT UNIQUE, 
		state INTEGER,
		date TEXT
		);
EOSQL

