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
readonly ICLOUD_LOCALPATH=$HOME/Icloud
readonly ONEDRIVE_LOCALPATH=$HOME/Onedrive
readonly IT_LOCALPATH=$HOME/Sharepoint/IT
readonly OT_LOCALPATH=$HOME/Sharepoint/OT
readonly SCHOOL_LOCALPATH=$HOME/Sharepoint/School
readonly ICLOUD_REMOTEPATH="icloud:"
readonly ONEDRIVE_REMOTEPATH="onedrive:"
readonly IT_REMOTEPATH="it:"
readonly OT_REMOTEPATH="ot:"
readonly SCHOOL_REMOTEPATH="school:"
readonly SYNCP_LOG="$HOME/syncp.log"
readonly RCLONE_LOG="$HOME/rclone.log"

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

sync_icloud() {
  print_status "Syncing iCloud files..."
  if [[ ! -d "$ICLOUD_LOCALPATH" ]]; then
    mkdir -p "$ICLOUD_LOCALPATH"
    print_warning "iCloud local path $ICLOUD_LOCALPATH did not exist and was created."
  fi
  if rclone bisync "$ICLOUD_LOCALPATH" "$ICLOUD_REMOTEPATH" --exclude "**/.DS_Store" --exclude "*.band" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access >>"$RCLONE_LOG" 2>&1; then
    print_success "iCloud sync without --resync completed successfully."
  else
    print_status "iCloud sync without --resync failed, retrying with --resync..."
    rclone bisync "$ICLOUD_LOCALPATH" "$ICLOUD_REMOTEPATH" --exclude "**/.DS_Store" --exclude "*.band" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access --resync
    print_success "iCloud sync with --resync completed successfully."
  fi
}

sync_onedrive() {
  print_status "Syncing OneDrive files..."
  if [[ ! -d "$ONEDRIVE_LOCALPATH" ]]; then
    mkdir -p "$ONEDRIVE_LOCALPATH"
    print_warning "OneDrive local path $ONEDRIVE_LOCALPATH did not exist and was created."
  fi
  if rclone bisync "$ONEDRIVE_LOCALPATH" "$ONEDRIVE_REMOTEPATH" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access >>"$RCLONE_LOG" 2>&1; then
    print_success "OneDrive sync without --resync completed successfully."
  else
    print_status "OneDrive sync without --resync failed, retrying with --resync..."
    rclone bisync "$ONEDRIVE_LOCALPATH" "$ONEDRIVE_REMOTEPATH" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access --resync
    print_success "OneDrive sync with --resync completed successfully."
  fi
}

sync_it() {
  print_status "Syncing IT SharePoint files..."
  if [[ ! -d "$IT_LOCALPATH" ]]; then
    mkdir -p "$IT_LOCALPATH"
    print_warning "IT SharePoint local path $IT_LOCALPATH did not exist and was created."
  fi
  if rclone bisync "$IT_LOCALPATH" "$IT_REMOTEPATH" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access >>"$RCLONE_LOG" 2>&1; then
    print_success "IT SharePoint sync without --resync completed successfully."
  else
    print_status "IT SharePoint sync without --resync failed, retrying with --resync..."
    rclone bisync "$IT_LOCALPATH" "$IT_REMOTEPATH" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access --resync
    print_success "IT SharePoint sync with --resync completed successfully."
  fi
}

sync_ot() {
  print_status "Syncing OT SharePoint files..."
  if [[ ! -d "$OT_LOCALPATH" ]]; then
    mkdir -p "$OT_LOCALPATH"
    print_warning "OT SharePoint local path $OT_LOCALPATH did not exist and was created."
  fi
  if rclone bisync "$OT_LOCALPATH" "$OT_REMOTEPATH" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access >>"$RCLONE_LOG" 2>&1; then
    print_success "OT SharePoint sync without --resync completed successfully."
  else
    print_status "OT SharePoint sync without --resync failed, retrying with --resync..."
    rclone bisync "$OT_LOCALPATH" "$OT_REMOTEPATH" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access --resync
    print_success "OT SharePoint sync with --resync completed successfully."
  fi
}

sync_school() {
  print_status "Syncing School SharePoint files..."
  if [[ ! -d "$SCHOOL_LOCALPATH" ]]; then
    mkdir -p "$SCHOOL_LOCALPATH"
    print_warning "School SharePoint local path $SCHOOL_LOCALPATH did not exist and was created."
  fi
  if rclone bisync "$SCHOOL_LOCALPATH" "$SCHOOL_REMOTEPATH" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access >>"$RCLONE_LOG" 2>&1; then
    print_success "School SharePoint sync without --resync completed successfully."
  else
    print_status "School SharePoint sync without --resync failed, retrying with --resync..."
    rclone bisync "$SCHOOL_LOCALPATH" "$SCHOOL_REMOTEPATH" --exclude "**/.DS_Store" --compare size,modtime,checksum --slow-hash-sync-only --resilient -MvP --drive-skip-gdocs --fix-case --check-access --resync
    print_success "School SharePoint sync with --resync completed successfully."
  fi
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------
main() {
  sync_icloud
  sync_onedrive
  sync_it
  sync_ot
  sync_school
}

main "$@"
