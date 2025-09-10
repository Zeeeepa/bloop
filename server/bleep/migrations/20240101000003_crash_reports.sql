-- Add crash_reports table for local crash report storage
-- Replaces remote saveCrashReport functionality

CREATE TABLE crash_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    unique_id TEXT NOT NULL,
    email TEXT,
    name TEXT,
    text TEXT NOT NULL,
    info TEXT NOT NULL,
    metadata TEXT NOT NULL,
    app_version TEXT NOT NULL,
    server_log TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT (datetime('now'))
);

-- Indexes for common queries
CREATE INDEX idx_crash_reports_unique_id ON crash_reports(unique_id);
CREATE INDEX idx_crash_reports_created_at ON crash_reports(created_at);
CREATE INDEX idx_crash_reports_app_version ON crash_reports(app_version);
