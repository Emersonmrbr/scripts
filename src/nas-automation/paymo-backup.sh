#!/bin/bash

# Script to backup Paymo data to ASUSTOR NAS
# Configuration - EDIT THESE VARIABLES

PAYMO_TOKEN="your_paymo_APIKEY"             # Replace with your Paymo API KEY (not token)
PAYMO_EMAIL="emersonm@nucleomap.com.br"   # Your Paymo email
BASE_DIR="/volume1/Backup/Paymo"          # Directory where backups will be saved
KEEP_DAYS=0                               # 0 = Keep all backups forever
LOG_FILE="/var/log/paymo-backup.log"      # Log file
COMPRESS_BACKUPS=false                    # Always false for incremental backups

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Current date and time for backup entry
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
INCREMENTAL_DIR="$BASE_DIR/incremental"

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

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if ! command -v tar &> /dev/null; then
        missing_deps+=("tar")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Install missing dependencies with:"
        print_status "apkg install ${missing_deps[*]}"
        exit 1
    fi

    print_success "All dependencies are installed"
}

# Validate configuration
validate_config() {
    print_status "Validating configuration..."

    if [ "$PAYMO_TOKEN" = "seu_api_key_aqui" ]; then
        print_error "Configure your Paymo API KEY in PAYMO_TOKEN variable"
        print_status "Get your API key at: https://app.paymoapp.com -> Settings -> API & Integrations"
        exit 1
    fi

    if [ -z "$PAYMO_EMAIL" ]; then
        print_error "Configure your Paymo email in PAYMO_EMAIL variable"
        exit 1
    fi

    print_success "Configuration validated"
}

# Create base directory structure
create_directories() {
    print_status "Creating directory structure..."

    local dirs=("$BASE_DIR" "$BASE_DIR/logs" "$INCREMENTAL_DIR")

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            if [ $? -eq 0 ]; then
                print_success "Directory created: $dir"
            else
                print_error "Failed to create directory: $dir"
                exit 1
            fi
        fi
    done

    print_success "Directory structure ready"
}

# Check connectivity to Paymo
check_connectivity() {
    print_status "Testing connectivity to Paymo API..."

    local response=$(curl -s --connect-timeout 10 -w "%{http_code}" -o /dev/null \
        -u "$PAYMO_TOKEN:random" \
        -H "Accept: application/json" \
        "https://app.paymoapp.com/api/me")

    if [ "$response" = "200" ]; then
        print_success "Connectivity to Paymo API: OK"
        return 0
    else
        print_error "Failed to connect to Paymo API (HTTP: $response)"
        if [ "$response" = "401" ]; then
            print_error "Invalid API key. Check your PAYMO_TOKEN configuration"
        fi
        return 1
    fi
}

# Make API request and append to incremental file
paymo_api_request() {
    local endpoint="$1"
    local filename="$2"
    local description="$3"
    local temp_file="/tmp/paymo_temp_$.json"
    local incremental_file="$INCREMENTAL_DIR/${filename}.json"

    print_status "Downloading $description..."

    local response=$(curl -s -w "%{http_code}" \
        -u "$PAYMO_TOKEN:random" \
        -H "Accept: application/json" \
        "https://app.paymoapp.com/api/$endpoint" \
        -o "$temp_file")

    local http_code="${response: -3}"

    if [ "$http_code" = "200" ]; then
        if [ -s "$temp_file" ]; then
            # Add timestamp and backup info to the data
            local backup_entry=$(jq -n \
                --arg timestamp "$DATE" \
                --arg endpoint "$endpoint" \
                --slurpfile data "$temp_file" \
                '{
                    backup_timestamp: $timestamp,
                    endpoint: $endpoint,
                    data: $data[0]
                }')

            # Append to incremental file
            if [ -f "$incremental_file" ]; then
                # File exists, append new entry
                local temp_combined="/tmp/paymo_combined_$.json"
                jq -s '. + ['"$backup_entry"']' "$incremental_file" > "$temp_combined"
                mv "$temp_combined" "$incremental_file"
                print_success "$description appended to existing file"
            else
                # First entry, create new file
                echo "[$backup_entry]" > "$incremental_file"
                print_success "$description saved as new incremental file"
            fi

            # Get file info
            local file_size
            if command -v stat &> /dev/null; then
                file_size=$(stat -f%z "$incremental_file" 2>/dev/null || stat -c%s "$incremental_file" 2>/dev/null || echo "unknown")
            else
                file_size="unknown"
            fi

            local entry_count=$(jq length "$incremental_file" 2>/dev/null || echo "unknown")
            print_status "File now contains $entry_count entries (${file_size} bytes total)"

            # Cleanup temp file
            rm -f "$temp_file"
            return 0
        else
            print_warning "$description downloaded but response is empty"
            rm -f "$temp_file"
            return 1
        fi
    else
        print_error "Failed to download $description (HTTP: $http_code)"
        rm -f "$temp_file"
        return 1
    fi
}

# Get user information and save incrementally
get_user_info() {
    paymo_api_request "me" "user_info" "User Information"

    if [ $? -eq 0 ]; then
        local user_file="$INCREMENTAL_DIR/user_info.json"
        if [ -f "$user_file" ]; then
            # Get latest user info from the incremental file
            local user_name=$(jq -r '.[-1].data.name // "Unknown"' "$user_file" 2>/dev/null)
            local company=$(jq -r '.[-1].data.company // "Unknown"' "$user_file" 2>/dev/null)
            print_status "Backup for user: $user_name ($company)"
        fi
    fi
}

