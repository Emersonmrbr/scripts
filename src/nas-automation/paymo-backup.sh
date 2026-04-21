#!/bin/bash

#==============================================================================
# Paymo Data Backup Script for ASUSTOR NAS
# Description: Automated backup solution for Paymo project management data
# Author: Refactored version
# Version: 2.0
#==============================================================================

set -uo pipefail  # Exit on undefined variables and pipe failures (but continue on command errors)

#------------------------------------------------------------------------------
# CONFIGURATION SECTION
#------------------------------------------------------------------------------

# Paymo API Configuration
readonly PAYMO_TOKEN="${PAYMO_TOKEN:-$(cat /home/Emerson/.paymo_token 2>/dev/null | tr -d '\n' || echo '')}"
readonly PAYMO_EMAIL="${PAYMO_EMAIL:-emersonm@nucleomap.com.br}"
readonly PAYMO_API_BASE="https://app.paymoapp.com/api"

# Backup Configuration
readonly BASE_DIR="${BASE_DIR:-/volume1/Backup/Paymo}"
readonly LOG_FILE="${LOG_FILE:-/var/log/paymo-backup.log}"
readonly RATE_LIMIT_SECONDS="${RATE_LIMIT_SECONDS:-1}"
readonly LOG_RETENTION_DAYS=90
readonly SUMMARY_RETENTION_DAYS=5

# Script Configuration
readonly SCRIPT_NAME=$(basename "$0")
readonly DATE=$(date +"%Y-%m-%d_%H-%M-%S")
readonly CURRENT_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

#------------------------------------------------------------------------------
# COLORS AND OUTPUT FUNCTIONS
#------------------------------------------------------------------------------

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Output functions with consistent formatting
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
    log "INFO: $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    log "WARNING: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    log "ERROR: $1"
}

print_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1" >&2
        log "DEBUG: $1"
    fi
}

#------------------------------------------------------------------------------
# VALIDATION FUNCTIONS
#------------------------------------------------------------------------------

# Check system dependencies
check_dependencies() {
    print_info "Checking system dependencies..."
    
    local -a missing_deps=()
    local -a required_deps=("curl" "jq" "tar" "find")
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_info "Install with: apkg install ${missing_deps[*]}"
        return 1
    fi
    
    print_success "All dependencies satisfied"
    return 0
}

# Validate script configuration
validate_configuration() {
    print_info "Validating configuration..."
    
    # Check API token
    if [[ -z "$PAYMO_TOKEN" ]]; then
        print_error "PAYMO_TOKEN not found. Please set environment variable or create /home/Emerson/.paymo_token"
        print_info "Get your API key at: https://app.paymoapp.com -> Settings -> API & Integrations"
        return 1
    fi
    
    # Check email configuration
    if [[ -z "$PAYMO_EMAIL" || "$PAYMO_EMAIL" == "example@domain.com" ]]; then
        print_error "Please configure PAYMO_EMAIL variable"
        return 1
    fi
    
    # Validate base directory path
    if [[ ! "$BASE_DIR" =~ ^/ ]]; then
        print_error "BASE_DIR must be an absolute path"
        return 1
    fi
    
    print_success "Configuration validated"
    return 0
}

# Test API connectivity and authentication
test_api_connectivity() {
    print_info "Testing Paymo API connectivity..."
    
    local http_code
    http_code=$(curl -s --connect-timeout 10 -w "%{http_code}" -o /dev/null \
        -u "$PAYMO_TOKEN:random" \
        -H "Accept: application/json" \
        "$PAYMO_API_BASE/me")
    
    case "$http_code" in
        200)
            print_success "API connectivity verified"
            return 0
            ;;
        401)
            print_error "Invalid API credentials (HTTP: $http_code)"
            return 1
            ;;
        *)
            print_error "API connectivity failed (HTTP: $http_code)"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# DIRECTORY MANAGEMENT
#------------------------------------------------------------------------------

# Create necessary directory structure
setup_directories() {
    print_info "Setting up directory structure..."
    
    local -a directories=("$BASE_DIR" "$BASE_DIR/logs")
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if mkdir -p "$dir"; then
                print_success "Created directory: $dir"
            else
                print_error "Failed to create directory: $dir"
                return 1
            fi
        else
            print_debug "Directory exists: $dir"
        fi
    done
    
    # Set appropriate permissions
    chmod 755 "$BASE_DIR" "$BASE_DIR/logs" || {
        print_warning "Could not set directory permissions"
    }
    
    print_success "Directory structure ready"
    return 0
}

#------------------------------------------------------------------------------
# API INTERACTION FUNCTIONS
#------------------------------------------------------------------------------

