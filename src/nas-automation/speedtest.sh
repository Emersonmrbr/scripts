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
DB_HOST="" DB_PORT="" DB_USER="" DB_PASSWORD="" DB_NAME=""
# Backup Configuration
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

load_configuration() {
  readonly ENV_FILE="/home/Emerson/.secrets.env"

  if [[ ! -f "$ENV_FILE" ]]; then
    print_error "Environment file $ENV_FILE not found. Please create it with the required variables."
    exit 1
  fi
  # Database Configuration
  DB_HOST=$(grep '^DB_HOST=' "$ENV_FILE" | cut -d "=" -f2-) || {
    print_error "DB_HOST not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }
  DB_PORT=$(grep '^DB_PORT=' "$ENV_FILE" | cut -d '=' -f2-) || {
    print_error "DB_PORT not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }
  DB_USER=$(grep '^DB_USER=' "$ENV_FILE" | cut -d '=' -f2-) || {
    print_error "DB_USER not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }
  DB_PASSWORD=$(grep '^DB_PASSWORD=' "$ENV_FILE" | cut -d '=' -f2-) || {
    print_error "DB_PASSWORD not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }
  DB_NAME=$(grep '^DB_NAME=' "$ENV_FILE" | cut -d '=' -f2-) || {
    print_error "DB_NAME not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }

  print_success "Configuration loaded successfully"
  return 0

}

mysql_config() {
  mysql \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --user="$DB_USER" \
    --password="$DB_PASSWORD" \
    "$DB_NAME" "$@"
}

# Check system dependencies
check_dependencies() {
  print_status "Checking system dependencies..."

  local -a missing_deps=()
  local -ar required_deps=("curl" "jq" "tar" "find" "mysql")

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
  if ! result=$(speedtest --format=json 2>>"$LOG_FILE" | jq -c 'select(.type == "result")'); then
    print_error "Speedtest failed"
    return 1
  fi
  local -r raw=$(jq -r '
  [
  ((.download.bandwidth / 125000) | floor),
  ((.upload.bandwidth / 125000) | floor),
  .ping.jitter,
  .ping.latency,
  (.timestamp | sub("T"; " ") | sub("Z"; "")),
  .result.url,
  .result.id,
  "id:\(.server.id) - host:\(.server.host) - port:\(.server.port) - name:\(.server.name) - ip:\(.server.ip) - url:\(.server.url)",
  "location:\(.server.location) - country:\(.server.country)",
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
    read -r LOCATION
    read -r EXTERNAL_IP
    read -r INTERNAL_IP
    read -r PACKETLOSS
  } <<<"$raw"

  print_success "Speedtest completed successfully"
  return 0
}

#------------------------------------------------------------------------------
# DATABASE FUNCTIONS
#------------------------------------------------------------------------------

ensure_table() {

  print_status "Ensuring database table exists..."
  if mysql_config <<'SQL'; then
CREATE TABLE IF NOT EXISTS results (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  datetime    DATETIME       NOT NULL,
    download    DECIMAL(10,2)  NOT NULL COMMENT 'Mbps',
    upload      DECIMAL(10,2)  NOT NULL COMMENT 'Mbps',
    server      VARCHAR(255),
    location    VARCHAR(300),
    externalip  VARCHAR(50),
  createdat  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    jitter      DECIMAL(10,2)  COMMENT 'ms',
    packetloss  DECIMAL(10,2),
    resultid    VARCHAR(50),
  resulturl   VARCHAR(255),
    latency     DECIMAL(10,2)  COMMENT 'ms',
    internalip  VARCHAR(50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL
    print_success "Database table ensured successfully"
    return 0
  fi

  print_warning "Could not create table (likely missing CREATE privilege). Checking if table already exists..."
  if mysql_config -N -s -e "SELECT 1 FROM information_schema.tables WHERE table_schema = '$DB_NAME' AND table_name = 'results' LIMIT 1;" | grep -q '^1$'; then
    print_warning "Using existing results table without CREATE privilege."
    return 0
  fi

  print_error "Database table results does not exist and could not be created with current user permissions."
  return 1
}

save_to_database() {

  print_status "Saving results to database..."
  local before_count="0"
  local after_count="0"

  ensure_table || {
    print_error "Failed to ensure database table exists"
    return 1
  }

  before_count=$(mysql_config -N -s -e "SELECT COUNT(*) FROM results WHERE resultid = '$RESULT_ID';") || {
    print_error "Failed to read existing record count before insert"
    return 1
  }

  local datetime_sql="${DATETIME//\'/''}"
  local result_url_sql="${RESULT_URL//\'/''}"
  local server_sql="${SERVER//\'/''}"
  local location_sql="${LOCATION//\'/''}"
  local result_id_sql="${RESULT_ID//\'/''}"
  local external_ip_sql="${EXTERNAL_IP//\'/''}"
  local internal_ip_sql="${INTERNAL_IP//\'/''}"

  local -r query=$(printf \
    "INSERT INTO results (datetime, download, upload, server, location, externalip, jitter, packetloss, resultid, resulturl, latency, internalip) VALUES ('%s', %.2f, %.2f, '%s', '%s', '%s', %.2f, %.2f, '%s', '%s', %.2f, '%s');" \
    "$datetime_sql" "$DOWNLOAD" "$UPLOAD" "$server_sql" "$location_sql" "$external_ip_sql" "$JITTER" "$PACKETLOSS" "$result_id_sql" "$result_url_sql" "$LATENCY" "$internal_ip_sql")

  if ! mysql_config -e "$query"; then
    print_error "Failed to save results to database"
    return 1
  fi

  after_count=$(mysql_config -N -s -e "SELECT COUNT(*) FROM results WHERE resultid = '$RESULT_ID';") || {
    print_error "Failed to read record count after insert"
    return 1
  }

  if [[ "$after_count" -le "$before_count" ]]; then
    print_error "Insert command completed, but no new record was confirmed in $DB_NAME.results on $DB_HOST:$DB_PORT."
    return 1
  fi

  print_success "Results saved to database successfully in $DB_NAME.results on $DB_HOST:$DB_PORT"
  return 0
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

main() {
  load_configuration || exit 1
  check_dependencies || exit 1
  test_speed || exit 1
  save_to_database || exit 1
}

main "$@"
