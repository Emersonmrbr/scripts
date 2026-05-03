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
DOWNLOAD="" UPLOAD="" JITTER="" LATENCY="" DATATIME="" RESULT_URL="" SERVER="" RESULT_ID="" EXTERNAL_IP="" PACKETLOSS="" INTERNAL_IP=""
readonly DB_HOST="" DB_PORT="" DB_USER="" DB_PASSWORD="" DB_NAME=""
#------------------------------------------------------------------------------
# CONFIGURATION SECTION
#------------------------------------------------------------------------------

# Database Configuration
DB_HOST=$(grep '^DB_HOST=' ~/.secrets.env | cut -d "=" -f2-) || {
  print_error "DB_HOST not found. Please set environment variable or create ~/.secrets.env"
  exit 1
}
DB_PORT=$(grep '^DB_PORT=' ~/.secrets.env | cut -d '=' -f2-) || {
  print_error "DB_PORT not found. Please set environment variable or create ~/.secrets.env"
  exit 1
}
DB_USER=$(grep '^DB_USER=' ~/.secrets.env | cut -d '=' -f2-) || {
  print_error "DB_USER not found. Please set environment variable or create ~/.secrets.env"
  exit 1
}
DB_PASSWORD=$(grep '^DB_PASSWORD=' ~/.secrets.env | cut -d '=' -f2-) || {
  print_error "DB_PASSWORD not found. Please set environment variable or create ~/.secrets.env"
  exit 1
}
DB_NAME=$(grep '^DB_NAME=' ~/.secrets.env | cut -d '=' -f2-) || {
  print_error "DB_NAME not found. Please set environment variable or create ~/.secrets.env"
  exit 1
}

DB_CONFIG="--host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD $DB_NAME"

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

# Check system dependencies
check_dependencies() {
  print_status "Checking system dependencies..."

  local -a missing_deps=()
  local -a required_deps=("curl" "jq" "tar" "find" "mysql")

  for dep in "${required_deps[@]}"; do
    if ! command -V "$dep" &>/dev/null || command --version "$dep" &>/dev/null || command --help "$dep" &>/dev/null; then
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
  if ! result=$(speedtest --format=json 2>&1); then
    print_error "Speedtest failed"
    return 1
  fi
  DOWNLOAD=$(($(jq -r '.download.bandwidth' <<<"${result}") / 125000)) || {
    print_error "Speedtest output does not contain download speed."
    return 1
  }
  UPLOAD=$(($(jq -r '.upload.bandwidth' <<<"${result}") / 125000)) || {
    print_error "Speedtest output does not contain upload speed."
    return 1
  }
  JITTER=$(jq -r '.ping.jitter' <<<"${result}") || {
    print_error "Speedtest output does not contain ping jitter."
    return 1
  }
  LATENCY=$(jq -r '.ping.latency' <<<"${result}") || {
    print_error "Speedtest output does not contain ping latency."
    return 1
  }
  DATATIME=$(jq -r '.timestamp' <<<"${result}") || {
    print_error "Speedtest output does not contain timestamp."
    return 1
  }
  RESULT_ID=$(jq -r '.result.id' <<<"${result}") || {
    print_error "Speedtest output does not contain result ID."
    return 1
  }
  RESULT_URL=$(jq -r '.result.url' <<<"${result}") || {
    print_error "Speedtest output does not contain result URL."
    return 1
  }
  SERVER=$(jq -r '"id:\(.server.id) - host:\(.server.host) - port:\(.server.port) - name:\(.server.name) - location:\(.server.location) - country:\(.server.country) - ip:\(.server.ip)"' <<<"${result}") || {
    print_error "Speedtest output does not contain server name."
    return 1
  }
  # SERVER=$(jq -r '.server' <<<"${result}") || {
  #   print_error "Speedtest output does not contain server name."
  #   return 1
  # }
  EXTERNAL_IP=$(jq -r '.interface.externalIp' <<<"${result}") || {
    print_error "Speedtest output does not contain external IP."
    return 1
  }
  INTERNAL_IP=$(jq -r '.interface.internalIp' <<<"${result}") || {
    print_error "Speedtest output does not contain internal IP."
    return 1
  }
  PACKETLOSS=$(jq -r '.packetLoss' <<<"${result}") || {
    print_error "Speedtest output does not contain packet loss."
    return 1
  }

  echo "Download: $DOWNLOAD Mbps"
  echo "Upload: $UPLOAD Mbps"
  echo "Jitter: $JITTER ms"
  echo "Latency: $LATENCY ms"
  echo "Date/Time: $DATATIME"
  echo "Result URL: $RESULT_URL"
  echo "Server: $SERVER"
  echo "Result ID: $RESULT_ID"
  echo "External IP: $EXTERNAL_IP"
  echo "Internal IP: $INTERNAL_IP"
  echo "Packet Loss: $PACKETLOSS%"

  print_success "Speedtest completed successfully"
  return 0

}

# test_speed || exit 1

save_to_database() {
  print_status "Saving results to database..."

  local query="INSERT INTO results (download, upload, jitter, latency, datatime, resulturl, server, location, externalip, internalip, packetloss) VALUES ($DOWNLOAD, $UPLOAD, $JITTER, $LATENCY, '$DATATIME', '$RESULT_URL', '$SERVER', '$LOCATION', '$EXTERNAL_IP', '$INTERNAL_IP', $PACKETLOSS);"

  if ! mysql "${DB_CONFIG}" -e "$query"; then
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
