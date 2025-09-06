//! Database models for event contexts and Codex agent integration

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

/// Event context model - stores all interaction contexts
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct EventContext {
    pub id: Uuid,
    pub session_id: Uuid,
    pub user_id: Option<String>,
    pub event_type: String,
    pub context_data: serde_json::Value,
    pub metadata: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Interaction log model - stores all user-AI interactions
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct InteractionLog {
    pub id: Uuid,
    pub session_id: Uuid,
    pub event_context_id: Option<Uuid>,
    pub interaction_type: String,
    pub content: String,
    pub tokens_used: Option<i32>,
    pub processing_time_ms: Option<i32>,
    pub model_used: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// Context stream model - manages streaming contexts to Codex agent
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct ContextStream {
    pub id: Uuid,
    pub session_id: Uuid,
    pub stream_type: String,
    pub context_payload: serde_json::Value,
    pub stream_status: String,
    pub priority: i32,
    pub created_at: DateTime<Utc>,
    pub streamed_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
}

/// Agent session model - tracks Codex agent sessions
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AgentSession {
    pub id: Uuid,
    pub user_id: Option<String>,
    pub session_token: String,
    pub agent_config: serde_json::Value,
    pub session_status: String,
    pub last_activity: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

/// Context relationship model - tracks relationships between contexts
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct ContextRelationship {
    pub id: Uuid,
    pub parent_context_id: Uuid,
    pub child_context_id: Uuid,
    pub relationship_type: String,
    pub created_at: DateTime<Utc>,
}

/// Event types enum
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EventType {
    Chat,
    CodeCompletion,
    Search,
    FileEdit,
    ProjectAnalysis,
    SystemEvent,
}

impl ToString for EventType {
    fn to_string(&self) -> String {
        match self {
            EventType::Chat => "chat".to_string(),
            EventType::CodeCompletion => "code_completion".to_string(),
            EventType::Search => "search".to_string(),
            EventType::FileEdit => "file_edit".to_string(),
            EventType::ProjectAnalysis => "project_analysis".to_string(),
            EventType::SystemEvent => "system_event".to_string(),
        }
    }
}

/// Interaction types enum
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum InteractionType {
    Request,
    Response,
    Error,
    System,
}

impl ToString for InteractionType {
    fn to_string(&self) -> String {
        match self {
            InteractionType::Request => "request".to_string(),
            InteractionType::Response => "response".to_string(),
            InteractionType::Error => "error".to_string(),
            InteractionType::System => "system".to_string(),
        }
    }
}

/// Stream status enum
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum StreamStatus {
    Pending,
    Streaming,
    Completed,
    Failed,
}

impl ToString for StreamStatus {
    fn to_string(&self) -> String {
        match self {
            StreamStatus::Pending => "pending".to_string(),
            StreamStatus::Streaming => "streaming".to_string(),
            StreamStatus::Completed => "completed".to_string(),
            StreamStatus::Failed => "failed".to_string(),
        }
    }
}

/// Session status enum
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SessionStatus {
    Active,
    Inactive,
    Expired,
}

impl ToString for SessionStatus {
    fn to_string(&self) -> String {
        match self {
            SessionStatus::Active => "active".to_string(),
            SessionStatus::Inactive => "inactive".to_string(),
            SessionStatus::Expired => "expired".to_string(),
        }
    }
}
