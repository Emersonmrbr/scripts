#! /bin/bash

#==============================================================================
# New plus instructions
# Description: This script allows users to copy files from the newplus directory to a specified folder.
# Author: Emerson Martins Brito
# Version: 1.0.0
#==============================================================================

#------------------------------------------------------------------------------
# GLOBAL VARIABLES
#------------------------------------------------------------------------------

CHOISE=""
DATE=$(date +"%Y-%m-%d %H:%M:%S")
NAME="$1"

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

selct_choise() {
  echo Select an option:
  echo "1) ProjectFolder_en-US"
  echo "2) ProjectFolder_pt-BR"
  echo "3) SchoolFolder"
  echo "4) Exit"
  read -p "Enter the number of your choice: " CHOISE


  case $CHOISE in
    1)
      print_info "You selected ProjectFolder_en-US."
      folder_name "ProjectFolder_en-US"
      ;;
    2)
      print_info "You selected ProjectFolder_pt-BR."
      folder_name "ProjectFolder_pt-BR"
      ;;
    3)
      print_info "You selected SchoolFolder."
      folder_name "SchoolFolder"
      ;;
    4)
      print_info "Exiting the script."
      exit 0
      ;;
    *)
      print_error "Invalid option. Please select a valid number."
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
    print_info "NEW PLUS v1.0.0 - STARTING EXECUTION"
    print_info "DEVELOPER: EMERSON MARTINS BRITO"
    print_info "VERSION: 1.0.0"
    print_info "DEVELOPER DATE: 2026-04-19"
    print_info "================================================"
    print_info "Timestamp: $DATE"

    # Select folder choice
    selct_choise "$1"

    # Script footer
    print_info "================================================"
    print_info "NEW PLUS v1.0.0 - EXECUTION COMPLETED"
    print_info "================================================"
}

# Execute main script
main "$@"