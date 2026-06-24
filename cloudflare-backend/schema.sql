-- Full reference schema. The Worker never runs CREATE TABLE (see CLAUDE.md); apply
-- changes to D1 by hand via `wrangler d1 execute` and keep this file in sync.

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
    object_key TEXT,
    status TEXT NOT NULL DEFAULT 'approved'   -- 'approved' | 'pending'
);

-- Pending path additions/edits awaiting admin review (see migrations/0001_review_queue.sql).
CREATE TABLE IF NOT EXISTS submissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,                              -- 'create' | 'edit'
    target_id INTEGER,
    payload TEXT NOT NULL,                          -- JSON path payload
    submitter TEXT,
    status TEXT NOT NULL DEFAULT 'pending',         -- 'pending' | 'approved' | 'rejected'
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    reviewed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_submissions_status ON submissions(status);
CREATE INDEX IF NOT EXISTS idx_photos_status ON photos(stairpath_id, status);
