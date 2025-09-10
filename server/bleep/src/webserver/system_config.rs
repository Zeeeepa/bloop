use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use serde::{Deserialize, Serialize};
use tracing::{error, info};

use crate::{db::SqlDb, webserver::prelude::*};

#[derive(Debug, Deserialize)]
pub struct UpdateConfigRequest {
    pub key: String,
    pub value: String,
    pub description: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ConfigResponse {
    pub success: bool,
    pub message: String,
    pub value: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct SystemConfig {
    pub id: i64,
    pub key: String,
    pub value: String,
    pub description: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Serialize)]
pub struct DiscordLinkResponse {
    pub url: String,
}

/// Get system configuration value by key
/// GET /system-config/:key
pub async fn get_config_value(
    State(db): State<SqlDb>,
    axum::extract::Path(key): axum::extract::Path<String>,
) -> Result<impl IntoResponse> {
    info!("Getting system config for key: {}", key);

    let result = sqlx::query!(
        "SELECT value FROM system_config WHERE key = ?",
        key
    )
    .fetch_optional(&**db)
    .await;

    match result {
        Ok(Some(row)) => {
            Ok((StatusCode::OK, Json(ConfigResponse {
                success: true,
                message: "Config value retrieved successfully".to_string(),
                value: Some(row.value),
            })))
        }
        Ok(None) => {
            Ok((StatusCode::NOT_FOUND, Json(ConfigResponse {
                success: false,
                message: "Config key not found".to_string(),
                value: None,
            })))
        }
        Err(e) => {
            error!("Failed to get config value: {}", e);
            Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(ConfigResponse {
                success: false,
                message: "Failed to get config value".to_string(),
                value: None,
            })))
        }
    }
}

/// Get Discord link (specific endpoint for backward compatibility)
/// GET /discord-url
pub async fn get_discord_link(
    State(db): State<SqlDb>,
) -> Result<impl IntoResponse> {
    info!("Getting Discord link");

    let result = sqlx::query!(
        "SELECT value FROM system_config WHERE key = 'discord_url'"
    )
    .fetch_optional(&**db)
    .await;

    match result {
        Ok(Some(row)) => {
            Ok((StatusCode::OK, Json(DiscordLinkResponse {
                url: row.value,
            })))
        }
        Ok(None) => {
            // Return default Discord link if not configured
            Ok((StatusCode::OK, Json(DiscordLinkResponse {
                url: "https://discord.gg/bloop".to_string(),
            })))
        }
        Err(e) => {
            error!("Failed to get Discord link: {}", e);
            Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(ConfigResponse {
                success: false,
                message: "Failed to get Discord link".to_string(),
                value: None,
            })))
        }
    }
}

/// Update system configuration value
/// PUT /system-config
pub async fn update_config_value(
    State(db): State<SqlDb>,
    Json(request): Json<UpdateConfigRequest>,
) -> Result<impl IntoResponse> {
    info!("Updating system config for key: {}", request.key);

    // Validate input
    if request.key.is_empty() || request.value.is_empty() {
        return Ok((StatusCode::BAD_REQUEST, Json(ConfigResponse {
            success: false,
            message: "Key and value are required".to_string(),
            value: None,
        })));
    }

    // Insert or update config value
    let result = sqlx::query!(
        r#"
        INSERT INTO system_config (key, value, description, updated_at)
        VALUES (?, ?, ?, datetime('now'))
        ON CONFLICT(key) DO UPDATE SET
            value = excluded.value,
            description = COALESCE(excluded.description, description),
            updated_at = datetime('now')
        "#,
        request.key,
        request.value,
        request.description
    )
    .execute(&**db)
    .await;

    match result {
        Ok(_) => {
            info!("Successfully updated config for key: {}", request.key);
            Ok((StatusCode::OK, Json(ConfigResponse {
                success: true,
                message: "Config value updated successfully".to_string(),
                value: Some(request.value),
            })))
        }
        Err(e) => {
            error!("Failed to update config value: {}", e);
            Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(ConfigResponse {
                success: false,
                message: "Failed to update config value".to_string(),
                value: None,
            })))
        }
    }
}

/// Get all system configuration values
/// GET /system-config
pub async fn get_all_config(
    State(db): State<SqlDb>,
) -> Result<impl IntoResponse> {
    info!("Getting all system config values");

    let result = sqlx::query!(
        "SELECT id, key, value, description, created_at, updated_at FROM system_config ORDER BY key"
    )
    .fetch_all(&**db)
    .await;

    match result {
        Ok(rows) => {
            let configs: Vec<SystemConfig> = rows
                .into_iter()
                .map(|row| SystemConfig {
                    id: row.id,
                    key: row.key,
                    value: row.value,
                    description: row.description,
                    created_at: row.created_at,
                    updated_at: row.updated_at,
                })
                .collect();

            Ok((StatusCode::OK, Json(configs)))
        }
        Err(e) => {
            error!("Failed to get all config values: {}", e);
            Ok((StatusCode::INTERNAL_SERVER_ERROR, Json(ConfigResponse {
                success: false,
                message: "Failed to get config values".to_string(),
                value: None,
            })))
        }
    }
}