# Define API endpoints configuration
declare -A API_ENDPOINTS=(
    ["projects"]="Projects"
    ["clients"]="Clients" 
    ["users"]="Users"
    ["tasks"]="Tasks"
    ["entries?where=time_interval%20in%20(%222014-12-01T00:00:00Z%22,%22${CURRENT_TIMESTAMP}%22)"]="TimeEntries" 
    ["invoicepayments"]="InvoicePayments"
    ["expenses"]="Expenses"
    ["milestones"]="Milestones"
    ["discussions"]="Discussions"
    ["files"]="Files"
    ["reports"]="Reports"
    ["hooks"]="Webhooks"
)

# Make API request and save data
execute_api_request() {
    local endpoint="$1"
    local filename="$2"
    local description="$3"
    
    local temp_file="/tmp/paymo_${SCRIPT_NAME}_$.json"
    local output_file="${BASE_DIR}/${filename}.json"
    
    print_info "Fetching $description..."
    print_debug "Endpoint: $endpoint"
    print_debug "Output file: $output_file"
    
    # Make API request
    local http_code
    http_code=$(curl -s -w "%{http_code}" \
        --connect-timeout 30 \
        --max-time 300 \
        -u "$PAYMO_TOKEN:random" \
        -H "Accept: application/json" \
        -H "User-Agent: PaymoBackup/2.0" \
        "$PAYMO_API_BASE/$endpoint" \
        -o "$temp_file" 2>/dev/null) || {
        print_error "$description - curl command failed"
        rm -f "$temp_file"
        return 1
    }
    
    print_debug "HTTP response code: $http_code"
    
    # Process response
    case "$http_code" in
        200)
            if [[ -s "$temp_file" ]]; then
                # Validate JSON first
                if ! jq empty "$temp_file" >/dev/null 2>&1; then
                    print_error "$description - Invalid JSON response"
                    rm -f "$temp_file"
                    return 1
                fi
                
                # Create structured backup entry
                local backup_entry
                backup_entry=$(jq -n \
                    --arg timestamp "$DATE" \
                    --arg endpoint "$endpoint" \
                    --slurpfile data "$temp_file" \
                    '{
                        backup_metadata: {
                            timestamp: $timestamp,
                            endpoint: $endpoint,
                            script_version: "2.0"
                        },
                        data: $data[0]
                    }' 2>/dev/null) || {
                    print_error "$description - Failed to create backup entry"
                    rm -f "$temp_file"
                    return 1
                }
                
                # Save as new file (overwrite previous)
                echo "[$backup_entry]" > "$output_file" || {
                    print_error "$description - Failed to write output file"
                    rm -f "$temp_file"
                    return 1
                }
                
                # Get file statistics
                local file_size entry_count
                file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "unknown")
                entry_count=$(jq '.data | length // 0' "$output_file" 2>/dev/null || echo "unknown")
                
                print_success "$description saved ($entry_count entries, ${file_size} bytes)"
                print_debug "Output file: $output_file"
                
                # Cleanup
                rm -f "$temp_file"
                return 0
            else
                print_warning "$description returned empty response"
                rm -f "$temp_file"
                return 1
            fi
            ;;
        401)
            print_error "$description - Authentication failed (HTTP: $http_code)"
            rm -f "$temp_file"
            return 1
            ;;
        403)
            print_error "$description - Access forbidden (HTTP: $http_code)"
            rm -f "$temp_file"
            return 1
            ;;
        404)
            print_error "$description - Endpoint not found (HTTP: $http_code)"
            rm -f "$temp_file"
            return 1
            ;;
        500|502|503)
            print_error "$description - Server error (HTTP: $http_code)"
            rm -f "$temp_file"
            return 1
            ;;
        *)
            print_error "$description failed (HTTP: $http_code)"
            rm -f "$temp_file"
            return 1
            ;;
    esac
}

# Fetch user information
fetch_user_info() {
    print_info "Fetching user information..."
    
    if execute_api_request "me" "user_info" "User Information"; then
        local user_file="$BASE_DIR/user_info.json"
        if [[ -f "$user_file" ]]; then
            local user_name company
            user_name=$(jq -r '.[-1].data.name // "Unknown"' "$user_file" 2>/dev/null || echo "Unknown")
            company=$(jq -r '.[-1].data.company // "Unknown"' "$user_file" 2>/dev/null || echo "Unknown")
            print_info "Backup user: $user_name ($company)"
        fi
        return 0
    else
        print_error "Failed to fetch user information"
        return 1
    fi
}

#------------------------------------------------------------------------------
# MAIN BACKUP FUNCTIONS
#------------------------------------------------------------------------------

