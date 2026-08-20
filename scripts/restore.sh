#!/bin/bash
set -e

# Load Environment Variables
S3_BUCKET=${S3_BUCKET_NAME:-"your-laravel-backup-bucket"}
DB_HOST=${DB_HOST:-"10.0.1.112"}
DB_PORT=${DB_PORT:-"3306"}
DB_USER=${DB_USERNAME:-"root"}
DB_PASS=${DB_PASSWORD:-"Zain@12345"}
DB_NAME=${DB_DATABASE:-"devops"}

RESTORE_DIR="/tmp/db_restore"
mkdir -p $RESTORE_DIR

echo "=== Step 1: Fetching Latest Backup from S3 ==="
LATEST_BACKUP=$(aws s3 ls s3://${S3_BUCKET}/backups/ | sort | tail -n 1 | awk '{print $4}')

if [ -z "$LATEST_BACKUP" ]; then
  echo "Error: No backup file found in S3 bucket!"
  exit 1
fi

echo "Downloading: $LATEST_BACKUP"
aws s3 cp "s3://${S3_BUCKET}/backups/${LATEST_BACKUP}" "$RESTORE_DIR/$LATEST_BACKUP"

echo "=== Step 2: Uncompressing Backup File ==="
gunzip -f "$RESTORE_DIR/$LATEST_BACKUP"
SQL_FILE="${RESTORE_DIR}/${LATEST_BACKUP%.gz}"

echo "=== Step 3: Restoring Database to $DB_NAME ==="
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SQL_FILE"

if [ $? -eq 0 ]; then
  echo "✅ Database Restoration Completed Successfully!"
  rm -rf $RESTORE_DIR
else
  echo "❌ Database Restoration Failed!"
  exit 1
fi
