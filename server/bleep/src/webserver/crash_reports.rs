use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use serde::{Deserialize, Serialize};
use tracing::{error, info};

use crate::{db::SqlDb, webserver::prelude::*};

#[derive(Debug, Deserialize)]
pub struct SaveCrashReportRequest {
    pub text: String,
    pub name: Option<String>,
    pub email: Option<String>,
    pub unique_id: String,
    pub info: String,
    pub metadata: String,
    pub app_version: String,
    pub server_log: String,
}

#[derive(Debug, Serialize)]
pub struct SaveCrashReportResponse {
    pub success: bool,
    pub message: String,
    pub id: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct CrashReport {
    pub id: i64,
    pub unique_id: String,
    pub email: Option<String>,
    pub name: Option<String>,
    pub text: String,
    pub info: String,
    pub metadata: String,
    pub app_version: String,
    pub server_log: String,
    pub created_at: String,
}

/// Save crash report locally
/// POST /crash-reports
pub async fn save_crash_report(
    State(db): State<SqlDb>,
    Json(request): Json<SaveCrashReportRequest>,
) -> Result<impl IntoResponse> {
    info!("Saving crash report from unique_id: {}", request.unique_id);

    // Validate input
    if request.text.is_empty() || request.unique_id.is_empty() || request.info.is_empty() {
        return Ok((
            StatusCode::BAD_REQUEST,
            Json(SaveCrashReportResponse {
                success: false,
                message: "Required fields are missing".to_string(),
                id: None,
            }),
        ));
    }

    // Insert crash report
    let result = sqlx::query!(
        r#"
        INSERT INTO crash_reports (unique_id, email, name, text, info, metadata, app_version, server_log)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        "#,
        request.unique_id,
        request.email,
        request.name,
        request.text,
        request.info,
        request.metadata,
        request.app_version,
        request.server_log
    )
    .execute(&**db)
    .await;

    match result {
        Ok(result) => {
            let id = result.last_insert_rowid();
            info!("Successfully saved crash report with id: {}", id);
            Ok((
                StatusCode::OK,
                Json(SaveCrashReportResponse {
                    success: true,
                    message: "Crash report saved successfully".to_string(),
                    id: Some(id),
                }),
            ))
        }
        Err(e) => {
            error!("Failed to save crash report: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveCrashReportResponse {
                    success: false,
                    message: "Failed to save crash report".to_string(),
                    id: None,
                }),
            ))
        }
    }
}

/// Get crash reports (for admin/debugging purposes)
/// GET /crash-reports
pub async fn get_crash_reports(
    State(db): State<SqlDb>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<impl IntoResponse> {
    let limit: i64 = params.get("limit").and_then(|s| s.parse().ok()).unwrap_or(50);
    let offset: i64 = params.get("offset").and_then(|s| s.parse().ok()).unwrap_or(0);

    info!("Getting crash reports with limit: {}, offset: {}", limit, offset);

    let result = sqlx::query!(
        r#"
        SELECT id, unique_id, email, name, text, info, metadata, app_version, server_log, created_at
        FROM crash_reports
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
            let crash_reports: Vec<CrashReport> = rows
                .into_iter()
                .map(|row| CrashReport {
                    id: row.id,
                    unique_id: row.unique_id,
                    email: row.email,
                    name: row.name,
                    text: row.text,
                    info: row.info,
                    metadata: row.metadata,
                    app_version: row.app_version,
                    server_log: row.server_log,
                    created_at: row.created_at,
                })
                .collect();

            Ok((StatusCode::OK, Json(crash_reports)))
        }
        Err(e) => {
            error!("Failed to get crash reports: {}", e);
            Ok((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(SaveCrashReportResponse {
                    success: false,
                    message: "Failed to get crash reports".to_string(),
                    id: None,
                }),
            ))
        }
    }
}