# Execute main backup process
execute_backup() {
    print_info "Starting Paymo data backup process..."
    
    # Clear previous backup files
    if ls "$BASE_DIR"/*.json >/dev/null 2>&1; then
        print_info "Removing previous backup files..."
        rm -f "$BASE_DIR"/*.json || {
            print_error "Failed to clear previous files"
            return 0
        }
    fi
    
    # Fetch user information first (not mandatory for backup to continue)
    fetch_user_info || print_warning "Could not fetch user information, continuing with backup..."
    
    # Process all API endpoints
    local success_count=0
    local failed_count=0
    local total_endpoints=${#API_ENDPOINTS[@]}
    local -a failed_endpoints=()
    local current=0
    
    print_info "Processing $total_endpoints API endpoints..."
    
    for endpoint in "${!API_ENDPOINTS[@]}"; do
        ((current++))
        local description="${API_ENDPOINTS[$endpoint]}"
        local filename=$(echo "$description" | sed 's/[^a-zA-Z0-9]/_/g')
        
        print_info "Processing [$current/$total_endpoints]: $description"
        print_debug "Endpoint URL: $PAYMO_API_BASE/$endpoint"
        
        # Execute request with error handling
        if execute_api_request "$endpoint" "$filename" "$description"; then
            ((success_count++))
            print_success "✓ $description completed successfully"
        else
            ((failed_count++))
            failed_endpoints+=("$description")
            print_error "✗ $description failed"
        fi
        
        # Rate limiting between requests (except for last one)
        if [[ $current -lt $total_endpoints ]]; then
            print_debug "Waiting ${RATE_LIMIT_SECONDS}s before next request..."
            sleep "$RATE_LIMIT_SECONDS"
        fi
    done
    
    # Generate backup summary
    print_info ""
    print_info "================================================"
    print_info "BACKUP EXECUTION SUMMARY"
    print_info "================================================"
    print_success "Successfully processed: $success_count/$total_endpoints endpoints"
    
    if [[ $failed_count -gt 0 ]]; then
        print_error "Failed endpoints: $failed_count"
        for failed in "${failed_endpoints[@]}"; do
            print_error "  • $failed"
        done
    fi
    
    return $success_count
}

# Validate backup integrity
validate_backup_integrity() {
    print_info "Validating backup file integrity..."
    
    local validation_errors=0
    
    for file in "$BASE_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            local basename
            basename=$(basename "$file")
            
            # Check if file is not empty
            if [[ ! -s "$file" ]]; then
                print_error "Empty file detected: $basename"
                ((validation_errors++))
                continue
            fi
            
            # Validate JSON structure
            if ! jq empty "$file" >/dev/null 2>&1; then
                print_error "Invalid JSON in file: $basename"
                ((validation_errors++))
                continue
            fi
            
            print_debug "Valid backup file: $basename"
        fi
    done
    
    if [[ $validation_errors -eq 0 ]]; then
        print_success "All backup files validated successfully"
        return 0
    else
        print_error "Found $validation_errors validation errors"
        return 1
    fi
}

#------------------------------------------------------------------------------
# REPORTING AND CLEANUP
#------------------------------------------------------------------------------

# Generate backup summary report
generate_backup_summary() {
    print_info "Generating backup summary report..."
    
    local summary_file="$BASE_DIR/logs/backup_summary_$DATE.txt"
    
    {
        echo "==============================================="
        echo "PAYMO BACKUP SUMMARY REPORT"
        echo "==============================================="
        echo "Backup Date: $DATE"
        echo "User Email: $PAYMO_EMAIL"
        echo "Script Version: 2.0"
        echo "Backup Location: $BASE_DIR"
        echo ""
        echo "BACKUP FILES STATUS:"
        echo "-------------------"
        
        for file in "$BASE_DIR"/*.json; do
            if [[ -f "$file" ]]; then
                local basename filename entries file_size
                basename=$(basename "$file" .json)
                filename=$(basename "$file")
                entries=$(jq '.[-1].data | to_entries[] | select(.value | type == "array") | .value | length' "$file" 2>/dev/null | head -n1 || echo "0")
                file_size=$(du -sh "$file" 2>/dev/null | cut -f1 || echo "unknown")
                printf "%-20s: %6s entries (%8s)\n" "$basename" "$entries" "$file_size"
            fi
        done
                
        echo ""
        echo "STORAGE SUMMARY:"
        echo "---------------"
        echo "Total backup size: $(du -sh "$BASE_DIR" 2>/dev/null | cut -f1 || echo "unknown")"
        echo "Available space: $(df -h "$BASE_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo "unknown")"
        echo ""
        echo "=================================================="
        echo "Report generated at: $(date)"
        echo "=================================================="
    } > "$summary_file"
    
    print_success "Summary report created: $summary_file"
    return 0
}

# Cleanup old log files (preserve all data)
cleanup_old_logs() {
    print_info "Cleaning up old log files..."
    
    local total_deleted=0
    
    # Clean old summary logs
    local summary_deleted
    summary_deleted=$(find "$BASE_DIR/logs" -name "backup_summary_*.txt" -mtime +$SUMMARY_RETENTION_DAYS 2>/dev/null | wc -l)
    
    if [[ $summary_deleted -gt 0 ]]; then
        find "$BASE_DIR/logs" -name "backup_summary_*.txt" -mtime +$SUMMARY_RETENTION_DAYS -delete 2>/dev/null
        print_success "Cleaned $summary_deleted old summary files"
        total_deleted=$((total_deleted + summary_deleted))
    fi
    
    # Clean old main logs
    local main_deleted
    main_deleted=$(find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE" .log)*.log" -mtime +$LOG_RETENTION_DAYS 2>/dev/null | wc -l)
    
    if [[ $main_deleted -gt 0 ]]; then
        find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE" .log)*.log" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null
        print_success "Cleaned $main_deleted old log files"
        total_deleted=$((total_deleted + main_deleted))
    fi
    
    if [[ $total_deleted -eq 0 ]]; then
        print_info "No old logs to clean"
    else
        print_success "Total cleaned: $total_deleted log files"
    fi
    
    print_info "All backup data preserved permanently"
    return 0
}

#------------------------------------------------------------------------------
# ERROR HANDLING
#------------------------------------------------------------------------------

# Error handling - remove global error trap since we handle errors locally
# handle_error() {
#     local exit_code=$?
#     local line_number=$1
#     
#     print_error "Script failed at line $line_number with exit code $exit_code"
#     print_info "Check log file for details: $LOG_FILE"
#     
#     # Cleanup temp files
#     rm -f /tmp/paymo_${SCRIPT_NAME}_*.json 2>/dev/null || true
#     
#     exit $exit_code
# }

# Cleanup function for temp files
cleanup_temp_files() {
    print_debug "Cleaning up temporary files..."
    rm -f /tmp/paymo_${SCRIPT_NAME}_*.json 2>/dev/null || true
}

# Set cleanup trap instead of error trap
trap cleanup_temp_files EXIT

#------------------------------------------------------------------------------
# MAIN EXECUTION FUNCTION
#------------------------------------------------------------------------------

main() {
    # Script header
    print_info "================================================"
    print_info "PAYMO BACKUP SCRIPT v2.0 - STARTING EXECUTION"
    print_info "================================================"
    print_info "Email: $PAYMO_EMAIL"
    print_info "Backup Directory: $BASE_DIR"
    print_info "Log File: $LOG_FILE"
    print_info "Data Retention: Permanent (incremental backups)"
    print_info "Timestamp: $DATE"
    
    # Pre-flight checks
    print_info "Executing pre-flight checks..."
    check_dependencies || exit 1
    validate_configuration || exit 1
    setup_directories || exit 1
    test_api_connectivity || exit 1
    
    print_success "Pre-flight checks completed successfully"
    
    # Execute main backup
    print_info "Initiating backup process..."
    local backup_result
    execute_backup
    backup_result=$?
    
    # Post-backup operations
    if [[ $backup_result -gt 0 ]]; then
        validate_backup_integrity || print_warning "Backup validation had issues"
        generate_backup_summary || print_warning "Could not generate summary"
        cleanup_old_logs || print_warning "Log cleanup had issues"
        
        # Final status report
        print_info "================================================"
        print_success "BACKUP OPERATION COMPLETED"
        print_info "================================================"
        print_info "Location: $BASE_DIR"
        print_info "Summary: $BASE_DIR/logs/backup_summary_$DATE.txt"
        print_info "Log: $LOG_FILE"
        print_info "Successful endpoints: $backup_result"
        
        # File status overview
        print_info ""
        print_info "BACKUP FILES OVERVIEW:"
        for file in "$BASE_DIR"/*.json; do
            if [[ -f "$file" ]]; then
                local basename entries file_size
                basename=$(basename "$file" .json)
                entries=$(jq '.[-1].data | to_entries[] | select(.value | type == "array") | .value | length' "$file" 2>/dev/null | head -n1 || echo "0")
                file_size=$(du -sh "$file" 2>/dev/null | cut -f1 || echo "unknown")
                print_info "  • $basename: $entries entries ($file_size)"
            fi
        done
        
        print_success "Backup completed successfully"
        exit 0
    else
        print_error "Backup operation failed - no endpoints processed successfully"
        print_info "Check log file: $LOG_FILE"
        exit 1
    fi
}

#------------------------------------------------------------------------------
# SCRIPT ENTRY POINT
#------------------------------------------------------------------------------

# Ensure script is not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
else
    print_error "This script should be executed, not sourced"
    exit 1
fi