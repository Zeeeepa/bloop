-- Add user_data table for local user information storage
-- Replaces remote saveUserData functionality

CREATE TABLE user_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    unique_id TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT (datetime('now')),
    updated_at DATETIME NOT NULL DEFAULT (datetime('now'))
);

-- Index for fast lookups by unique_id
CREATE INDEX idx_user_data_unique_id ON user_data(unique_id);
CREATE INDEX idx_user_data_email ON user_data(email);
