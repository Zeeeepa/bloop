-- Event Contexts Migration
-- This migration creates tables for storing all event contexts and interactions
-- for the local Codex agent integration

-- Event contexts table - stores all interaction contexts
CREATE TABLE event_contexts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    user_id TEXT,
    event_type VARCHAR(50) NOT NULL, -- 'chat', 'code_completion', 'search', 'file_edit', etc.
    context_data JSONB NOT NULL, -- Flexible JSON storage for context data
    metadata JSONB DEFAULT '{}', -- Additional metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Interaction logs table - stores all user-AI interactions
CREATE TABLE interaction_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    event_context_id UUID REFERENCES event_contexts(id) ON DELETE CASCADE,
    interaction_type VARCHAR(50) NOT NULL, -- 'request', 'response', 'error', 'system'
    content TEXT NOT NULL,
    tokens_used INTEGER DEFAULT 0,
    processing_time_ms INTEGER DEFAULT 0,
    model_used VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Context streams table - manages streaming contexts to Codex agent
CREATE TABLE context_streams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    stream_type VARCHAR(50) NOT NULL, -- 'active', 'historical', 'project', 'file'
    context_payload JSONB NOT NULL,
    stream_status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'streaming', 'completed', 'failed'
    priority INTEGER DEFAULT 0, -- Higher numbers = higher priority
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    streamed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Agent sessions table - tracks Codex agent sessions
CREATE TABLE agent_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    agent_config JSONB DEFAULT '{}',
    session_status VARCHAR(20) DEFAULT 'active', -- 'active', 'inactive', 'expired'
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '24 hours'
);

-- Event context relationships table - tracks relationships between contexts
CREATE TABLE context_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_context_id UUID REFERENCES event_contexts(id) ON DELETE CASCADE,
    child_context_id UUID REFERENCES event_contexts(id) ON DELETE CASCADE,
    relationship_type VARCHAR(50) NOT NULL, -- 'follows', 'references', 'depends_on', 'spawned_from'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(parent_context_id, child_context_id, relationship_type)
);

-- Create indexes for performance
CREATE INDEX idx_event_contexts_session_id ON event_contexts(session_id);
CREATE INDEX idx_event_contexts_user_id ON event_contexts(user_id);
CREATE INDEX idx_event_contexts_event_type ON event_contexts(event_type);
CREATE INDEX idx_event_contexts_created_at ON event_contexts(created_at);

CREATE INDEX idx_interaction_logs_session_id ON interaction_logs(session_id);
CREATE INDEX idx_interaction_logs_event_context_id ON interaction_logs(event_context_id);
CREATE INDEX idx_interaction_logs_interaction_type ON interaction_logs(interaction_type);
CREATE INDEX idx_interaction_logs_created_at ON interaction_logs(created_at);

CREATE INDEX idx_context_streams_session_id ON context_streams(session_id);
CREATE INDEX idx_context_streams_stream_status ON context_streams(stream_status);
CREATE INDEX idx_context_streams_priority ON context_streams(priority DESC);
CREATE INDEX idx_context_streams_created_at ON context_streams(created_at);

CREATE INDEX idx_agent_sessions_user_id ON agent_sessions(user_id);
CREATE INDEX idx_agent_sessions_session_token ON agent_sessions(session_token);
CREATE INDEX idx_agent_sessions_session_status ON agent_sessions(session_status);
CREATE INDEX idx_agent_sessions_last_activity ON agent_sessions(last_activity);

CREATE INDEX idx_context_relationships_parent ON context_relationships(parent_context_id);
CREATE INDEX idx_context_relationships_child ON context_relationships(child_context_id);
CREATE INDEX idx_context_relationships_type ON context_relationships(relationship_type);

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_event_contexts_updated_at 
    BEFORE UPDATE ON event_contexts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to clean up expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM agent_sessions 
    WHERE expires_at < NOW() OR (session_status = 'inactive' AND last_activity < NOW() - INTERVAL '7 days');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
