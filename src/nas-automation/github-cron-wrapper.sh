#!/bin/bash

# Cron wrapper script for execution
# File: github-cron-wrapper.sh

# Configuration - EDIT AS NEEDED
SCRIPT_PATH="/etc/script/github-backup.sh"
LOG_FILE="/var/log/github-cron.log"
LOCK_FILE="/tmp/github-clone.lock"
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
        local log_size=$(du -m "$LOG_FILE" | cut -f1)
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
    # Remove logs older than 30 days
    find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE").*" -mtime +30 -delete 2>/dev/null
    
    # Remove orphaned lock files (older than 1 day)
    find "$(dirname "$LOCK_FILE")" -name "$(basename "$LOCK_FILE")*" -mtime +1 -delete 2>/dev/null
}

# Function to check prerequisites
check_prerequisites() {
    local errors=0
    
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
    
    return $errors
}

# Function to check if already running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        
        # Check if process still exists
        if [ ! -z "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            log "WARNING" "Script is already running (PID: $lock_pid). Exiting."
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

# Main function
main() {
    local start_time=$(date +%s)
    
    log "INFO" "=== STARTING GITHUB SYNC (via CRON) ==="
    log "INFO" "Script: $SCRIPT_PATH"
    log "INFO" "Log: $LOG_FILE"
    log "INFO" "PID: $$"
    
    # Rotate log if necessary
    rotate_log
    
    # Check prerequisites
    if ! check_prerequisites; then
        log "ERROR" "Prerequisites not met. Aborting."
        send_notification "GitHub Sync - Error" "Prerequisites not met. Check logs."
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
    
    # Execute main script
    log "INFO" "Executing main script..."
    
    if "$SCRIPT_PATH" >> "$LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "SUCCESS" "Sync completed successfully (duration: ${duration}s)"
        
        # Success notification (only if configured)
        if [ ! -z "$NOTIFICATION_EMAIL" ]; then
            send_notification "GitHub Sync - Success" "Sync completed in ${duration} seconds."
        fi
        
        exit_code=0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "ERROR" "Sync error (duration: ${duration}s)"
        
        # Error notification
        send_notification "GitHub Sync - Error" "Sync error after ${duration} seconds. Check logs."
        
        exit_code=1
    fi
    
    # Cleanup
    cleanup_old_logs
    remove_lock
    
    log "INFO" "=== PROCESS FINISHED (code: $exit_code) ==="
    
    exit $exit_code
}

# Check if being executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
