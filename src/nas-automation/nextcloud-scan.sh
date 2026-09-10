#!/bin/bash
# Rescans the Local external storage mounts so changes made outside Nextcloud
# (Local storage backend has no active change notifications) show up.
# flock ensures only one instance runs at a time, since a full scan can take
# longer than the hourly cron interval.

# Logging function. Output goes to stdout only: the caller
# (nextcloud-cron-wrapper.sh) redirects it into the shared log file, so this
# just keeps the message format consistent with the other scripts.
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] [PID:$$] $message"
}

exec 200>/tmp/nextcloud-scan.lock
chmod 666 /tmp/nextcloud-scan.lock 2>/dev/null
if ! flock -n 200; then
    log "WARNING" "Another scan is already running. Exiting."
    exit 0
fi

log "INFO" "Listing external storage mounts..."
mount_list=$(sudo docker exec -u www-data nextcloud-app php occ files_external:list --all --output=json 2>&1)
if [ $? -ne 0 ]; then
    log "ERROR" "Failed to list external storage mounts: $mount_list"
    exit 1
fi

mount_ids=$(echo "$mount_list" | jq -r '.[].mount_id' 2>/dev/null)

if [ -z "$mount_ids" ]; then
    log "WARNING" "No external storage mounts found"
    exit 0
fi

for id in $mount_ids; do
    log "INFO" "Scanning mount $id..."
    if sudo docker exec -u www-data nextcloud-app php occ files_external:scan "$id"; then
        log "SUCCESS" "Mount $id scanned successfully"
    else
        log "ERROR" "Failed to scan mount $id"
    fi
done

log "INFO" "Scan finished"
