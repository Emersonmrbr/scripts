#! /bin/bash

#==============================================================================
# New plus instructions
# Description: This script allows users to copy files from the newplus directory to a specified folder.
# Author: Emerson Martins Brito
# Version: 1.0.1
#==============================================================================

#------------------------------------------------------------------------------
# GLOBAL VARIABLES
#------------------------------------------------------------------------------

DATE=$(date +"%Y-%m-%d %H:%M:%S")
NAME="$2"

#------------------------------------------------------------------------------
# COLORS AND OUTPUT FUNCTIONS
#------------------------------------------------------------------------------

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Output functions with consistent formatting
print_info() {
  echo -e "${BLUE}[INFO]${NC} ${1}" >&2
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} ${1}" >&2
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} ${1}" >&2
}

print_error() {
  echo -e "${RED}[ERROR]${NC} ${1}" >&2
}

print_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo -e "${CYAN}[DEBUG]${NC} ${1}" >&2
  fi
}

#------------------------------------------------------------------------------
# NAME OF THE FOLDER FUNCTION
#------------------------------------------------------------------------------

folder_name() {
  if [ -z "$NAME" ]; then
    cp -r ~/.local/lib/.newp/"${1}" ./"New Folder"/
    echo "No folder name provided. Files copied to 'New Folder'."
  else
    cp -r ~/.local/lib/.newp/"${1}" ./"${NAME}"/
    echo "Files copied to ${NAME}."
  fi
}

select_choice() {
  case "$1" in

  --help | -h)
    print_info "You selected Help."
    cat <<EOF
    Usage: $0 [folder_name] [options]"
    Options:
      -e, --en) ProjectFolder_en-US
      -p, --pt) ProjectFolder_pt-BR
      -s, --school) SchoolFolder
      --help, -h) Help
      --version, -v) Version
      -x, --exit) Exit
      Synopsis:
        This script allows users to copy files from the newplus directory to a specified folder.
        If no folder name is provided, files will be copied to a default 'New Folder'.
      Syntax:
        $0 [folder_name]
      Examples:
        $0 MyProjectFolder
        $0
        $0 --help
        $0 --version
EOF
    exit 0
    ;;
  --version | -v)
    cat <<EOF
    You selected Version.
    New Plus v1.0.1
    Developer: Emerson Martins Brito
    Developer Date: 2026-04-19
EOF
    exit 0
    ;;
  -e | --en)
    print_info "You selected ProjectFolder_en-US."
    folder_name "ProjectFolder_en-US"
    ;;
  -p | --pt)
    print_info "You selected ProjectFolder_pt-BR."
    folder_name "ProjectFolder_pt-BR"
    ;;
  -s | --school)
    print_info "You selected SchoolFolder."
    folder_name "SchoolFolder"
    ;;
  -x | --exit)
    print_info "Exiting the script."
    exit 0
    ;;
  *)
    echo "Invalid option: $1"
    echo "Use --help or -h for usage information."
    exit 1
    ;;
  esac
}

#------------------------------------------------------------------------------
# MAIN EXECUTION FUNCTION
#------------------------------------------------------------------------------

main() {
  # Script header
  print_info "================================================"
  print_info "NEW PLUS v1.0.1 - STARTING EXECUTION"
  print_info "DEVELOPER: EMERSON MARTINS BRITO"
  print_info "VERSION: 1.0.1"
  print_info "DEVELOPER DATE: 2026-04-19"
  print_info "================================================"
  print_info "Timestamp: $DATE"

  # Select folder choice
  select_choice "$1"

  # Script footer
  print_info "================================================"
  print_info "NEW PLUS v1.0.1 - EXECUTION COMPLETED"
  print_info "================================================"
}

# Execute main script
main "$@"
