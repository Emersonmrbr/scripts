#! /bin/bash

#==============================================================================
# Update and Upgrade Script
# Description: This script updates and upgrades the system using apt package manager.
# Author: Emerson Martins Brito
# Version: 1.1.1
#==============================================================================

DATE=$(date +"%Y-%m-%d %H:%M:%S")

#==============================================================================
# Update and Upgrade Script
# Description: This script updates and upgrades the system using apt package manager.
echo "=============================================="
echo "System Update and Upgrade Script"
echo "Author: Emerson Martins Brito"
echo "Version: 1.1.0"
echo "Timestamp: $DATE"
echo "=============================================="
echo "This may take a few minutes. Please wait..."
echo ""

if [ -z "${1}" ]; then
  # No options provided, perform full update and upgrade
  set -- "--all"
fi
case "$1" in
--help | -h)
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --help, -h    Display this help message"
  echo "  --version, -v Display version information"
  echo "  --all, -a     Update and upgrade the system, is default if no options are provided"
  echo "  --update, -u   Update the package lists only"
  echo "  --upgrade, -g  Upgrade the installed packages only"
  exit 0
  ;;
--version | -v)
  echo "Version: 1.1.0"
  exit 0
  ;;
--all | -a)
  if command -v apt-get &> /dev/null; then
    echo "Updating and upgrading the system using apt..."
      if sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt clean; then
          echo "System updated successfully."
          exit 0
      else
          echo "Upgrade failed."
          exit 1
      fi
  elif command -v apkg &> /dev/null; then
    echo "Updating the system using apkg..."
      if sudo apkg --update; then
          echo "System updated successfully using apkg."
          exit 0
      else
          echo "Upgrade failed using apkg."
          exit 1
      fi
  else
      echo "No supported package manager found. Please install apt-get or apkg."
      exit 1
  fi
  ;;
--update | -u)
  if command -v apt-get &> /dev/null; then
    echo "Updating package lists using apt..."
    if sudo apt-get update --yes; then
      echo "Package lists updated successfully."
      exit 0
    else
      echo "An error occurred while updating package lists."
      exit 1
    fi
  elif command -v apkg &> /dev/null; then
    echo "Updating package lists using apkg..."
    if sudo apkg --update; then
      echo "Package lists updated successfully using apkg."
      exit 0
    else
      echo "An error occurred while updating package lists using apkg."
      exit 1
    fi
  else
    echo "No supported package manager found. Please install apt-get or apkg."
    exit 1
  fi
  ;;
--upgrade | -g)
  if command -v apt-get &> /dev/null; then
    if sudo apt-get upgrade --yes && sudo apt-get dist-upgrade --yes; then
      echo "Packages upgraded successfully."
      exit 0
    else
      echo "An error occurred while upgrading packages."
      exit 1
    fi
  else
    echo "No supported package manager found. Please install apt-get."
    exit 1
  fi
  ;;
*)
  echo "Invalid option: $1"
  echo "Use --help or -h for usage information."
  exit 1
  ;;
esac
