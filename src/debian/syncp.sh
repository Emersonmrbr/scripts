#!/bin/bash

#==============================================================================
# Syncp Script for sync file on cloud
# Description: Automated sync solution for Cloud
# Author: Emerson
# Version: 1.2.0
#==============================================================================

#------------------------------------------------------------------------------
# VARIABLES
#------------------------------------------------------------------------------
readonly LOCALPATH=("/mnt/dados/Icloud" "/mnt/dados/Onedrive" "/mnt/dados/Sharepoint/IT" "/mnt/dados/Sharepoint/OT" "/mnt/dados/Sharepoint/School" "/mnt/dados/OZ3")
readonly REMOTES=("icloud:" "onedrive:" "it:" "ot:" "school:" "oz3:")
if [ -f "$HOME/logs/syncp.log" ]; then
  readonly SYNCP_LOG="$HOME/logs/syncp.log"
else
  mkdir -p "$HOME/logs"
  readonly SYNCP_LOG="$HOME/logs/syncp.log"
fi
if [ -f "$HOME/logs/rclone.log" ]; then
  readonly RCLONE_LOG="/home/emerson/logs/rclone.log"
else
  mkdir -p "$HOME/logs"
  readonly RCLONE_LOG="/home/emerson/logs/rclone.log"
fi
readonly RCLONE_CONFIG="/home/emerson/.config/rclone/rclone.conf"
readonly RCLONE_FLAGS=(
  --compare size,modtime,checksum
  --slow-hash-sync-only
  --resilient
  --metadata
  --drive-skip-gdocs
  --fix-case
  --check-access
  --log-file "$RCLONE_LOG"
  --log-file-max-size 10M
  --progress
)
readonly RCLONE_EXCLUDE=(
  --exclude "Preview/**"
  --exclude "GarageBand for iOS/**"
  --exclude "*.band"
)
readonly RCLONE_INCLUDE=(
  --include "Equipamentos/**"
)

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
sync_log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SYNCP_LOG"
}

# Function to display colored messages
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
  sync_log "INFO: $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
  sync_log "SUCCESS: $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
  sync_log "WARNING: $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  sync_log "ERROR: $1"
}

if ! command -v rclone >/dev/null 2>&1; then
  print_error "rclone is not installed or not available in PATH."
  exit 1
fi

if [[ ! -f "$RCLONE_CONFIG" ]]; then
  print_error "rclone config file not found at $RCLONE_CONFIG."
  exit 1
fi

# Ensure rclone check-access marker exists on both sides.
ensure_check_access_marker() {
  local local_path="$1"
  local remote_path="$2"
  local marker_file="$local_path/RCLONE_TEST"
  local marker_remote="${remote_path}RCLONE_TEST"

  if [[ ! -f "$marker_file" ]]; then
    if sudo touch "$marker_file"; then
      print_status "Created check-access marker: $marker_file"
    else
      print_warning "Could not create check-access marker: $marker_file"
    fi
  fi

  if sudo rclone --config "$RCLONE_CONFIG" lsf "$marker_remote" >/dev/null 2>&1; then
    return 0
  fi

  if sudo rclone --config "$RCLONE_CONFIG" touch "$marker_remote" >/dev/null 2>&1; then
    print_status "Created check-access marker on remote: $marker_remote"
  else
    print_warning "Could not create check-access marker on remote: $marker_remote"
  fi
}

if [[ "${#REMOTES[@]}" -ne "${#LOCALPATH[@]}" ]]; then
  print_error "The number of remotes and local paths do not match. Please check the configuration."
  exit 1
fi

print_status "Syncing cloud files..."

for i in "${!REMOTES[@]}"; do

  if [[ ! -d "${LOCALPATH[i]}" ]]; then
    if sudo mkdir -p "${LOCALPATH[i]}"; then
      print_warning "Local path ${LOCALPATH[i]} did not exist and was created."
    else
      print_error "Failed to create local path ${LOCALPATH[i]}. Check permissions and try again."
      exit 1
    fi
  fi

  ensure_check_access_marker "${LOCALPATH[i]}" "${REMOTES[i]}"

  print_status "Starting sync for ${REMOTES[i]} to ${LOCALPATH[i]}..."
  if [[ "${REMOTES[i]}" == "oz3:" ]]; then
    if sudo rclone --config "${RCLONE_CONFIG}" bisync "${REMOTES[i]}" "${LOCALPATH[i]}" "${RCLONE_FLAGS[@]}" "${RCLONE_INCLUDE[@]}" 2>&1; then
      print_success "Sync without --resync completed successfully for ${REMOTES[i]}."
    else
      print_status "Sync without --resync failed for ${REMOTES[i]}, retrying with --resync..."
      if sudo rclone --config "${RCLONE_CONFIG}" bisync "${REMOTES[i]}" "${LOCALPATH[i]}" "${RCLONE_FLAGS[@]}" "${RCLONE_INCLUDE[@]}" --resync 2>&1; then
        print_success "Sync with --resync completed successfully for ${REMOTES[i]}."
      else
        print_error "Sync with --resync also failed for ${REMOTES[i]}. Check the $SYNCP_LOG and $RCLONE_LOG for details."
        exit 1
      fi
    fi
  else
    if sudo rclone --config "${RCLONE_CONFIG}" bisync "${REMOTES[i]}" "${LOCALPATH[i]}" "${RCLONE_FLAGS[@]}" "${RCLONE_EXCLUDE[@]}" 2>&1; then
      print_success "Sync without --resync completed successfully for ${REMOTES[i]}."
    else
      print_status "Sync without --resync failed for ${REMOTES[i]}, retrying with --resync..."
      if sudo rclone --config "${RCLONE_CONFIG}" bisync "${REMOTES[i]}" "${LOCALPATH[i]}" "${RCLONE_FLAGS[@]}" "${RCLONE_EXCLUDE[@]}" --resync 2>&1; then
        print_success "Sync with --resync completed successfully for ${REMOTES[i]}."
      else
        print_error "Sync with --resync also failed for ${REMOTES[i]}. Check the $SYNCP_LOG and $RCLONE_LOG for details."
        exit 1
      fi
    fi
  fi
done
