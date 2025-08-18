#!/bin/bash

# Script to clone all GitHub repositories
# Configuration - EDIT THESE VARIABLES

GITHUB_USERNAME="Emersonmrbr"   # Replace with your GitHub username
GITHUB_TOKEN="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"           # GitHub personal access token
BASE_DIR="/volume1/GithubBackup"         # Directory where repos will be cloned
INCLUDE_FORKS=false                      # true to include forks, false to exclude
LOG_FILE="/var/log/github-clone.log"     # Log file

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if dependencies are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Install missing dependencies:"
        print_status "apkg install git curl jq"
        exit 1
    fi
    
    print_success "All dependencies are installed"
}

# Validate configuration
validate_config() {
    print_status "Validating configuration..."
    
    if [ "$GITHUB_USERNAME" = "your_github_username" ]; then
        print_error "Configure your GitHub username in GITHUB_USERNAME variable"
        exit 1
    fi
    
    if [ "$GITHUB_TOKEN" = "your_token_here" ]; then
        print_error "Configure your GitHub token in GITHUB_TOKEN variable"
        print_status "Create a token at: https://github.com/settings/tokens"
        exit 1
    fi
    
    print_success "Configuration validated"
}

# Create base directory
create_base_directory() {
    print_status "Creating base directory: $BASE_DIR"
    
    if [ ! -d "$BASE_DIR" ]; then
        mkdir -p "$BASE_DIR"
        if [ $? -eq 0 ]; then
            print_success "Directory created: $BASE_DIR"
        else
            print_error "Failed to create directory: $BASE_DIR"
            exit 1
        fi
    else
        print_status "Directory already exists: $BASE_DIR"
    fi
}

# Get repository list
get_repositories() {
    print_status "Getting repository list..."
    
    local page=1
    local per_page=100
    local all_repos=()
    
    while true; do
        local url="https://api.github.com/user/repos?page=$page&per_page=$per_page&type=all"
        local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$url")
        
        if [ $? -ne 0 ]; then
            print_error "Failed to connect to GitHub API"
            exit 1
        fi
        
        # Check for API error
        local error_message=$(echo "$response" | jq -r '.message // empty')
        if [ ! -z "$error_message" ]; then
            print_error "GitHub API error: $error_message"
            exit 1
        fi
        
        local repos_page=$(echo "$response" | jq -r '.[] | select(.archived == false) | "\(.name)|\(.clone_url)|\(.fork)"')
        
        if [ -z "$repos_page" ]; then
            break
        fi
        
        while IFS= read -r repo_info; do
            if [ ! -z "$repo_info" ]; then
                all_repos+=("$repo_info")
            fi
        done <<< "$repos_page"
        
        page=$((page + 1))
    done
    
    echo "${all_repos[@]}"
}

# Clone a repository
clone_repository() {
    local repo_name="$1"
    local clone_url="$2"
    local is_fork="$3"
    local repo_dir="$BASE_DIR/$repo_name"
    
    # Check if should include forks
    if [ "$is_fork" = "true" ] && [ "$INCLUDE_FORKS" = "false" ]; then
        print_warning "Skipping fork: $repo_name"
        return 0
    fi
    
    print_status "Processing: $repo_name"
    
    if [ -d "$repo_dir" ]; then
        print_status "Repository already exists. Updating: $repo_name"
        cd "$repo_dir"
        
        if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
            print_success "Updated: $repo_name"
        else
            print_warning "Failed to update: $repo_name"
        fi
    else
        print_status "Cloning: $repo_name"
        
        # Modify URL to include token
        local auth_url=$(echo "$clone_url" | sed "s|https://|https://$GITHUB_USERNAME:$GITHUB_TOKEN@|")
        
        if git clone "$auth_url" "$repo_dir"; then
            print_success "Cloned: $repo_name"
        else
            print_error "Failed to clone: $repo_name"
        fi
    fi
}

# Main function
main() {
    print_status "=== Starting GitHub repositories clone ==="
    print_status "User: $GITHUB_USERNAME"
    print_status "Directory: $BASE_DIR"
    print_status "Include forks: $INCLUDE_FORKS"
    print_status "Log: $LOG_FILE"
    
    # Initial checks
    check_dependencies
    validate_config
    create_base_directory
    
    # Get repositories
    print_status "Searching repositories..."
    local repositories=($(get_repositories))
    
    if [ ${#repositories[@]} -eq 0 ]; then
        print_warning "No repositories found"
        exit 0
    fi
    
    print_success "Found ${#repositories[@]} repositories"
    
    # Clone repositories
    local cloned=0
    local failed=0
    
    for repo_info in "${repositories[@]}"; do
        IFS='|' read -r repo_name clone_url is_fork <<< "$repo_info"
        
        clone_repository "$repo_name" "$clone_url" "$is_fork"
        
        if [ $? -eq 0 ]; then
            cloned=$((cloned + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    print_status "=== Summary ==="
    print_success "Repositories processed: $cloned"
    if [ $failed -gt 0 ]; then
        print_warning "Failures: $failed"
    fi
    print_status "Complete log at: $LOG_FILE"
}

# Execute main script
main "$@"