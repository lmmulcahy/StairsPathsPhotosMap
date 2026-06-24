CREATE TABLE IF NOT EXISTS stairpaths (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    startLatitude REAL NOT NULL,
    startLongitude REAL NOT NULL,
    endLatitude REAL NOT NULL,
    endLongitude REAL NOT NULL,
    pathData TEXT
);
