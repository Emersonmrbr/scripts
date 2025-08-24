#!/bin/bash

# Cron wrapper script for Paymo backup execution
# File: paymo-cron-wrapper.sh

# Configuration - EDIT AS NEEDED
SCRIPT_PATH="/usr/etc/paymo-backup.sh"
LOG_FILE="/var/log/paymo-cron.log"
LOCK_FILE="/tmp/paymo-backup.lock"
MAX_LOG_SIZE="10M"  # Maximum log size
NOTIFICATION_EMAIL="emersonmrbr@gmail.com"  # Email for notifications (optional)

# Colors for logs (removed in cron, but useful for manual testing)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Enhanced logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] [PID:$$] $message" >> "$LOG_FILE"

    # If running in terminal, also show on screen
    if [ -t 1 ]; then
        case "$level" in
            "ERROR") echo -e "${RED}[$level]${NC} $message" ;;
            "SUCCESS") echo -e "${GREEN}[$level]${NC} $message" ;;
            "WARNING") echo -e "${YELLOW}[$level]${NC} $message" ;;
            *) echo -e "${BLUE}[$level]${NC} $message" ;;
        esac
    fi
}

# Function to send email notification (optional)
send_notification() {
    local subject="$1"
    local message="$2"

    if [ ! -z "$NOTIFICATION_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$NOTIFICATION_EMAIL"
        log "INFO" "Notification sent to $NOTIFICATION_EMAIL"
    fi
}

# Function to check log size and rotate if necessary
rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(du -m "$LOG_FILE" 2>/dev/null | cut -f1 || echo "0")
        local max_size=$(echo "$MAX_LOG_SIZE" | sed 's/M//')

        if [ "$log_size" -gt "$max_size" ]; then
            log "INFO" "Rotating log (size: ${log_size}M > ${max_size}M)"

            # Keep last 1000 lines
            tail -1000 "$LOG_FILE" > "${LOG_FILE}.tmp"
            mv "${LOG_FILE}.tmp" "$LOG_FILE"

            log "INFO" "Log rotated successfully"
        fi
    fi
}

# Function to clean up old logs
cleanup_old_logs() {
    # Remove logs older than 90 days (since we keep incremental data forever)
    find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE").*" -mtime +90 -delete 2>/dev/null

    # Remove orphaned lock files (older than 1 day)
    find "$(dirname "$LOCK_FILE")" -name "$(basename "$LOCK_FILE")*" -mtime +1 -delete 2>/dev/null
}

# Function to check API connectivity
check_connectivity() {
    log "INFO" "Checking internet connectivity..."

    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log "ERROR" "No internet connectivity"
        return 1
    fi

    if ! curl -s --connect-timeout 10 "https://app.paymoapp.com" >/dev/null; then
        log "ERROR" "Cannot reach Paymo servers"
        return 1
    fi

    log "INFO" "Connectivity check passed"
    return 0
}

# Function to check prerequisites
check_prerequisites() {
    local errors=0

    log "INFO" "Checking prerequisites..."

    # Check if main script exists
    if [ ! -f "$SCRIPT_PATH" ]; then
        log "ERROR" "Main script not found: $SCRIPT_PATH"
        errors=$((errors + 1))
    fi

    # Check if script is executable
    if [ ! -x "$SCRIPT_PATH" ]; then
        log "ERROR" "Main script is not executable: $SCRIPT_PATH"
        log "INFO" "Run: chmod +x $SCRIPT_PATH"
        errors=$((errors + 1))
    fi

    # Check if log directory exists
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        log "WARNING" "Log directory does not exist: $log_dir"
        if mkdir -p "$log_dir" 2>/dev/null; then
            log "INFO" "Log directory created: $log_dir"
        else
            log "ERROR" "Failed to create log directory: $log_dir"
            errors=$((errors + 1))
        fi
    fi

    # Check for required dependencies
    local missing_deps=()
    for cmd in curl jq tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        log "INFO" "Install with: apkg install ${missing_deps[*]}"
        errors=$((errors + 1))
    fi

    # Check disk space (warn if less than 1GB free)
    local backup_dir="/volume1/Backup/Paymo"
    if [ -d "$backup_dir" ]; then
        local free_space=$(df -BG "$backup_dir" | awk 'NR==2 {print $4}' | sed 's/G//')
        if [ "$free_space" -lt 1 ]; then
            log "WARNING" "Low disk space: ${free_space}GB free in backup directory"
        else
            log "INFO" "Disk space check: ${free_space}GB free"
        fi
    fi

    return $errors
}

