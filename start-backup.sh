#!/bin/bash

# Configuration
# Defaults match the production image layout (/papermc, /backups, /logs).
# cron runs with a minimal environment, so these defaults must be correct on
# their own; override via env only when the layout differs (e.g. dev/workspace).
SERVER_DIR="${SERVER_DIR:-/papermc}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
LOG_DIR="${LOG_DIR:-/logs}"
LOG_FILE="${LOG_DIR}/backup.log"
MAX_BACKUPS=10
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Check for last backup
LAST_BACKUP=$(ls -d "${BACKUP_DIR}"/* 2>/dev/null | tail -n 1)

# Check if there are changes since last backup
if [ -n "$LAST_BACKUP" ]; then
    CHANGES=$(rsync -avn --delete "${SERVER_DIR}/" "${LAST_BACKUP}/" | grep -v "sending incremental file list" | grep -v "^$" | grep -v "^sent" | grep -v "^total")
    if [ -z "$CHANGES" ]; then
        log "No changes detected. Skipping backup."
        exit 0
    fi
fi

# Create backup directory and perform backup
log "Starting backup..."
mkdir -p "${BACKUP_DIR}/${TIMESTAMP}"
rsync -avz --delete "${SERVER_DIR}/" "${BACKUP_DIR}/${TIMESTAMP}/" >> "${LOG_FILE}" 2>&1
log "Backup completed: ${TIMESTAMP}"

# Rotation: Remove oldest backups if exceeding MAX_BACKUPS
BACKUP_COUNT=$(ls -d "${BACKUP_DIR}"/* | wc -l)
if [ ${BACKUP_COUNT} -gt ${MAX_BACKUPS} ]; then
    REMOVED=$(ls -d "${BACKUP_DIR}"/* | head -n $((BACKUP_COUNT - MAX_BACKUPS)))
    echo "$REMOVED" | xargs rm -rf
    log "Removed old backups: $(echo "$REMOVED" | tr '\n' ' ')"
fi