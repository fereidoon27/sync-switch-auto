#!/bin/bash

# Get script directory for finding config file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="$(dirname "$0")/Info"
SERVERS_CONF="$INFO_PATH/servers.conf"

# Log file setup
LOG_FILE="$HOME/sync_$(date +%Y%m%d).log"

# Default configuration
MAX_PARALLEL_JOBS=4
INTERACTIVE_MODE=true
AUTO_DATACENTER=""
AUTO_VMS=""

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -d, --datacenter DATACENTER   Specify destination datacenter"
    echo "  -v, --vms VM_LIST             Specify VMs to sync (comma-separated numbers or 'all')"
    echo "  -j, --jobs NUM                Number of parallel jobs (default: 4)"
    echo "  -y, --yes                     Skip confirmation prompt"
    echo "  -h, --help                    Show this help message"
    echo
    echo "Example automated usage:"
    echo "  $0 --datacenter arvan --vms all --jobs 8 --yes"
    echo "  $0 -d cloudzy -v 1,3,5 -j 4 -y"
    exit 1
}

# Parse command-line arguments
SKIP_CONFIRM=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--datacenter)
            AUTO_DATACENTER="$2"
            INTERACTIVE_MODE=false
            shift 2
            ;;
        -v|--vms)
            AUTO_VMS="$2"
            INTERACTIVE_MODE=false
            shift 2
            ;;
        -j|--jobs)
            MAX_PARALLEL_JOBS="$2"
            shift 2
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done
RUNNING_JOBS=0

# SSH optimization options
SSH_OPTS="-o StrictHostKeyChecking=no -o ControlMaster=auto -o ControlPath=/tmp/ssh_mux_%h_%p_%r -o ControlPersist=1h -o BatchMode=yes"

# Function for logging
log() {
    local message="$1"
    local log_to_console="${2:-true}"
    
    # Always log to file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    
    # Only echo to console if requested
    if [ "$log_to_console" = "true" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
    fi
}

# Function to wait for background jobs
wait_for_jobs() {
    while [ $RUNNING_JOBS -ge $MAX_PARALLEL_JOBS ]; do
        # Wait for any child process to finish
        wait -n 2>/dev/null || true
        # Count running jobs again
        RUNNING_JOBS=$(jobs -p | wc -l)
    done
}

# Check if servers.conf exists
if [ ! -f "$SERVERS_CONF" ]; then
    log "ERROR: Configuration file $SERVERS_CONF not found"
    exit 1
fi

# Function to get unique datacenters from servers.conf
get_datacenters() {
    awk -F'|' '{print $1}' "$SERVERS_CONF" | sort -u
}

# Function to get VMs for a specific datacenter
get_vms_for_datacenter() {
    local datacenter="$1"
    awk -F'|' -v dc="$datacenter" '$1 == dc {print $2}' "$SERVERS_CONF"
}

# Function to get server info from servers.conf
get_server_info() {
    local datacenter="$1"
    local vm_name="$2"
    local field="$3"
    
    # Field mapping: 1=datacenter, 2=vm_name, 3=ip, 4=host, 5=username, 6=port
    local field_num
    case "$field" in
        "ip") field_num=3 ;;
        "host") field_num=4 ;;
        "username") field_num=5 ;;
        "port") field_num=6 ;;
        *) field_num=0 ;;
    esac
    
    if [ "$field_num" -eq 0 ]; then
        echo "unknown"
        return
    fi
    
    awk -F'|' -v dc="$datacenter" -v vm="$vm_name" -v fn="$field_num" \
        '$1 == dc && $2 == vm {print $fn}' "$SERVERS_CONF"
}

