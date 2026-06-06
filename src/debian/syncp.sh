#!/bin/bash

#==============================================================================
# Syncp Script for sync file on cloud
# Description: Automated sync solution for Cloud
# Author: Emerson
# Version: 1.0.0
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
  readonly RCLONE_LOG="$HOME/logs/rclone.log"
else
  mkdir -p "$HOME/logs"
  readonly RCLONE_LOG="$HOME/logs/rclone.log"
fi
readonly RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"
readonly RCLONE_FLAGS=(
  --exclude "**/.DS_Store"
  --exclude "Preview/**"
  --exclude "GarageBand for iOS/**"
  --exclude "**/.DS_Store"
  --compare size,modtime,checksum
  --slow-hash-sync-only
  --resilient
  --metadata
  --drive-skip-gdocs
  --fix-case
  --check-access
  --log-file "$RCLONE_LOG"
  --log-file-max-size 10M
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

sync_clouds() {
  print_status "Syncing cloud files..."

  for i in "${!REMOTES[@]}"; do
    localpath="${LOCALPATH[i]}"
    remotepath="${REMOTES[i]}"

    if [[ ! -d "$localpath" ]]; then
      if sudo mkdir -p "$localpath"; then
        print_warning "Local path $localpath did not exist and was created."
      else
        print_error "Failed to create local path $localpath. Check permissions and try again."
        return 1
      fi
    fi
    print_status "Starting sync for $remotepath to $localpath..."
    if [[ "$remotepath" == "oz3:" ]]; then
      if sudo rclone --config "${RCLONE_CONFIG}" bisync "${remotepath}" "${localpath}" --include "Equipamentos/**" "${RCLONE_FLAGS[@]}" 2>&1; then
        print_success "Sync without --resync completed successfully for $remotepath."
      else
        print_status "Sync without --resync failed for ${remotepath}, retrying with --resync..."
        if sudo rclone --config "${RCLONE_CONFIG}" bisync "${remotepath}" "${localpath}" --include "Equipamentos/**" "${RCLONE_FLAGS[@]}" --resync 2>&1; then
          print_success "Sync with --resync completed successfully for $remotepath."
        else
          print_error "Sync with --resync also failed for ${remotepath}. Check the $SYNCP_LOG and $RCLONE_LOG for details."
          return 1
        fi
      fi
    else
      if sudo rclone --config "${RCLONE_CONFIG}" bisync "${remotepath}" "${localpath}" "${RCLONE_FLAGS[@]}" 2>&1; then
        print_success "Sync without --resync completed successfully for $remotepath."
      else
        print_status "Sync without --resync failed for ${remotepath}, retrying with --resync..."
        if sudo rclone --config "${RCLONE_CONFIG}" bisync "${remotepath}" "${localpath}" "${RCLONE_FLAGS[@]}" --resync 2>&1; then
          print_success "Sync with --resync completed successfully for $remotepath."
        else
          print_error "Sync with --resync also failed for ${remotepath}. Check the $SYNCP_LOG and $RCLONE_LOG for details."
          return 1
        fi
      fi
    fi
  done
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------
main() {
  if ! command -v rclone >/dev/null 2>&1; then
    print_error "rclone is not installed or not available in PATH."
    return 1
  fi

  if [[ ! -f "$RCLONE_CONFIG" ]]; then
    print_error "rclone config file not found at $RCLONE_CONFIG."
    return 1
  fi

  sync_clouds
}

main "$@"
