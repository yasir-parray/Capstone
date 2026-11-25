#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/clouduser/Yasir/Capstone/Project_19"
BUCKET_NAME="$(cat "$PROJECT_DIR/bucket.txt")"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="/tmp/yasir-p19-logs-${TIMESTAMP}.tar.gz"
AWS_BIN="$(command -v aws || echo /usr/local/bin/aws)"

tar -czf "$ARCHIVE" -C "$PROJECT_DIR" logs
"$AWS_BIN" s3 cp "$ARCHIVE" "s3://${BUCKET_NAME}/backups/yasir-p19-logs-${TIMESTAMP}.tar.gz"
rm -f "$ARCHIVE"
echo "$(date -u) - Uploaded yasir-p19-logs-${TIMESTAMP}.tar.gz to s3://${BUCKET_NAME}/backups/" >> "$PROJECT_DIR/cron.log"
