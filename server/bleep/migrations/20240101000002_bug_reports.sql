-- Add bug_reports table for local bug report storage
-- Replaces remote saveBugReport functionality

CREATE TABLE bug_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    unique_id TEXT NOT NULL,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    text TEXT NOT NULL,
    app_version TEXT NOT NULL,
    metadata TEXT NOT NULL,
    server_log TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT (datetime('now'))
);

-- Indexes for common queries
CREATE INDEX idx_bug_reports_unique_id ON bug_reports(unique_id);
CREATE INDEX idx_bug_reports_created_at ON bug_reports(created_at);
CREATE INDEX idx_bug_reports_app_version ON bug_reports(app_version);
