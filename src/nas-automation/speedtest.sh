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
DOWNLOAD="" UPLOAD="" JITTER="" LATENCY="" DATETIME="" RESULT_URL="" SERVER="" RESULT_ID="" EXTERNAL_IP="" PACKETLOSS="" INTERNAL_IP=""
# Backup Configuration
readonly BASE_DIR="/volume1/Backup/Speedtest"
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

readonly -a DB_CONFIG=(--host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --password="$DB_PASSWORD" --database="$DB_NAME")

# Check system dependencies
check_dependencies() {
  print_status "Checking system dependencies..."

  local -a missing_deps=()
  local -a required_deps=("curl" "jq" "tar" "find" "mysql")

  for dep in "${required_deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if [[ ${#missing_deps[@]} -ne 0 ]]; then
    print_error "Missing dependencies: ${missing_deps[*]}"
    print_status "Install with: apkg install ${missing_deps[*]}"
    return 1
  fi

  print_success "All dependencies satisfied"
  return 0
}

test_speed() {
  print_status "Running speedtest..."
  local result=""
  local raw
  if ! result=$(speedtest --format=json 2>>"$LOG_FILE" | jq -c 'select(.type == "result")'); then
    print_error "Speedtest failed"
    return 1
  fi
  raw=$(jq -r '
  [
  ((.download.bandwidth / 125000) | floor),
  ((.upload.bandwidth / 125000) | floor),
  .ping.jitter,
  .ping.latency,
  (.timestamp | sub("T"; " ") | sub("Z"; "")),
  .result.url,
  .result.id,
  "id:\(.server.id) - host:\(.server.host) - port:\(.server.port) - name:\(.server.name) - location:\(.server.location) - country:\(.server.country) - ip:\(.server.ip) - url:\(.server.url)",
  .interface.externalIp,
  .interface.internalIp,
  .packetLoss
  ] | .[]
  ' <<<"${result}") || {
    print_error "Failed to parse speedtest JSON output."
    return 1
  }

  if [[ -z "$raw" ]]; then
    print_error "Speedtest JSON output is empty or missing expected fields."
    return 1
  fi
  {
    read -r DOWNLOAD
    read -r UPLOAD
    read -r JITTER
    read -r LATENCY
    read -r DATETIME
    read -r RESULT_URL
    read -r RESULT_ID
    read -r SERVER
    read -r EXTERNAL_IP
    read -r INTERNAL_IP
    read -r PACKETLOSS
  } <<<"$raw"

  SERVER=$(printf '%s' "$SERVER" | sed "s/'/''/g")

  print_success "Speedtest completed successfully"
  return 0
}

# test_speed || exit 1

save_to_database() {
  print_status "Saving results to database..."

  local query="INSERT INTO results (download, upload, jitter, latency, datetime, resulturl, server, resultid, externalip, internalip, packetloss) VALUES ($DOWNLOAD, $UPLOAD, $JITTER, $LATENCY, '$DATETIME', '$RESULT_URL', '$SERVER', '$RESULT_ID', '$EXTERNAL_IP', '$INTERNAL_IP', $PACKETLOSS);"

  if ! mysql "${DB_CONFIG[@]}" -e "$query"; then
    print_error "Failed to save results to database"
    return 1
  fi

  print_success "Results saved to database successfully"
  return 0
}

main() {
  check_dependencies || exit 1
  test_speed || exit 1
  save_to_database || exit 1
}

main "$@"
