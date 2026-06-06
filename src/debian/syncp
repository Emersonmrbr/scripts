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
readonly ICLOUD_LOCALPATH=/mnt/dados/Icloud
readonly ONEDRIVE_LOCALPATH=/mnt/dados/Onedrive
readonly IT_LOCALPATH=/mnt/dados/Sharepoint/IT
readonly OT_LOCALPATH=/mnt/dados/Sharepoint/OT
readonly SCHOOL_LOCALPATH=/mnt/dados/Sharepoint/School
readonly OZ3_LOCALPATH=/mnt/dados/OZ3
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

sync_icloud() {
  print_status "Syncing iCloud files..."
  if [[ ! -d "$ICLOUD_LOCALPATH" ]]; then
    if sudo mkdir -p "$ICLOUD_LOCALPATH"; then
      print_warning "iCloud local path $ICLOUD_LOCALPATH did not exist and was created."
    else
      print_error "Failed to create iCloud local path $ICLOUD_LOCALPATH. Check permissions and try again."
      return 1
    fi
  fi
  ensure_check_access_marker "$ICLOUD_LOCALPATH" "$ICLOUD_REMOTE"
  if sudo rclone --config "$RCLONE_CONFIG" bisync "$ICLOUD_LOCALPATH" "$ICLOUD_REMOTE" --exclude "**/.DS_Store" --exclude "*.band" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --log-file "$RCLONE_LOG" --log-file-max-size 10M "${RCLONE_OPTIONAL_FLAGS[@]}" 2>&1; then
    print_success "iCloud sync without --resync completed successfully."
  else
    print_status "iCloud sync without --resync failed, retrying with --resync..."
    if sudo rclone --config "$RCLONE_CONFIG" bisync "$ICLOUD_LOCALPATH" "$ICLOUD_REMOTE" --exclude "**/.DS_Store" --exclude "*.band" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --resync --log-file "$RCLONE_LOG" --log-file-max-size 10M; then
      print_success "iCloud sync with --resync completed successfully."
    else
      print_error "iCloud sync with --resync failed. Check $RCLONE_LOG for details."
      return 1
    fi
  fi
}

sync_onedrive() {
  print_status "Syncing OneDrive files..."
  if [[ ! -d "$ONEDRIVE_LOCALPATH" ]]; then
    if sudo mkdir -p "$ONEDRIVE_LOCALPATH"; then
      print_warning "OneDrive local path $ONEDRIVE_LOCALPATH did not exist and was created."
    else
      print_error "Failed to create OneDrive local path $ONEDRIVE_LOCALPATH. Check permissions and try again."
      return 1
    fi
  fi
  ensure_check_access_marker "$ONEDRIVE_LOCALPATH" "$ONEDRIVE_REMOTE"
  if sudo rclone --config "$RCLONE_CONFIG" bisync "$ONEDRIVE_LOCALPATH" "$ONEDRIVE_REMOTE" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --log-file "$RCLONE_LOG" --log-file-max-size 10M "${RCLONE_OPTIONAL_FLAGS[@]}" 2>&1; then
    print_success "OneDrive sync without --resync completed successfully."
  else
    print_status "OneDrive sync without --resync failed, retrying with --resync..."
    if sudo rclone --config "$RCLONE_CONFIG" bisync "$ONEDRIVE_LOCALPATH" "$ONEDRIVE_REMOTE" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --resync --log-file "$RCLONE_LOG" --log-file-max-size 10M; then
      print_success "OneDrive sync with --resync completed successfully."
    else
      print_error "OneDrive sync with --resync failed. Check $RCLONE_LOG for details."
      return 1
    fi
  fi
}

sync_it() {
  print_status "Syncing IT SharePoint files..."
  if [[ ! -d "$IT_LOCALPATH" ]]; then
    if sudo mkdir -p "$IT_LOCALPATH"; then
      print_warning "IT SharePoint local path $IT_LOCALPATH did not exist and was created."
    else
      print_error "Failed to create IT SharePoint local path $IT_LOCALPATH. Check permissions and try again."
      return 1
    fi
  fi
  ensure_check_access_marker "$IT_LOCALPATH" "$IT_REMOTE"
  if sudo rclone --config "$RCLONE_CONFIG" bisync "$IT_LOCALPATH" "$IT_REMOTE" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --log-file "$RCLONE_LOG" --log-file-max-size 10M "${RCLONE_OPTIONAL_FLAGS[@]}" 2>&1; then
    print_success "IT SharePoint sync without --resync completed successfully."
  else
    print_status "IT SharePoint sync without --resync failed, retrying with --resync..."
    if sudo rclone --config "$RCLONE_CONFIG" bisync "$IT_LOCALPATH" "$IT_REMOTE" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --resync --log-file "$RCLONE_LOG" --log-file-max-size 10M; then
      print_success "IT SharePoint sync with --resync completed successfully."
    else
      print_error "IT SharePoint sync with --resync failed. Check $RCLONE_LOG for details."
      return 1
    fi
  fi
}

