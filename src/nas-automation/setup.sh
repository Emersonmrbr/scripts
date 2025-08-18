#!/bin/bash

# Initial setup script for Asustor NAS
# This script installs the necessary dependencies

echo "=== Initial setup for GitHub clone ==="

# Check if we're running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Run this script as root or with sudo"
    exit 1
fi

echo "1. Updating package list..."
apkg update

echo "2. Installing dependencies..."

# Install git if not already installed
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    apkg install git
else
    echo "Git is already installed"
fi

# Install curl if not already installed
if ! command -v curl &> /dev/null; then
    echo "Installing cURL..."
    apkg install curl
else
    echo "cURL is already installed"
fi

# Install jq if not already installed
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    apkg install jq
else
    echo "jq is already installed"
fi

echo "3. Verifying installations..."
git --version
curl --version
jq --version

echo ""
echo "=== Setup completed! ==="
echo ""
echo "Next steps:"
echo "1. Edit the main script (github-clone.sh) with your information:"
echo "   - GITHUB_USERNAME: your GitHub username"
echo "   - GITHUB_TOKEN: personal access token"
echo "   - BASE_DIR: directory where repos will be cloned"
echo ""
echo "2. To create a GitHub token:"
echo "   - Go to: https://github.com/settings/tokens"
echo "   - Click 'Generate new token (classic)'"
echo "   - Check permissions: repo, read:user"
echo "   - Copy the generated token"
echo ""
echo "3. Run the script: ./github-clone.sh"