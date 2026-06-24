-- Review queue migration.
--
-- Apply to local and remote D1 with:
--   npx wrangler d1 execute stairs_paths_db --local  --file=migrations/0001_review_queue.sql
--   npx wrangler d1 execute stairs_paths_db --remote --file=migrations/0001_review_queue.sql
--
-- Note: the Worker never runs CREATE TABLE itself; schema changes are applied by hand
-- (see CLAUDE.md). schema.sql mirrors the full resulting schema for reference.

-- Pending path additions/edits submitted by anonymous users (iOS app).
CREATE TABLE IF NOT EXISTS submissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL,                              -- 'create' | 'edit'
    target_id INTEGER,                              -- stairpath being edited (NULL for 'create')
    payload TEXT NOT NULL,                          -- JSON: { name, start/end lat/lng, pathData }
    submitter TEXT,                                 -- optional free-text identifier
    status TEXT NOT NULL DEFAULT 'pending',         -- 'pending' | 'approved' | 'rejected'
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    reviewed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_submissions_status ON submissions(status);

-- Photos gain a moderation status. Existing rows default to 'approved' so nothing that is
-- already live disappears; new public uploads are inserted as 'pending'.
ALTER TABLE photos ADD COLUMN status TEXT NOT NULL DEFAULT 'approved';

CREATE INDEX IF NOT EXISTS idx_photos_status ON photos(stairpath_id, status);