# Create pattern file for rsync once
PATTERN_FILE="/tmp/rsync_patterns_$"
cat > "$PATTERN_FILE" << EOF
+ van-buren-*/
+ van-buren-*/**
+ *.sh
+ .secret/
+ .secret/**
- *
EOF

# Log pattern file info to log file only, not to console
log "Pattern file created with the following patterns:" false
cat "$PATTERN_FILE" | while read line; do log "  $line" false; done

# Get unique datacenters
DATACENTERS=($(get_datacenters))

# Handle datacenter selection (interactive or automated)
if [ "$INTERACTIVE_MODE" = true ]; then
    # Interactive mode - prompt user for datacenter
    echo "Available datacenters:"
    for i in "${!DATACENTERS[@]}"; do
        echo "$((i+1)). ${DATACENTERS[$i]}"
    done

    # Get destination datacenter
    while true; do
        read -p "Choose destination datacenter (1-${#DATACENTERS[@]}): " DST_DC_CHOICE
        if [[ "$DST_DC_CHOICE" =~ ^[0-9]+$ ]] && [ "$DST_DC_CHOICE" -ge 1 ] && [ "$DST_DC_CHOICE" -le "${#DATACENTERS[@]}" ]; then
            DEST_DATACENTER="${DATACENTERS[$((DST_DC_CHOICE-1))]}"
            break
        fi
        echo "Invalid selection. Please try again."
    done
else
    # Automated mode - use provided datacenter
    DEST_DATACENTER=""
    for dc in "${DATACENTERS[@]}"; do
        if [ "$dc" = "$AUTO_DATACENTER" ]; then
            DEST_DATACENTER="$dc"
            break
        fi
    done
    
    if [ -z "$DEST_DATACENTER" ]; then
        log "ERROR: Invalid datacenter specified: $AUTO_DATACENTER"
        echo "Available datacenters:"
        for dc in "${DATACENTERS[@]}"; do
            echo "  $dc"
        done
        exit 1
    fi
    
    log "Using datacenter: $DEST_DATACENTER"
fi

# Get VMs for destination datacenter
DEST_VMS=($(get_vms_for_datacenter "$DEST_DATACENTER"))

# Handle VM selection (interactive or automated)
if [ "$INTERACTIVE_MODE" = true ]; then
    # Display VM options for destination with "all" as an additional option
    echo "Available VMs in $DEST_DATACENTER datacenter:"
    for i in "${!DEST_VMS[@]}"; do
        echo "$((i+1)). ${DEST_VMS[$i]}"
    done
    echo "$((${#DEST_VMS[@]}+1)). all (select all VMs)"

    # Get destination VM(s)
    while true; do
        echo "Enter VM numbers to select multiple VMs (e.g., '246' for VMs 2, 4, and 6)"
        read -p "Choose destination VM(s) (1-$((${#DEST_VMS[@]}+1))): " DST_VM_CHOICE
        
        # Initialize array for selected VMs
        SELECTED_VMS=()
        
        # Check if user selected "all" option
        if [[ "$DST_VM_CHOICE" == "$((${#DEST_VMS[@]}+1))" ]]; then
            # Select all VMs
            for ((i=0; i<${#DEST_VMS[@]}; i++)); do
                SELECTED_VMS+=("${DEST_VMS[$i]}")
            done
            break
        elif [[ "$DST_VM_CHOICE" =~ ^[0-9]+$ ]]; then
            # Process each digit in the input
            valid_selection=true
            for ((i=0; i<${#DST_VM_CHOICE}; i++)); do
                digit="${DST_VM_CHOICE:$i:1}"
                if [[ "$digit" -ge 1 && "$digit" -le "${#DEST_VMS[@]}" ]]; then
                    SELECTED_VMS+=("${DEST_VMS[$((digit-1))]}")
                else
                    echo "Invalid VM number: $digit"
                    valid_selection=false
                    break
                fi
            done
            
            if [[ "$valid_selection" == true ]]; then
                break
            fi
        else
            echo "Invalid selection. Please try again."
        fi
    done
else
    # Automated mode - use provided VM list
    SELECTED_VMS=()
    
    if [ "$AUTO_VMS" = "all" ]; then
        # Select all VMs in this datacenter
        for ((i=0; i<${#DEST_VMS[@]}; i++)); do
            SELECTED_VMS+=("${DEST_VMS[$i]}")
        done
    else
        # Process comma-separated VM numbers
        IFS=',' read -ra VM_INDEXES <<< "$AUTO_VMS"
        
        for idx in "${VM_INDEXES[@]}"; do
            if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le "${#DEST_VMS[@]}" ]; then
                SELECTED_VMS+=("${DEST_VMS[$((idx-1))]}")
            else
                log "ERROR: Invalid VM index: $idx (must be between 1 and ${#DEST_VMS[@]})"
                exit 1
            fi
        done
    fi
    
    log "Selected VMs: ${SELECTED_VMS[*]}"
fi

# Display selected VMs in interactive mode
if [ "$INTERACTIVE_MODE" = true ]; then
    echo "Selected VMs:"
    for vm in "${SELECTED_VMS[@]}"; do
        echo "- $vm"
    done
fi

# Display configuration summary and confirm unless --yes was specified
echo -e "\nConfiguration Summary:"
echo "Source: Main Machine ($(hostname))"
echo "Destination Datacenter: $DEST_DATACENTER"
echo "Number of selected VMs: ${#SELECTED_VMS[@]}"
echo "Max parallel jobs: $MAX_PARALLEL_JOBS"

if [ "$SKIP_CONFIRM" = false ]; then
    read -p "Continue? (y/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log "Operation canceled by user"
        rm -f "$PATTERN_FILE"
        exit 0
    fi
else
    log "Automatic confirmation (--yes flag provided)"
fi

# Pre-establish SSH connections for all VMs to speed up subsequent operations
log "Pre-establishing SSH connections..."
for DEST_VM in "${SELECTED_VMS[@]}"; do
    # Set connection parameters for current VM
    DEST_USER=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "username")
    DEST_IP=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "ip")
    DEST_PORT=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "port")
    
    # Establish control socket
    ssh $SSH_OPTS -p $DEST_PORT -M -f -N $DEST_USER@$DEST_IP &>/dev/null &
done

# Setup trap to clean up connections and temp files on exit
cleanup() {
    log "Cleaning up connections and temporary files..."
    # Kill all SSH control masters
    for DEST_VM in "${SELECTED_VMS[@]}"; do
        DEST_USER=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "username")
        DEST_IP=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "ip")
        DEST_PORT=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "port")
        ssh $SSH_OPTS -p $DEST_PORT -O exit $DEST_USER@$DEST_IP &>/dev/null || true
    done
    
    # Remove pattern file
    rm -f "$PATTERN_FILE"
    
    log "Cleanup completed"
}
trap cleanup EXIT

# Function to sync a VM
sync_vm() {
    local VM=$1
    
    # Create a VM-specific log file for capturing non-progress output
    local VM_LOG_FILE="/tmp/sync_${VM}_$.log"
    
    # Print header to console
    echo -e "\n========== Processing $VM =========="
    
    # Set connection parameters for current VM
    DEST_USER=$(get_server_info "$DEST_DATACENTER" "$VM" "username")
    DEST_HOST=$(get_server_info "$DEST_DATACENTER" "$VM" "host")
    DEST_IP=$(get_server_info "$DEST_DATACENTER" "$VM" "ip")
    DEST_PORT=$(get_server_info "$DEST_DATACENTER" "$VM" "port")

    # Extract VM number for source directory
    VM_NUMBER=$(echo "$VM" | sed -E 's/^cr([0-9]+).*/\1/')
    # SOURCE_PATH="/home/amin/1111-binance-services/cr$VM_NUMBER"
    SOURCE_PATH="$HOME/1111-binance-services/cr$VM_NUMBER"
    DEST_PATH="/home/$DEST_USER"

    log "Current VM: $VM ($DEST_HOST)"
    log "Source Directory: $SOURCE_PATH"
    log "Destination Directory: $DEST_PATH"

    # Check if the connection is working (log to file only if successful)
    if ! ssh $SSH_OPTS -p $DEST_PORT $DEST_USER@$DEST_IP "echo Connection successful" &>/dev/null; then
        log "ERROR: Cannot connect to $VM, skipping this VM"
        echo "========== Failed $VM =========="
        return 1
    fi
    log "Connection to $VM successful" false
    
    # Check if source directory exists
    if [ ! -d "$SOURCE_PATH" ]; then
        log "ERROR: Source directory $SOURCE_PATH does not exist, skipping this VM"
        echo "========== Failed $VM =========="
        return 1
    fi

    # Ensure destination directory exists
    ssh $SSH_OPTS -p $DEST_PORT $DEST_USER@$DEST_IP "mkdir -p $DEST_PATH" &>> "$VM_LOG_FILE"

    # Perform transfer - display progress directly to console
    log "Starting pattern-based transfer from main machine to $VM..."
    
    if rsync -az --progress --info=progress2 --include-from="$PATTERN_FILE" -e "ssh $SSH_OPTS -p $DEST_PORT" "$SOURCE_PATH/" "$DEST_USER@$DEST_IP:$DEST_PATH/"; then
        log "Transfer to $VM completed successfully"
        echo "========== Completed $VM =========="
        
        # Append non-progress logs to main log
        cat "$VM_LOG_FILE" >> "$LOG_FILE"
        rm -f "$VM_LOG_FILE"
        return 0
    else
        log "ERROR: Transfer to $VM failed"
        echo "========== Failed $VM =========="
        
        # Append non-progress logs to main log
        cat "$VM_LOG_FILE" >> "$LOG_FILE"
        rm -f "$VM_LOG_FILE"
        return 1
    fi
}

# Process VMs in parallel with job control
log "Starting parallel transfers (max $MAX_PARALLEL_JOBS concurrent jobs)..."
for DEST_VM in "${SELECTED_VMS[@]}"; do
    # Wait if we've reached max parallel jobs
    wait_for_jobs
    
    # Start a background job for this VM
    sync_vm "$DEST_VM" &
    
    # Increment running jobs counter
    ((RUNNING_JOBS++))
    log "Started sync job for $DEST_VM (running jobs: $RUNNING_JOBS)"
done

# Wait for all remaining jobs to complete
log "Waiting for all transfers to complete..."
wait

log "All transfers completed"

