use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use serde::{Deserialize, Serialize};
use tracing::{error, info};

use crate::{db::SqlDb, webserver::prelude::*};

#[derive(Debug, Deserialize)]
pub struct SaveUpvoteRequest {
    pub unique_id: String,
    pub snippet_id: String,
    pub query: String,
    pub text: String,
    pub is_upvote: bool,
}

#[derive(Debug, Deserialize)]
pub struct GetUpvoteRequest {
    pub unique_id: String,
    pub snippet_id: String,
    pub query: String,
}

#[derive(Debug, Serialize)]
pub struct SaveUpvoteResponse {
    pub success: bool,
    pub message: String,
    pub id: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct Upvote {
    pub id: i64,
    pub unique_id: String,
    pub snippet_id: String,
    pub query: String,
    pub text: String,
    pub is_upvote: bool,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Serialize)]
pub struct GetUpvoteResponse {
    pub upvote: Option<Upvote>,
}

/// Save upvote locally
/// POST /upvotes
pub async fn save_upvote(
    State(db): State<SqlDb>,
    Json(request): Json<SaveUpvoteRequest>,
) -> Result<impl IntoResponse> {
    info!(
        "Saving upvote for unique_id: {}, snippet_id: {}, is_upvote: {}",
        request.unique_id, request.snippet_id, request.is_upvote
    );

    // Validate input
    if request.unique_id.is_empty() || request.snippet_id.is_empty() || request.query.is_empty() {
        return Ok((
            StatusCode::BAD_REQUEST,
            Json(SaveUpvoteResponse {
                success: false,
                message: "Required fields are missing".to_string(),
                id: None,
            }),
        ));
    }

    // Insert or update upvote (upsert)
    let result = sqlx::query!(
        r#"
        INSERT INTO upvotes (unique_id, snippet_id, query, text, is_upvote, updated_at)
        VALUES (?, ?, ?, ?, ?, datetime('now'))
        ON CONFLICT(unique_id, snippet_id, query) DO UPDATE SET
            text = excluded.text,
            is_upvote = excluded.is_upvote,
            updated_at = datetime('now')
        "#,
        request.unique_id,
        request.snippet_id,
        request.query,
        request.text,
        request.is_upvote
    )
    .execute(&**db)
    .await;

    match result {
        Ok(result) => {
            let id = result.last_insert_rowid();
            info!("Successfully saved upvote with id: {}", id);
            Ok((
                StatusCode::OK,
                Json(SaveUpvoteResponse {
                    success: true,
                    message: "Upvote saved successfully".to_string(),
                    id: Some(id),
                }),
            ))
        }
        Err(e) => {
            error!("Failed to save upvote: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveUpvoteResponse {
                    success: false,
                    message: "Failed to save upvote".to_string(),
                    id: None,
                }),
            ))
        }
    }
}

/// Get upvote by unique_id, snippet_id, and query
/// GET /upvotes
pub async fn get_upvote(
    State(db): State<SqlDb>,
    Query(params): Query<GetUpvoteRequest>,
) -> Result<impl IntoResponse> {
    info!(
        "Getting upvote for unique_id: {}, snippet_id: {}, query: {}",
        params.unique_id, params.snippet_id, params.query
    );

    let result = sqlx::query!(
        r#"
        SELECT id, unique_id, snippet_id, query, text, is_upvote, created_at, updated_at
        FROM upvotes
        WHERE unique_id = ? AND snippet_id = ? AND query = ?
        "#,
        params.unique_id,
        params.snippet_id,
        params.query
    )
    .fetch_optional(&**db)
    .await;

    match result {
        Ok(Some(row)) => {
            let upvote = Upvote {
                id: row.id,
                unique_id: row.unique_id,
                snippet_id: row.snippet_id,
                query: row.query,
                text: row.text,
                is_upvote: row.is_upvote,
                created_at: row.created_at,
                updated_at: row.updated_at,
            };
            Ok((StatusCode::OK, Json(GetUpvoteResponse { upvote: Some(upvote) })))
        }
        Ok(None) => {
            Ok((StatusCode::OK, Json(GetUpvoteResponse { upvote: None })))
        }
        Err(e) => {
            error!("Failed to get upvote: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveUpvoteResponse {
                    success: false,
                    message: "Failed to get upvote".to_string(),
                    id: None,
                }),
            ))
        }
    }
}

/// Get all upvotes (for admin/analytics purposes)
/// GET /upvotes/all
pub async fn get_all_upvotes(
    State(db): State<SqlDb>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<impl IntoResponse> {
    let limit: i64 = params.get("limit").and_then(|s| s.parse().ok()).unwrap_or(100);
    let offset: i64 = params.get("offset").and_then(|s| s.parse().ok()).unwrap_or(0);

    info!("Getting all upvotes with limit: {}, offset: {}", limit, offset);

    let result = sqlx::query!(
        r#"
        SELECT id, unique_id, snippet_id, query, text, is_upvote, created_at, updated_at
        FROM upvotes
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
        "#,
        limit,
        offset
    )
    .fetch_all(&**db)
    .await;

    match result {
        Ok(rows) => {
            let upvotes: Vec<Upvote> = rows
                .into_iter()
                .map(|row| Upvote {
                    id: row.id,
                    unique_id: row.unique_id,
                    snippet_id: row.snippet_id,
                    query: row.query,
                    text: row.text,
                    is_upvote: row.is_upvote,
                    created_at: row.created_at,
                    updated_at: row.updated_at,
                })
                .collect();

            Ok((StatusCode::OK, Json(upvotes)))
        }
        Err(e) => {
            error!("Failed to get all upvotes: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveUpvoteResponse {
                    success: false,
                    message: "Failed to get upvotes".to_string(),
                    id: None,
                }),
            ))
        }
    }
}
