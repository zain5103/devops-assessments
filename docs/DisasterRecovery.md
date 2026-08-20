## Disaster Recovery (DR) & Database Backup Strategy

### 1. Recovery Metrics
* **RPO (Recovery Point Objective):** 24 Hours (Daily Automated Cron/Pipeline Backups).
* **RTO (Recovery Time Objective):** < 15 Minutes (Automated S3 Restoration Script).

### 2. S3 Backup Security & Management
* **Encryption:** AES-256 (Server-Side Encryption enabled on S3 Bucket via AWS KMS/S3-managed keys).
* **Retention Policy:** S3 Lifecycle Rule configured to transition backups to S3 Glacier after 30 days and delete after 90 days.
* **Versioning:** S3 Bucket Versioning is **ENABLED** to prevent accidental deletion or overwriting of backup snapshots.

### 3. Backup Failure Detection & Monitoring
* **Alerting:** Backup scripts emit exit status codes (`set -e`). If the backup script fails, Jenkins pipeline triggers an automated failure status (or Slack/Email webhook notification).
* **Automated Integrity Testing:** Periodic restore testing using `scripts/restore.sh` inside a staging/ephemeral container to verify database restoration without corruption.

### 4. Restoration Process (Step-by-Step)
To test or execute a full database restoration:
1. Run `./scripts/restore.sh` with valid DB and S3 bucket credentials.
2. The script fetches the latest gzipped dump from S3, decompresses it, and populates the target MariaDB/MySQL instance.
