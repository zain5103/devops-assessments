# Enterprise CI/CD Pipeline Architecture & Quality Gates

This repository implements a production-ready Jenkins CI/CD pipeline featuring multi-stage validation, automated security scanning, container image inspection, zero-downtime health verification, and automated rollback capabilities.

## Pipeline Lifecycle Workflow


[ Git Push ]
│
▼
[ Quality Gate: PHPUnit Unit & Integration Tests ]
│
▼
[ Code Security Scan: SonarQube / Static Analysis ]
│
▼
[ Multi-Stage Docker Build (Cached Layers) ]
│
▼
[ Image Vulnerability Scan: Trivy / Container Inspection ]
│
▼
[ Staging Container Deployment ]
│
▼
[ Automated Health Check & Smoke Tests (HTTP 200 OK Verification) ]
│
├──► [ PASS ] ──► Release to Production Traffic
│
└──► [ FAIL ] ──► Automated Rollback to Last Known Good Tag


## Key Stages & Quality Gates Explained

1. **Pre-Build Quality Gate (Unit & Integration Testing):**
   * Executes `./vendor/bin/phpunit --stop-on-failure` prior to containerization.
   * If any unit test or application logic fails, the build halts immediately, preventing faulty code from reaching image creation.

2. **Static Code Security Scan (SAST):**
   * Scans Laravel source code for hardcoded credentials, weak dependencies, or security vulnerabilities before proceeding.

3. **Optimized Multi-Stage Docker Build:**
   * Utilizes Docker layer caching (removing `--no-cache` overhead) and multi-stage Dockerfiles (`composer` builder stage vs runtime `php:apache` image) to minimize image footprint and build speed.

4. **Container Image Security Scan:**
   * Scans built Docker images (`my-laravel-app:COMMIT_SHA`) for OS-level and package-level CVE vulnerabilities before running the container.

5. **Deployment, Health Check & Smoke Testing:**
   * Boots the container isolated on target port (e.g., `8080`).
   * Runs automated `curl` HTTP status checks and smoke tests against essential endpoints (`/` and health routes).

6. **Automated Rollback Mechanism:**
   * If health checks fail (e.g., non-200 HTTP code, DB connection loss, runtime exception), Jenkins catches the non-zero status code, halts deployment, stops the degraded container, and preserves the last stable container image.
