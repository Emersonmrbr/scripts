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
readonly ICLOUD_SYNC="icloud: /mnt/dados/Icloud"
readonly ONEDRIVE_SYNC="onedrive: /mnt/dados/Onedrive"
readonly IT_SYNC="it: /mnt/dados/Sharepoint/IT"
readonly OT_SYNC="ot: /mnt/dados/Sharepoint/OT"
readonly SCHOOL_SYNC="school: /mnt/dados/Sharepoint/School"
readonly OZ3_SYNC="oz3: /mnt/dados/OZ3"
readonly LOCALPATH=("/mnt/dados/Icloud" "/mnt/dados/Onedrive" "/mnt/dados/Sharepoint/IT" "/mnt/dados/Sharepoint/OT" "/mnt/dados/Sharepoint/School" "/mnt/dados/OZ3")
readonly ICLOUD_LOCALPATH=/mnt/dados/Icloud
readonly ONEDRIVE_LOCALPATH=/mnt/dados/Onedrive
readonly IT_LOCALPATH=/mnt/dados/Sharepoint/IT
readonly OT_LOCALPATH=/mnt/dados/Sharepoint/OT
readonly SCHOOL_LOCALPATH=/mnt/dados/Sharepoint/School
readonly OZ3_LOCALPATH=/mnt/dados/OZ3
readonly REMOTES=("icloud:" "onedrive:" "it:" "ot:" "school:" "oz3:")
readonly ICLOUD_REMOTE="icloud:"
readonly ONEDRIVE_REMOTE="onedrive:"
readonly IT_REMOTE="it:"
readonly OT_REMOTE="ot:"
readonly SCHOOL_REMOTE="school:"
readonly OZ3_REMOTE="oz3:"
RCLONE_OPTIONAL_FLAGS=()
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

# Build optional rclone flags without forcing incompatible combinations (like -v and -q).
set_rclone_optional_flags() {
  local has_verbosity=0
  local has_ignore_errors=0

  RCLONE_OPTIONAL_FLAGS=()

  for arg in "$@"; do
    case "$arg" in
    -q | --quiet | -v | --verbose | -vv | -vvv)
      has_verbosity=1
      RCLONE_OPTIONAL_FLAGS+=("$arg")
      ;;
    --ignore-errors)
      has_ignore_errors=1
      RCLONE_OPTIONAL_FLAGS+=("$arg")
      ;;
    esac
  done

  if [[ $has_verbosity -eq 0 ]]; then
    RCLONE_OPTIONAL_FLAGS+=("--quiet")
  fi

  if [[ $has_ignore_errors -eq 0 ]]; then
    RCLONE_OPTIONAL_FLAGS+=("--ignore-errors")
  fi
}

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