# Backup Paymo data
backup_paymo_data() {
    print_status "Starting Paymo data backup..."
    CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Define API endpoints and their descriptions
    declare -A endpoints=(
        ["projects"]="Projects"
        ["clients"]="Clients"
        ["users"]="Users"
        ["tasks"]="Tasks"
        ["entries?where=time_interval%20in%20(%222014-12-01T00:00:00Z%22,%22${CURRENT_DATE}%22)"]="Time Entries"
        ["invoicepayments"]="Invoices"
        ["expenses"]="Expenses"
        ["milestones"]="Milestones"
        ["discussions"]="Discussions"
        ["files"]="Files"
        ["reports"]="Reports"
        ["hooks"]="Webhooks"
    )

    local success_count=0
    local total_endpoints=${#endpoints[@]}

    # Get user information first
    get_user_info

    # Download data from each endpoint incrementally
    for endpoint in "${!endpoints[@]}"; do
        local description="${endpoints[$endpoint]}"
        local filename=$(echo "$description" | sed 's/\//_/g')  # Replace / with _

        if paymo_api_request "$endpoint" "$filename" "$description"; then
            success_count=$((success_count + 1))
        fi

        # Rate limiting - wait between requests
        sleep 1
    done

    print_status "Downloaded $success_count of $total_endpoints endpoints"
    return $success_count
}

# Create backup summary
create_backup_summary() {
    print_status "Creating backup summary..."

    local summary_file="$BASE_DIR/logs/backup_summary_$DATE.txt"

    {
        echo "=== PAYMO INCREMENTAL BACKUP SUMMARY ==="
        echo "Date: $DATE"
        echo "Email: $PAYMO_EMAIL"
        echo "Incremental Directory: $INCREMENTAL_DIR"
        echo ""
        echo "Incremental files status:"
        for file in "$INCREMENTAL_DIR"/*.json; do
            if [ -f "$file" ]; then
                local basename=$(basename "$file" .json)
                local entries=$(jq length "$file" 2>/dev/null || echo "0")
                local size=$(du -sh "$file" 2>/dev/null | cut -f1 || echo "unknown")
                printf "%-20s: %s entries (%s)\n" "$basename" "$entries" "$size"
            fi
        done
        echo ""
        echo "Total incremental backup size:"
        du -sh "$INCREMENTAL_DIR" 2>/dev/null || echo "Error calculating size"
        echo ""
        echo "Backup completed at: $(date)"
    } > "$summary_file"

    print_success "Backup summary created: $summary_file"
}

# Remove compress backup function (not needed for incremental)
# Incremental backups are never compressed to allow continuous appending

# Clean old logs only (keep all incremental data)
cleanup_old_logs() {
    print_status "Cleaning up old log files (keeping all incremental data)..."

    local deleted_count=0

    # Clean old summary logs (keep last 90 days)
    if find "$BASE_DIR/logs" -name "backup_summary_*.txt" -mtime +90 -delete 2>/dev/null; then
        deleted_count=$(find "$BASE_DIR/logs" -name "backup_summary_*.txt" -mtime +90 2>/dev/null | wc -l)
    fi

    # Clean old main logs (keep last 90 days)
    find "/var/log" -name "paymo-backup*.log" -mtime +90 -delete 2>/dev/null

    if [ $deleted_count -gt 0 ]; then
        print_success "Cleaned up $deleted_count old log file(s)"
    else
        print_status "No old logs to clean (incremental data preserved)"
    fi

    print_status "All incremental backup data is preserved forever"
}

# Main function
main() {
    print_status "=== Starting Paymo Incremental Backup ==="
    print_status "Email: $PAYMO_EMAIL"
    print_status "Incremental Directory: $INCREMENTAL_DIR"
    print_status "Data Retention: Forever (incremental)"
    print_status "Log File: $LOG_FILE"

    # Initial checks
    check_dependencies
    validate_config
    create_directories

    # Check connectivity
    if ! check_connectivity; then
        print_error "Cannot proceed without API connectivity"
        exit 1
    fi

    # Perform backup
    local backup_result
    backup_paymo_data
    backup_result=$?

    if [ $backup_result -gt 0 ]; then
        print_success "Backup completed with $backup_result successful downloads"

        # Create summary and cleanup old logs only
        create_backup_summary
        cleanup_old_logs

        print_status "=== Incremental Backup Summary ==="
        print_success "Incremental backup completed successfully"
        print_status "Location: $INCREMENTAL_DIR"
        print_status "Endpoints updated: $backup_result"

        # Show incremental files summary
        print_status ""
        print_status "Incremental files status:"
        for file in "$INCREMENTAL_DIR"/*.json; do
            if [ -f "$file" ]; then
                local basename=$(basename "$file" .json)
                local entries=$(jq length "$file" 2>/dev/null || echo "0")
                local size=$(du -sh "$file" 2>/dev/null | cut -f1 || echo "unknown")
                print_status "  $basename: $entries total entries ($size)"
            fi
        done

        print_success "Complete log available at: $LOG_FILE"
    else
        print_error "Backup failed - no data downloaded"
        exit 1
    fi
}

# Execute main script
main "$@"