sync_ot() {
  print_status "Syncing OT SharePoint files..."
  if [[ ! -d "$OT_LOCALPATH" ]]; then
    if sudo mkdir -p "$OT_LOCALPATH"; then
      print_warning "OT SharePoint local path $OT_LOCALPATH did not exist and was created."
    else
      print_error "Failed to create OT SharePoint local path $OT_LOCALPATH. Check permissions and try again."
      return 1
    fi
  fi
  ensure_check_access_marker "$OT_LOCALPATH" "$OT_REMOTE"
  if sudo rclone --config "$RCLONE_CONFIG" bisync "$OT_LOCALPATH" "$OT_REMOTE" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --log-file "$RCLONE_LOG" --log-file-max-size 10M "${RCLONE_OPTIONAL_FLAGS[@]}" 2>&1; then
    print_success "OT SharePoint sync without --resync completed successfully."
  else
    print_status "OT SharePoint sync without --resync failed, retrying with --resync..."
    if sudo rclone --config "$RCLONE_CONFIG" bisync "$OT_LOCALPATH" "$OT_REMOTE" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --resync --log-file "$RCLONE_LOG" --log-file-max-size 10M; then
      print_success "OT SharePoint sync with --resync completed successfully."
    else
      print_error "OT SharePoint sync with --resync failed. Check $RCLONE_LOG for details."
      return 1
    fi
  fi
}

sync_school() {
  print_status "Syncing School SharePoint files..."
  if [[ ! -d "$SCHOOL_LOCALPATH" ]]; then
    if sudo mkdir -p "$SCHOOL_LOCALPATH"; then
      print_warning "School SharePoint local path $SCHOOL_LOCALPATH did not exist and was created."
    else
      print_error "Failed to create School SharePoint local path $SCHOOL_LOCALPATH. Check permissions and try again."
      return 1
    fi
  fi
  ensure_check_access_marker "$SCHOOL_LOCALPATH" "$SCHOOL_REMOTE"
  if sudo rclone --config "$RCLONE_CONFIG" bisync "$SCHOOL_LOCALPATH" "$SCHOOL_REMOTE" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --log-file "$RCLONE_LOG" --log-file-max-size 10M "${RCLONE_OPTIONAL_FLAGS[@]}" 2>&1; then
    print_success "School SharePoint sync without --resync completed successfully."
  else
    print_status "School SharePoint sync without --resync failed, retrying with --resync..."
    if sudo rclone --config "$RCLONE_CONFIG" bisync "$SCHOOL_LOCALPATH" "$SCHOOL_REMOTE" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --resync --log-file "$RCLONE_LOG" --log-file-max-size 10M; then
      print_success "School SharePoint sync with --resync completed successfully."
    else
      print_error "School SharePoint sync with --resync failed. Check $RCLONE_LOG for details."
      return 1
    fi
  fi
}

sync_oz3() {
  print_status "Syncing OZ3 files..."
  if [[ ! -d "$OZ3_LOCALPATH" ]]; then
    if sudo mkdir -p "$OZ3_LOCALPATH"; then
      print_warning "OZ3 local path $OZ3_LOCALPATH did not exist and was created."
    else
      print_error "Failed to create OZ3 local path $OZ3_LOCALPATH. Check permissions and try again."
      return 1
    fi
  fi
  ensure_check_access_marker "$OZ3_LOCALPATH" "$OZ3_REMOTE"
  if sudo rclone --config "$RCLONE_CONFIG" bisync "$OZ3_LOCALPATH" "$OZ3_REMOTE" --include "/Equipamentos/**" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --log-file "$RCLONE_LOG" --log-file-max-size 10M "${RCLONE_OPTIONAL_FLAGS[@]}" 2>&1; then
    print_success "OZ3 sync without --resync completed successfully."
  else
    print_status "OZ3 sync without --resync failed, retrying with --resync..."
    if sudo rclone --config "$RCLONE_CONFIG" bisync "$OZ3_LOCALPATH" "$OZ3_REMOTE" --include "/Equipamentos/**" --compare size,modtime,checksum --slow-hash-sync-only --resilient --metadata --drive-skip-gdocs --fix-case --check-access --resync --log-file "$RCLONE_LOG" --log-file-max-size 10M; then
      print_success "OZ3 sync with --resync completed successfully."
    else
      print_error "OZ3 sync with --resync failed. Check $RCLONE_LOG for details."
      return 1
    fi
  fi
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------
main() {
  set_rclone_optional_flags "$@"
  sync_icloud
  sync_onedrive
  sync_it
  sync_ot
  sync_school
  sync_oz3
}

main "$@"
