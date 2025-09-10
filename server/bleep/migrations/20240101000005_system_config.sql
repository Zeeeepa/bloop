-- Add system_config table for local system configuration storage
-- Replaces remote getDiscordLink and other system configuration functionality

CREATE TABLE system_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    created_at DATETIME NOT NULL DEFAULT (datetime('now')),
    updated_at DATETIME NOT NULL DEFAULT (datetime('now'))
);

-- Index for fast lookups by key
CREATE INDEX idx_system_config_key ON system_config(key);

-- Insert default configuration values
INSERT INTO system_config (key, value, description) VALUES 
    ('discord_url', 'https://discord.gg/bloop', 'Discord community invite link'),
    ('update_check_enabled', 'false', 'Enable/disable automatic update checking'),
    ('analytics_enabled', 'false', 'Enable/disable analytics collection'),
    ('feedback_enabled', 'true', 'Enable/disable user feedback collection');
