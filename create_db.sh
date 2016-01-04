#! /bin/ksh

cd "$HOME/video/TV Shows/Tatort"

sqlite3 tatorte.sqlite <<EOSQL
	create table if not exists tatort_history (
		movie_name TEXT UNIQUE,
		movie_name_long TEXT,
		commissar TEXT,
		state INTEGER,
		date TEXT
		);
EOSQL

