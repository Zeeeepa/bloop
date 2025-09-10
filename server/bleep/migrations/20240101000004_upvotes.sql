-- Add upvotes table for local user feedback storage
-- Replaces remote saveUpvote/getUpvote functionality

CREATE TABLE upvotes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    unique_id TEXT NOT NULL,
    snippet_id TEXT NOT NULL,
    query TEXT NOT NULL,
    text TEXT NOT NULL,
    is_upvote BOOLEAN NOT NULL,
    created_at DATETIME NOT NULL DEFAULT (datetime('now')),
    updated_at DATETIME NOT NULL DEFAULT (datetime('now')),
    
    -- Ensure one vote per user per snippet per query
    UNIQUE(unique_id, snippet_id, query)
);

-- Indexes for common queries
CREATE INDEX idx_upvotes_unique_id ON upvotes(unique_id);
CREATE INDEX idx_upvotes_snippet_id ON upvotes(snippet_id);
CREATE INDEX idx_upvotes_query ON upvotes(query);
CREATE INDEX idx_upvotes_created_at ON upvotes(created_at);
