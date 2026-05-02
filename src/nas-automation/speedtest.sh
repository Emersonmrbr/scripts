#!/bin/bash

#==============================================================================
# Speedtest Data Backup Script for ASUSTOR NAS
# Description: Automated backup solution for Speedtest data
# Author: Refactored version
# Version: 5.0.0
#==============================================================================

#------------------------------------------------------------------------------
# VARIABLES
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# CONFIGURATION SECTION
#------------------------------------------------------------------------------

# Database Configuration
readonly DB_HOST=$(grep '^DB_HOST=' ~/.secrets.env | cut -d "=" -f2-) || {
    print_error "DB_HOST not found. Please set environment variable or create ~/.secrets.env"
    exit 1
}
readonly DB_PORT=$(grep '^DB_PORT=' ~/.secrets.env | cut -d '=' -f2-) || {
    print_error "DB_PORT not found. Please set environment variable or create ~/.secrets.env"
    exit 1
}
readonly DB_USER=$(grep '^DB_USER=' ~/.secrets.env | cut -d '=' -f2-) || {
    print_error "DB_USER not found. Please set environment variable or create ~/.secrets.env"
    exit 1
}
readonly DB_PASSWORD=$(grep '^DB_PASSWORD=' ~/.secrets.env | cut -d '=' -f2-) || {
    print_error "DB_PASSWORD not found. Please set environment variable or create ~/.secrets.env"
    exit 1
}
readonly DB_NAME=$(grep '^DB_NAME=' ~/.secrets.env | cut -d '=' -f2-) || {
    print_error "DB_NAME not found. Please set environment variable or create ~/.secrets.env"
    exit 1
}

DB_CONFIG="--host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME"

# Backup Configuration
readonly BASE_DIR="/volume1/Backup/Speedtest"
readonly INCLUDE_FORKS=false
readonly LOG_FILE="/volume1/logs/speedtest.log"

#------------------------------------------------------------------------------
# COLORS AND OUTPUT FUNCTIONS
#------------------------------------------------------------------------------

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to display colored messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

# Check system dependencies
check_dependencies() {
    print_status "Checking system dependencies..."

    local -a missing_deps=()
    local -a required_deps=("curl" "jq" "tar" "find")

    for dep in "${required_deps[@]}"; do
        if ! command -V "$dep" &>/dev/null || command --version "$dep" &>/dev/null || command --help "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if ! mysql --version &>/dev/null; then
        MYSQL_CMD="mysql $DB_CONFIG"
        missing_deps+=("mysql")
    fi

    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Install with: apkg install ${missing_deps[*]}"
        return 1
    fi

    print_success "All dependencies satisfied"
    return 0
}
check_dependencies
