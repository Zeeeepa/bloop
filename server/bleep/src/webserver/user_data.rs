use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use tracing::{error, info};

use crate::{db::SqlDb, webserver::prelude::*};

#[derive(Debug, Deserialize)]
pub struct SaveUserDataRequest {
    pub email: String,
    pub first_name: String,
    pub last_name: String,
    pub unique_id: String,
}

#[derive(Debug, Serialize)]
pub struct SaveUserDataResponse {
    pub success: bool,
    pub message: String,
}

#[derive(Debug, Serialize)]
pub struct UserData {
    pub id: i64,
    pub unique_id: String,
    pub email: String,
    pub first_name: String,
    pub last_name: String,
    pub created_at: String,
    pub updated_at: String,
}

/// Save user data locally
/// POST /user-data
pub async fn save_user_data(
    State(db): State<SqlDb>,
    Json(request): Json<SaveUserDataRequest>,
) -> Result<impl IntoResponse> {
    info!("Saving user data for unique_id: {}", request.unique_id);

    // Validate input
    if request.email.is_empty() || request.first_name.is_empty() || request.last_name.is_empty() || request.unique_id.is_empty() {
        return Ok((
            StatusCode::BAD_REQUEST,
            Json(SaveUserDataResponse {
                success: false,
                message: "All fields are required".to_string(),
            }),
        ));
    }

    // Insert or update user data
    let result = sqlx::query!(
        r#"
        INSERT INTO user_data (unique_id, email, first_name, last_name, updated_at)
        VALUES (?, ?, ?, ?, datetime('now'))
        ON CONFLICT(unique_id) DO UPDATE SET
            email = excluded.email,
            first_name = excluded.first_name,
            last_name = excluded.last_name,
            updated_at = datetime('now')
        "#,
        request.unique_id,
        request.email,
        request.first_name,
        request.last_name
    )
    .execute(&**db)
    .await;

    match result {
        Ok(_) => {
            info!("Successfully saved user data for unique_id: {}", request.unique_id);
            Ok((
                StatusCode::OK,
                Json(SaveUserDataResponse {
                    success: true,
                    message: "User data saved successfully".to_string(),
                }),
            ))
        }
        Err(e) => {
            error!("Failed to save user data: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveUserDataResponse {
                    success: false,
                    message: "Failed to save user data".to_string(),
                }),
            ))
        }
    }
}

/// Get user data by unique_id
/// GET /user-data/:unique_id
pub async fn get_user_data(
    State(db): State<SqlDb>,
    axum::extract::Path(unique_id): axum::extract::Path<String>,
) -> Result<impl IntoResponse> {
    info!("Getting user data for unique_id: {}", unique_id);

    let result = sqlx::query!(
        "SELECT id, unique_id, email, first_name, last_name, created_at, updated_at FROM user_data WHERE unique_id = ?",
        unique_id
    )
    .fetch_optional(&**db)
    .await;

    match result {
        Ok(Some(row)) => {
            let user_data = UserData {
                id: row.id,
                unique_id: row.unique_id,
                email: row.email,
                first_name: row.first_name,
                last_name: row.last_name,
                created_at: row.created_at,
                updated_at: row.updated_at,
            };
            Ok((StatusCode::OK, Json(user_data)))
        }
        Ok(None) => Ok((
            StatusCode::NOT_FOUND,
            Json(SaveUserDataResponse {
                success: false,
                message: "User not found".to_string(),
            }),
        )),
        Err(e) => {
            error!("Failed to get user data: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveUserDataResponse {
                    success: false,
                    message: "Failed to get user data".to_string(),
                }),
            ))
        }
    }
}
