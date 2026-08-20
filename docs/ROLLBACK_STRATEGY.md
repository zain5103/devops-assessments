# Automated Deployment Rollback & Failure Recovery Strategy

This project implements an automated, zero-downtime rollback mechanism within the Jenkins CI/CD pipeline to ensure high availability and prevent degraded application releases from reaching production traffic.

## Automated Rollback Workflow

[ Deploy Version N (New Tag) ]
│
▼
[ Automated Container Initialization ]
│
▼
[ Health & Smoke Test Execution (HTTP Endpoint Check) ]
│
├──► [ HTTP 200 OK ] ──► Deployment Success (Release Active)
│
└──► [ Non-200 / Timeout ] ──► AUTOMATED ROLLBACK TRIGGERED
│
├──► Stop & Remove Degraded Container (Version N)
├──► Restore Last Known Good Container (Version N-1)
└──► Mark Pipeline Execution as FAILED

## Core Technical Implementation

### 1. Health Verification & HTTP Status Checks
Upon spinning up the newly built Docker container (`my-laravel-app:${GIT_COMMIT_SHA}`), the pipeline enters a verification state before routing active traffic:
* Executes automated `curl` checks against the HTTP service endpoint (`http://127.0.0.1:8080`).
* Validates that the application returns a strict `200 OK` HTTP status code.

### 2. Failure Detection & Immediate Circuit Breaking
If the container encounters an application crash (e.g., HTTP 500 internal server error, database connection failure, or unhandled Laravel runtime exception):
* The health check script catches the non-200 response or timeout error.
* Jenkins catches the execution failure via standard shell error handling (`set -e` / non-zero exit codes).

### 3. Automated Rollback Logic
When a health check failure is caught, the pipeline automatically executes the following recovery steps:
1. **Container Termination:** Immediately stops and removes the degraded container instance (`docker stop laravel_app && docker rm laravel_app`).
2. **State Restoration:** Re-spins the container using the previous stable, immutable image tag (`my-laravel-app:previous_stable_tag`).
3. **Pipeline Alerting:** Halts downstream pipeline execution, prevents database migrations or backup triggers from running on corrupt states, and flags the build as **FAILED** in Jenkins.

### 4. Immutable Tagging for Reliable Reversion
Because every deployment generates an immutable image tag bound to the **Git Commit SHA** (`my-laravel-app:${GIT_COMMIT_SHA}`) alongside the rolling `:latest` tag, reverting to a prior release does not rely on guessing dependencies or rebuilding source code. The exact pre-compiled binary artifact is restored instantly.
