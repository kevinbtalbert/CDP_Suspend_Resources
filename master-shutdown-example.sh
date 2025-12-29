#!/bin/bash

################################################################################
# CDP Master Shutdown Script - EXAMPLE CONFIGURATION
# 
# This is an example configuration file showing how to configure the master
# shutdown script for your specific environment.
#
# Copy this file to master-shutdown.sh and edit the configuration values.
################################################################################

set -e  # Exit on error

################################################################################
# CONFIGURATION SECTION - EDIT THESE VALUES
################################################################################

# CDP Credentials - Set these to your CDP access credentials
export CDP_ACCESS_KEY_ID="82c1e84d-b960-4f67-bcc9-123e0a98f886"
export CDP_PRIVATE_KEY="M0i3EXPPZLHVO0jUDRlSpMTIx1nu8AtGQka9ug+mwEE="

# CDP Region/Endpoint (optional - defaults to us-west-1)
export CDP_REGION="us-west-1"
export CDP_ENDPOINT_URL="https://console.${CDP_REGION}.cdp.cloudera.com"

# Environment Configuration
# Example: "xzhong-cml-env" or "se-sandbox-aws"
ENVIRONMENT_NAME="pdf-dec-cdp-env"

# DataHub Configuration
# Specify DataHub names as comma-separated list
# Examples:
#   DATAHUB_NAMES="anjanraz,fcatestdh"  # Specific datahubs
#   DATAHUB_NAMES=""                     # All datahubs in environment
DATAHUB_NAMES=""

# ML Workspace Configuration
# Specify ML Workspace CRNs as comma-separated list
# Examples:
#   ML_WORKSPACE_CRNS="crn:cdp:ml:us-west-1:558bc1d2-8867-4357-8524-311d51259233:workspace:f6a78e0d-51db-4f06-885d-cd359d68bc14"
#   ML_WORKSPACE_CRNS=""  # All ML workspaces
ML_WORKSPACE_CRNS="crn:cdp:ml:us-west-1:558bc1d2-8867-4357-8524-311d51259233:workspace:28c27082-367e-4c9e-9b75-81776f0bd86b"

# Timing Configuration (in seconds)
# Default: 3600 seconds = 1 hour between each phase
# For testing: 60 seconds = 1 minute
# For production: 3600 seconds = 1 hour
DELAY_BETWEEN_PHASES=60  # Set to 60 for testing, 3600 for production

# Logging Configuration
LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/master-shutdown-$(date '+%Y%m%d-%H%M%S').log"

# Script paths (relative to this script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ML_WORKSPACE_SCRIPT="${SCRIPT_DIR}/suspend-ml-workspaces.sh"
DATAHUB_SCRIPT="${SCRIPT_DIR}/stop-datahubs.sh"
ENVIRONMENT_SCRIPT="${SCRIPT_DIR}/stop-environments.sh"

################################################################################
# END CONFIGURATION SECTION
################################################################################

################################################################################
# FUNCTIONS
################################################################################

# Function to log messages to both console and log file
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Function to log section headers
log_section() {
    local message="$1"
    log ""
    log "================================================================================"
    log "$message"
    log "================================================================================"
    log ""
}

# Function to setup CDP credentials
setup_credentials() {
    log "Setting up CDP credentials..."
    
    # Create credentials file for CDP CLI
    mkdir -p ~/.cdp
    cat > ~/.cdp/credentials << EOF
[default]
cdp_access_key_id=${CDP_ACCESS_KEY_ID}
cdp_private_key=${CDP_PRIVATE_KEY}
EOF
    
    chmod 600 ~/.cdp/credentials
    log "CDP credentials configured successfully"
}

# Function to validate prerequisites
validate_prerequisites() {
    log "Validating prerequisites..."
    
    # Check if virtual environment exists
    if [ ! -d "${SCRIPT_DIR}/cdpclienv" ]; then
        log "ERROR: CDP CLI virtual environment not found at ${SCRIPT_DIR}/cdpclienv"
        log "Please run setup-venv.sh first"
        exit 1
    fi
    
    # Check if required scripts exist
    if [ ! -f "$ML_WORKSPACE_SCRIPT" ]; then
        log "ERROR: ML Workspace script not found at $ML_WORKSPACE_SCRIPT"
        exit 1
    fi
    
    if [ ! -f "$DATAHUB_SCRIPT" ]; then
        log "ERROR: DataHub script not found at $DATAHUB_SCRIPT"
        exit 1
    fi
    
    if [ ! -f "$ENVIRONMENT_SCRIPT" ]; then
        log "ERROR: Environment script not found at $ENVIRONMENT_SCRIPT"
        exit 1
    fi
    
    log "All prerequisites validated successfully"
}

# Function to wait for specified duration with countdown
wait_with_countdown() {
    local duration=$1
    local description=$2
    
    log "Waiting $duration seconds ($((duration/60)) minutes) before $description..."
    
    local remaining=$duration
    while [ $remaining -gt 0 ]; do
        if [ $remaining -eq $duration ] || [ $((remaining % 300)) -eq 0 ]; then
            log "Time remaining: $remaining seconds ($((remaining/60)) minutes)"
        fi
        sleep 60
        remaining=$((remaining - 60))
    done
    
    log "Wait complete. Proceeding with $description..."
}

