//! Local Codex client for direct communication with the Codex agent

use anyhow::{anyhow, Result};
use futures::{Stream, StreamExt};
use reqwest_eventsource::EventSource;
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tracing::{debug, error, warn};
use uuid::Uuid;

use crate::{llm_gateway::api, Application};

/// Local Codex request structure
#[derive(Debug, Serialize)]
pub struct CodexRequest {
    pub messages: Vec<api::Message>,
    pub functions: Option<Vec<api::Function>>,
    pub session_id: Uuid,
    pub context_data: serde_json::Value,
    pub max_tokens: Option<u32>,
    pub temperature: Option<f32>,
    pub stream: bool,
}

/// Local Codex response structure
#[derive(Debug, Deserialize)]
pub struct CodexResponse {
    pub content: String,
    pub tokens_used: Option<u32>,
    pub processing_time_ms: Option<u64>,
    pub session_id: Uuid,
    pub context_updated: bool,
}

/// Local Codex streaming response
#[derive(Debug, Deserialize)]
pub struct CodexStreamResponse {
    pub delta: String,
    pub tokens_used: Option<u32>,
    pub session_id: Uuid,
    pub finished: bool,
}

/// Health check response from Codex agent
#[derive(Debug, Deserialize)]
pub struct CodexHealthResponse {
    pub status: String,
    pub version: String,
    pub uptime_seconds: u64,
    pub active_sessions: u32,
}

/// Local Codex client
#[derive(Clone)]
pub struct CodexClient {
    http: reqwest::Client,
    base_url: String,
    timeout: Duration,
}

impl CodexClient {
    /// Create a new Codex client
    pub fn new(base_url: String) -> Self {
        Self {
            http: reqwest::Client::builder()
                .timeout(Duration::from_secs(300)) // 5 minutes for long operations
                .build()
                .expect("Failed to create HTTP client"),
            base_url,
            timeout: Duration::from_secs(60),
        }
    }

    /// Check if the Codex agent is healthy and available
    pub async fn health_check(&self) -> Result<CodexHealthResponse> {
        let response = self
            .http
            .get(&format!("{}/health", self.base_url))
            .timeout(Duration::from_secs(10))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow!("Codex health check failed: {}", response.status()));
        }

        let health = response.json::<CodexHealthResponse>().await?;
        Ok(health)
    }

    /// Send a chat completion request to the local Codex agent
    pub async fn chat_completion(&self, request: CodexRequest) -> Result<CodexResponse> {
        debug!("Sending chat completion request to local Codex");

        let response = self
            .http
            .post(&format!("{}/v1/chat/completions", self.base_url))
            .json(&request)
            .timeout(self.timeout)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await.unwrap_or_default();
            error!("Codex request failed: {}", error_text);
            return Err(anyhow!("Codex request failed: {}", error_text));
        }

        let codex_response = response.json::<CodexResponse>().await?;
        debug!("Received response from local Codex");

        Ok(codex_response)
    }

    /// Stream chat completion from the local Codex agent
    pub async fn chat_completion_stream(
        &self,
        request: CodexRequest,
    ) -> Result<impl Stream<Item = Result<String>>> {
        debug!("Starting streaming chat completion with local Codex");

        let mut stream_request = request;
        stream_request.stream = true;

        let mut event_source = Box::pin(
            EventSource::new(
                self.http
                    .post(&format!("{}/v1/chat/completions/stream", self.base_url))
                    .json(&stream_request)
                    .timeout(self.timeout),
            )?
            .take_while(|result| {
                let is_end = matches!(result, Err(reqwest_eventsource::Error::StreamEnded));
                async move { !is_end }
            }),
        );

        // Check if the stream opened successfully
        match event_source.next().await {
            Some(Ok(reqwest_eventsource::Event::Open)) => {
                debug!("Codex stream opened successfully");
            }
            Some(Err(e)) => {
                error!("Failed to open Codex stream: {:?}", e);
                return Err(anyhow!("Failed to open Codex stream: {:?}", e));
            }
            _ => {
                error!("Unexpected response when opening Codex stream");
                return Err(anyhow!("Unexpected response when opening Codex stream"));
            }
        }

        Ok(event_source
            .filter_map(|result| async move {
                match result {
                    Ok(reqwest_eventsource::Event::Message(msg)) => {
                        match serde_json::from_str::<CodexStreamResponse>(&msg.data) {
                            Ok(stream_response) => {
                                if stream_response.finished {
                                    debug!("Codex stream finished");
                                    None
                                } else {
                                    Some(Ok(stream_response.delta))
                                }
                            }
                            Err(e) => {
                                warn!("Failed to parse Codex stream response: {:?}", e);
                                Some(Err(anyhow!("Failed to parse stream response: {:?}", e)))
                            }
                        }
                    }
                    Ok(reqwest_eventsource::Event::Open) => None,
                    Err(reqwest_eventsource::Error::StreamEnded) => None,
                    Err(e) => {
                        error!("Codex stream error: {:?}", e);
                        Some(Err(anyhow!("Stream error: {:?}", e)))
                    }
                }
            }))
    }

    /// Update context for a session
    pub async fn update_context(
        &self,
        session_id: Uuid,
        context_data: serde_json::Value,
    ) -> Result<()> {
        debug!("Updating context for session: {}", session_id);

        let response = self
            .http
            .post(&format!("{}/v1/sessions/{}/context", self.base_url, session_id))
            .json(&context_data)
            .timeout(Duration::from_secs(30))
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await.unwrap_or_default();
            error!("Failed to update context: {}", error_text);
            return Err(anyhow!("Failed to update context: {}", error_text));
        }

        debug!("Context updated successfully for session: {}", session_id);
        Ok(())
    }

    /// Create a new session with the Codex agent
    pub async fn create_session(&self, user_id: Option<String>) -> Result<Uuid> {
        debug!("Creating new Codex session");

        #[derive(Serialize)]
        struct CreateSessionRequest {
            user_id: Option<String>,
        }

        #[derive(Deserialize)]
        struct CreateSessionResponse {
            session_id: Uuid,
        }

        let response = self
            .http
            .post(&format!("{}/v1/sessions", self.base_url))
            .json(&CreateSessionRequest { user_id })
            .timeout(Duration::from_secs(30))
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await.unwrap_or_default();
            error!("Failed to create session: {}", error_text);
            return Err(anyhow!("Failed to create session: {}", error_text));
        }

        let session_response = response.json::<CreateSessionResponse>().await?;
        debug!("Created new session: {}", session_response.session_id);

        Ok(session_response.session_id)
    }

    /// Close a session with the Codex agent
    pub async fn close_session(&self, session_id: Uuid) -> Result<()> {
        debug!("Closing Codex session: {}", session_id);

        let response = self
            .http
            .delete(&format!("{}/v1/sessions/{}", self.base_url, session_id))
            .timeout(Duration::from_secs(30))
            .send()
            .await?;

        if !response.status().is_success() {
            warn!("Failed to close session {}: {}", session_id, response.status());
        } else {
            debug!("Session closed successfully: {}", session_id);
        }

        Ok(())
    }
}
