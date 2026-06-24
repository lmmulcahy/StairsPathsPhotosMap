CREATE TABLE IF NOT EXISTS stairpaths (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    startLatitude REAL NOT NULL,
    startLongitude REAL NOT NULL,
    endLatitude REAL NOT NULL,
    endLongitude REAL NOT NULL,
    pathData TEXT
);

CREATE TABLE IF NOT EXISTS photos (
    id TEXT PRIMARY KEY,
    stairpath_id INTEGER,
    object_key TEXT
);