# Function to check if already running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)

        # Check if process still exists
        if [ ! -z "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            log "WARNING" "Paymo backup is already running (PID: $lock_pid). Exiting."
            return 1
        else
            log "WARNING" "Orphaned lock file found. Removing."
            rm -f "$LOCK_FILE"
        fi
    fi

    return 0
}

# Function to create lock
create_lock() {
    echo $$ > "$LOCK_FILE"
    if [ $? -eq 0 ]; then
        log "INFO" "Lock file created (PID: $$)"
        return 0
    else
        log "ERROR" "Failed to create lock file: $LOCK_FILE"
        return 1
    fi
}

# Function to remove lock
remove_lock() {
    if [ -f "$LOCK_FILE" ]; then
        rm -f "$LOCK_FILE"
        log "INFO" "Lock file removed"
    fi
}

# Function to handle signals and cleanup
cleanup_on_signal() {
    log "WARNING" "Signal received. Cleaning up..."
    remove_lock
    exit 1
}

# Function to get backup statistics
get_backup_stats() {
    local incremental_dir="/volume1/Backup/Paymo/incremental"
    local stats_msg=""

    if [ -d "$incremental_dir" ]; then
        local total_files=$(find "$incremental_dir" -name "*.json" -type f | wc -l)
        local total_size=$(du -sh "$incremental_dir" 2>/dev/null | cut -f1 || echo "unknown")

        stats_msg="Incremental files: $total_files | Total size: $total_size"

        # Count entries in largest file as example
        local largest_file=$(find "$incremental_dir" -name "*.json" -type f -exec ls -la {} + 2>/dev/null | sort -k5 -nr | head -1 | awk '{print $9}')
        if [ ! -z "$largest_file" ] && [ -f "$largest_file" ]; then
            local entries=$(jq length "$largest_file" 2>/dev/null || echo "0")
            local basename=$(basename "$largest_file" .json)
            stats_msg="$stats_msg | Example: $basename has $entries entries"
        fi
    else
        stats_msg="Backup directory not found"
    fi

    echo "$stats_msg"
}

# Main function
main() {
    local start_time=$(date +%s)

    log "INFO" "=== STARTING PAYMO BACKUP (via CRON) ==="
    log "INFO" "Script: $SCRIPT_PATH"
    log "INFO" "Log: $LOG_FILE"
    log "INFO" "PID: $$"
    log "INFO" "User: $(whoami)"

    # Rotate log if necessary
    rotate_log

    # Check connectivity first
    if ! check_connectivity; then
        log "ERROR" "Connectivity check failed. Aborting backup."
        send_notification "Paymo Backup - Connectivity Error" "No internet connectivity or Paymo unreachable."
        exit 1
    fi

    # Check prerequisites
    if ! check_prerequisites; then
        log "ERROR" "Prerequisites not met. Aborting."
        send_notification "Paymo Backup - Configuration Error" "Prerequisites not met. Check logs at $LOG_FILE"
        exit 1
    fi

    # Check lock
    if ! check_lock; then
        exit 0
    fi

    # Create lock
    if ! create_lock; then
        exit 1
    fi

    # Setup cleanup on signal
    trap cleanup_on_signal INT TERM

    # Get pre-backup stats
    local pre_stats=$(get_backup_stats)
    log "INFO" "Pre-backup stats: $pre_stats"

    # Execute main script
    log "INFO" "Executing Paymo backup script..."

    if "$SCRIPT_PATH" >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        # Get post-backup stats
        local post_stats=$(get_backup_stats)

        log "SUCCESS" "Paymo backup completed successfully (duration: ${duration}s)"
        log "INFO" "Post-backup stats: $post_stats"

        # Success notification (only send weekly to avoid spam)
        local day_of_week=$(date +%u)  # 1-7, Monday is 1
        if [ "$day_of_week" = "1" ] && [ ! -z "$NOTIFICATION_EMAIL" ]; then
            local notification_msg="Paymo backup completed successfully.
Duration: ${duration} seconds
$post_stats

Weekly status: All incremental backups are working properly."
            send_notification "Paymo Backup - Weekly Status" "$notification_msg"
        fi

        exit_code=0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log "ERROR" "Paymo backup failed (duration: ${duration}s)"

        # Error notification (always send)
        local error_msg="Paymo backup failed after ${duration} seconds.
Check logs at: $LOG_FILE
Pre-backup stats: $pre_stats

Please investigate the issue."
        send_notification "Paymo Backup - ERROR" "$error_msg"

        exit_code=1
    fi

    # Cleanup
    cleanup_old_logs
    remove_lock

    log "INFO" "=== PAYMO BACKUP PROCESS FINISHED (exit code: $exit_code) ==="

    exit $exit_code
}

# Check if being executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi