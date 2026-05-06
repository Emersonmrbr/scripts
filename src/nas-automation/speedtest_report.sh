#!/bin/bash

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

read_from_database() {
  print_status "Reading data from database..."
  read -r -d '' query <<'SQL'
SELECT
  MIN(download) AS minimum_download,
  MIN(upload) AS minimum_upload,
  MAX(latency) AS maximum_latency,
  MAX(jitter) AS maximum_jitter,
  ROUND(AVG(download), 2) AS average_download,
  ROUND(AVG(upload), 2) AS average_upload,
  ROUND(AVG(latency), 2) AS average_latency,
  ROUND(AVG(jitter), 2) AS average_jitter,
  ROUND(AVG(packetloss), 2) AS average_packet_loss,
  DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01') AS start_date,
  DATE_FORMAT(CURRENT_DATE, '%Y-%m-01') AS end_date,
  DATE_FORMAT(CURRENT_DATE, '%Y') AS year,
  DATE_FORMAT(CURRENT_DATE, '%m') AS month,
  COUNT(*) AS total_measurements
FROM results
WHERE datetime >= DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
AND datetime < DATE_FORMAT(CURRENT_DATE, '%Y-%m-01');
SQL
  dados=$(mysql_config -N -e "$query") || {
    print_error "Failed to execute query: $query"
    exit 1
  }
  if [[ -z "$dados" ]]; then
    print_warning "No data found for the specified date range."
    exit 0
  fi
  IFS=$'\t' read -r minimum_download minimum_upload maximum_latency maximum_jitter average_download average_upload average_latency average_jitter average_packet_loss start_date end_date year month total_measurements <<<"$dados"
  print_success "Data retrieved successfully"

  echo "Minimum Download: $minimum_download Mbps"
  echo "Minimum Upload: $minimum_upload Mbps"
  echo "Maximum Latency: $maximum_latency ms"
  echo "Maximum Jitter: $maximum_jitter ms"
  echo "Average Download: $average_download Mbps"
  echo "Average Upload: $average_upload Mbps"
  echo "Average Latency: $average_latency ms"
  echo "Average Jitter: $average_jitter ms"
  echo "Average Packet Loss: $average_packet_loss %"
  echo "Date Range: $start_date to $end_date"
  echo "Total Measurements: $total_measurements"
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

main() {
  load_configuration || exit 1
  check_dependencies || exit 1
  read_from_database || exit 1
}

main "$@"
