#!/bin/bash

# Directory where the scripts to be executed are located
SCRIPT_DIR="/volume1/Scripts/src/nas-automation"
# Log file for recording script execution details
LOG_FILE="/volume1/logs/cron-wrapper.log"
# List of scripts to be executed
SCRIPTS=("${SCRIPT_DIR}"/*-cron-wrapper.sh)

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
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

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

main(){
    local failures=0

    log "INFO" "=== STARTING CRON WRAPPER (via CRON) ==="
    log "INFO" "Log: $LOG_FILE"
    log "INFO" "PID: $$"
    # Loop to execute each script in the list
    for script in "${SCRIPTS[@]}"; do
        # Skips scripts containing "paymo" in their name
        if [[ "$script" != *paymo* ]]; then
            # Executes the script in the background
            bash "$script" < /dev/null &
            PROCESS=$!
            # Waits for the background process to finish
            wait $PROCESS
            EXIT_CODE=$?
            # Checks if there was an error during script execution
            if (( EXIT_CODE != 0 )); then
                log "ERROR" "Error executing $script (exit code: $EXIT_CODE)"
                failures=$((failures + 1))
            else
                log "SUCCESS" "Successfully executed $script"
            fi
        else
            log "WARNING" "Skipped execution of $script because paymo account expired"
        fi
    done

    # Ensure all background processes are terminated
    wait
    log "INFO" "=== PROCESS FINISHED (failures: $failures) ==="
    exit 0
}
main "$@"