#!/bin/bash

DATE=$(date +%F-%H-%M)

DB_NAME="devops"
DB_USER="root"
DB_PASSWORD="Zain@12345"

BACKUP_DIR="/var/www/html/devops-assesment/DatabasaeBackups"

BACKUP_FILE="$BACKUP_DIR/$DB_NAME-$DATE.sql"

mkdir -p "$BACKUP_DIR"

mysqldump -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$BACKUP_FILE"

if [ $? -eq 0 ]; then

    echo "✅ Backup completed successfully."

    aws s3 cp "$BACKUP_FILE" s3://devops-assessment-zain-backups-2026/

    if [ $? -eq 0 ]; then
        echo "✅ Backup uploaded to S3 successfully."
    else
        echo "❌ Failed to upload backup to S3."
    fi

else

    echo "❌ Database backup failed."

fi
