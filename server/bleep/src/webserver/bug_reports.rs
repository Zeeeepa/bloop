use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use serde::{Deserialize, Serialize};
use tracing::{error, info};

use crate::{db::SqlDb, webserver::prelude::*};

#[derive(Debug, Deserialize)]
pub struct SaveBugReportRequest {
    pub email: String,
    pub name: String,
    pub text: String,
    pub unique_id: String,
    pub app_version: String,
    pub metadata: String,
    pub server_log: String,
}

#[derive(Debug, Serialize)]
pub struct SaveBugReportResponse {
    pub success: bool,
    pub message: String,
    pub id: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct BugReport {
    pub id: i64,
    pub unique_id: String,
    pub email: String,
    pub name: String,
    pub text: String,
    pub app_version: String,
    pub metadata: String,
    pub server_log: String,
    pub created_at: String,
}

/// Save bug report locally
/// POST /bug-reports
pub async fn save_bug_report(
    State(db): State<SqlDb>,
    Json(request): Json<SaveBugReportRequest>,
) -> Result<impl IntoResponse> {
    info!("Saving bug report from user: {}", request.name);

    // Validate input
    if request.email.is_empty() || request.name.is_empty() || request.text.is_empty() || request.unique_id.is_empty() {
        return Ok((
            StatusCode::BAD_REQUEST,
            Json(SaveBugReportResponse {
                success: false,
                message: "Required fields are missing".to_string(),
                id: None,
            }),
        ));
    }

    // Insert bug report
    let result = sqlx::query!(
        r#"
        INSERT INTO bug_reports (unique_id, email, name, text, app_version, metadata, server_log)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        "#,
        request.unique_id,
        request.email,
        request.name,
        request.text,
        request.app_version,
        request.metadata,
        request.server_log
    )
    .execute(&**db)
    .await;

    match result {
        Ok(result) => {
            let id = result.last_insert_rowid();
            info!("Successfully saved bug report with id: {}", id);
            Ok((
                StatusCode::OK,
                Json(SaveBugReportResponse {
                    success: true,
                    message: "Bug report saved successfully".to_string(),
                    id: Some(id),
                }),
            ))
        }
        Err(e) => {
            error!("Failed to save bug report: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveBugReportResponse {
                    success: false,
                    message: "Failed to save bug report".to_string(),
                    id: None,
                }),
            ))
        }
    }
}

/// Get bug reports (for admin/debugging purposes)
/// GET /bug-reports
pub async fn get_bug_reports(
    State(db): State<SqlDb>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<impl IntoResponse> {
    let limit: i64 = params.get("limit").and_then(|s| s.parse().ok()).unwrap_or(50);
    let offset: i64 = params.get("offset").and_then(|s| s.parse().ok()).unwrap_or(0);

    info!("Getting bug reports with limit: {}, offset: {}", limit, offset);

    let result = sqlx::query!(
        r#"
        SELECT id, unique_id, email, name, text, app_version, metadata, server_log, created_at
        FROM bug_reports
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
            let bug_reports: Vec<BugReport> = rows
                .into_iter()
                .map(|row| BugReport {
                    id: row.id,
                    unique_id: row.unique_id,
                    email: row.email,
                    name: row.name,
                    text: row.text,
                    app_version: row.app_version,
                    metadata: row.metadata,
                    server_log: row.server_log,
                    created_at: row.created_at,
                })
                .collect();

            Ok((StatusCode::OK, Json(bug_reports)))
        }
        Err(e) => {
            error!("Failed to get bug reports: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveBugReportResponse {
                    success: false,
                    message: "Failed to get bug reports".to_string(),
                    id: None,
                }),
            ))
        }
    }
}