# Function to execute a script and capture output
execute_script() {
    local script_path=$1
    local script_args=$2
    local script_name=$(basename "$script_path")
    
    log "Executing $script_name..."
    log "Script: $script_path"
    log "Arguments: $script_args"
    
    # Execute the script and capture output
    if [ -n "$script_args" ]; then
        bash "$script_path" "$script_args" 2>&1 | tee -a "$LOG_FILE"
    else
        bash "$script_path" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        log "$script_name completed successfully"
        return 0
    else
        log "ERROR: $script_name failed with exit code $exit_code"
        return $exit_code
    fi
}

################################################################################
# MAIN EXECUTION
################################################################################

# Create log directory
mkdir -p "$LOG_DIR"

log_section "CDP Master Shutdown Script Started"

# Determine which phases will run
PHASES_TO_RUN=()
if [ -n "$ML_WORKSPACE_CRNS" ]; then
    PHASES_TO_RUN+=("ML Workspaces")
fi
if [ -n "$DATAHUB_NAMES" ]; then
    PHASES_TO_RUN+=("DataHubs")
fi
if [ -n "$ENVIRONMENT_NAME" ]; then
    PHASES_TO_RUN+=("Environment")
fi

# Validate that at least one phase is configured
if [ ${#PHASES_TO_RUN[@]} -eq 0 ]; then
    log "ERROR: No resources specified for shutdown!"
    log "Please configure at least one of:"
    log "  - ML_WORKSPACE_CRNS (for ML Workspaces)"
    log "  - DATAHUB_NAMES (for DataHubs)"
    log "  - ENVIRONMENT_NAME (for Environment)"
    exit 1
fi

log "Configuration:"
log "  ML Workspaces: ${ML_WORKSPACE_CRNS:-'(skipped - not configured)'}"
log "  DataHubs: ${DATAHUB_NAMES:-'(skipped - not configured)'}"
log "  Environment: ${ENVIRONMENT_NAME:-'(skipped - not configured)'}"
log "  Phases to execute: ${PHASES_TO_RUN[*]}"
log "  Delay between phases: $DELAY_BETWEEN_PHASES seconds ($((DELAY_BETWEEN_PHASES/60)) minutes)"
log "  Log file: $LOG_FILE"

# Setup credentials
setup_credentials

# Validate prerequisites
validate_prerequisites

# Track if we need to wait before next phase
PREVIOUS_PHASE_RAN=false

################################################################################
# PHASE 1: Suspend ML Workspaces
################################################################################

if [ -n "$ML_WORKSPACE_CRNS" ]; then
    log_section "PHASE 1: Suspending ML Workspaces"
    
    if execute_script "$ML_WORKSPACE_SCRIPT" "$ML_WORKSPACE_CRNS"; then
        log "ML Workspaces suspension phase completed successfully"
    else
        log "WARNING: ML Workspaces suspension encountered errors, but continuing..."
    fi
    
    PREVIOUS_PHASE_RAN=true
else
    log_section "PHASE 1: Skipping ML Workspaces (not configured)"
fi

################################################################################
# PHASE 2: Stop DataHubs
################################################################################

if [ -n "$DATAHUB_NAMES" ]; then
    # Wait if a previous phase ran
    if [ "$PREVIOUS_PHASE_RAN" = true ]; then
        log_section "WAIT PERIOD: Before DataHub Shutdown"
        wait_with_countdown "$DELAY_BETWEEN_PHASES" "DataHub shutdown"
    fi
    
    log_section "PHASE 2: Stopping DataHubs"
    
    if execute_script "$DATAHUB_SCRIPT" "$DATAHUB_NAMES"; then
        log "DataHub shutdown phase completed successfully"
    else
        log "WARNING: DataHub shutdown encountered errors, but continuing..."
    fi
    
    PREVIOUS_PHASE_RAN=true
else
    log_section "PHASE 2: Skipping DataHubs (not configured)"
fi

################################################################################
# PHASE 3: Stop Environment
################################################################################

if [ -n "$ENVIRONMENT_NAME" ]; then
    # Wait if a previous phase ran
    if [ "$PREVIOUS_PHASE_RAN" = true ]; then
        log_section "WAIT PERIOD: Before Environment Shutdown"
        wait_with_countdown "$DELAY_BETWEEN_PHASES" "Environment shutdown"
    fi
    
    log_section "PHASE 3: Stopping Environment"
    
    if execute_script "$ENVIRONMENT_SCRIPT" "$ENVIRONMENT_NAME"; then
        log "Environment shutdown phase completed successfully"
    else
        log "ERROR: Environment shutdown encountered errors"
        exit 1
    fi
else
    log_section "PHASE 3: Skipping Environment (not configured)"
fi

################################################################################
# COMPLETION
################################################################################

log_section "CDP Master Shutdown Script Completed Successfully"

log "Summary:"
log "  Phases executed: ${PHASES_TO_RUN[*]}"
log "  Start time: $(head -1 "$LOG_FILE" | awk '{print $1, $2}')"
log "  End time: $(date '+%Y-%m-%d %H:%M:%S')"
log "  Log file: $LOG_FILE"
log ""
log "All configured CDP resources have been shut down successfully."
log "To start resources again, use the corresponding start scripts."

exit 0

