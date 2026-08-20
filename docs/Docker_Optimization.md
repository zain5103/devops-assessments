# Docker Build Optimization & Container Strategy

This document outlines the Docker image build architecture, caching strategy, and security practices implemented in this project to ensure fast, secure, and reproducible deployments.

## Why `--no-cache` Was Replaced

Previously, using `--no-cache` forced Docker to rebuild every layer from scratch on every pipeline run, leading to:
* Unnecessary resource consumption on build agents.
* Significantly longer build times (e.g., re-downloading system packages and Composer dependencies every time).

We removed `--no-cache` and structured the Dockerfile to leverage **Docker Layer Caching** and **BuildKit**.

---

## Key Docker Optimization Strategies

### 1. Optimized Dockerfile Layer Ordering
Docker caches layers based on instruction order. Frequently changing files (like application source code) are placed at the bottom, while rarely changing layers (like base images and system dependencies) are placed at the top.

* **Base OS & Dependencies (Infrequent Changes):** System packages (`apt-get` / `apk`), PHP extensions, and Apache configurations are installed early.
* **Dependency Files First (`composer.json` / `composer.lock`):** Copied and run separately before copying full application code. Changing application source code will not invalidate the cached `composer install` layer.
* **Application Code (Frequent Changes):** `COPY app/ .` is placed near the end.

### 2. Multi-Stage Builds (Builder vs. Runtime)
We utilize a multi-stage Docker build to keep the final image minimal and secure:
* **Stage 1 (Builder):** Uses CLI image to download dependencies (`composer install --no-dev`) and generate optimized autoload files.
* **Stage 2 (Runtime):** Copies only necessary compiled artifacts into a lightweight Apache-PHP runtime environment, omitting heavy build tooling (e.g., `git`, `unzip`, dev headers).

### 3. Immutable Image Tagging
* Instead of relying solely on `latest` (which can lead to non-deterministic deployments), every build produces a uniquely tagged image using the **Git Commit SHA** (`my-laravel-app:${GIT_COMMIT_SHA}`).
* Both `:${GIT_COMMIT_SHA}` and `:latest` tags are built and pushed, allowing exact version tracking, seamless rollbacks, and auditability.

### 4. Image Security & Vulnerability Scanning
* Base images are locked to specific stable PHP versions (`php:8.4-apache`, `php:8.4-cli-alpine`).
* Container images undergo automated vulnerability scans (e.g., Trivy / Docker Scout) during the CI/CD pipeline to detect OS and application-level CVEs before deployment.
