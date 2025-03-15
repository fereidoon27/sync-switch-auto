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

# ANSI color codes for terminal UI
CYAN="\033[0;36m"       # Primary color
LIGHT_CYAN="\033[1;36m" # Highlighted primary
BLUE="\033[0;34m"       # Secondary color
LIGHT_BLUE="\033[1;34m" # Highlighted secondary
GRAY="\033[0;37m"       # Accent color
DARK_GRAY="\033[1;30m"  # Secondary accent
GREEN="\033[0;32m"      # Success color
RED="\033[0;31m"        # Error color
YELLOW="\033[0;33m"     # Warning color
BOLD="\033[1m"          # Bold text
ITALIC="\033[3m"        # Italic text
RESET="\033[0m"         # Reset formatting

# Function to display usage
usage() {
    echo -e "${CYAN}${BOLD}Sync Tool - Usage Guide${RESET}"
    echo -e "${DARK_GRAY}--------------------------------------------------------${RESET}"
    echo -e "${GRAY}Usage: ${RESET}$0 ${CYAN}[options]${RESET}"
    echo
    echo -e "${CYAN}${BOLD}Options:${RESET}"
    echo -e "  ${CYAN}-d, --datacenter ${LIGHT_CYAN}DATACENTER${RESET}   Specify destination datacenter"
    echo -e "  ${CYAN}-v, --vms ${LIGHT_CYAN}VM_LIST${RESET}             Specify VMs to sync (comma-separated numbers or 'all')"
    echo -e "  ${CYAN}-j, --jobs ${LIGHT_CYAN}NUM${RESET}                Number of parallel jobs (default: 4)"
    echo -e "  ${CYAN}-y, --yes${RESET}                     Skip confirmation prompt"
    echo -e "  ${CYAN}-h, --help${RESET}                    Show this help message"
    echo
    echo -e "${CYAN}${BOLD}Example automated usage:${RESET}"
    echo -e "  ${GRAY}$0 --datacenter arvan --vms all --jobs 8 --yes${RESET}"
    echo -e "  ${GRAY}$0 -d cloudzy -v 1,3,5 -j 4 -y${RESET}"
    echo -e "${DARK_GRAY}--------------------------------------------------------${RESET}"
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
            echo -e "${RED}Unknown option: $1${RESET}"
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
    local log_type="${3:-info}"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Always log to file
    echo "[$timestamp] $message" >> "$LOG_FILE"
    
    # Only echo to console if requested
    if [ "$log_to_console" = "true" ]; then
        case "$log_type" in
            "info")
                echo -e "${CYAN}[${timestamp}]${RESET} $message"
                ;;
            "success")
                echo -e "${GREEN}[${timestamp}]${RESET} $message"
                ;;
            "error")
                echo -e "${RED}[${timestamp}]${RESET} $message"
                ;;
            "warning")
                echo -e "${YELLOW}[${timestamp}]${RESET} $message"
                ;;
        esac
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
    log "ERROR: Configuration file $SERVERS_CONF not found" true "error"
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

# Display script header
clear
echo -e "${LIGHT_CYAN}${BOLD}===========================================${RESET}"
echo -e "${LIGHT_CYAN}${BOLD}            DATACENTER SYNC TOOL          ${RESET}"
echo -e "${LIGHT_CYAN}${BOLD}===========================================${RESET}"
echo -e "${GRAY}Safely synchronize specific files across datacenters${RESET}"
echo

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
    echo -e "${CYAN}${BOLD}DATACENTER SELECTION${RESET}"
    echo -e "${DARK_GRAY}------------------------------------------${RESET}"
    for i in "${!DATACENTERS[@]}"; do
        echo -e "  ${CYAN}${BOLD}$((i+1))${RESET} ${GRAY}|${RESET} ${LIGHT_CYAN}${DATACENTERS[$i]}${RESET}"
    done
    echo -e "${DARK_GRAY}------------------------------------------${RESET}"

    # Get destination datacenter
    while true; do
        echo -en "${CYAN}Choose destination datacenter ${RESET}(${LIGHT_CYAN}1${RESET}-${LIGHT_CYAN}${#DATACENTERS[@]}${RESET}): "
        read DST_DC_CHOICE
        if [[ "$DST_DC_CHOICE" =~ ^[0-9]+$ ]] && [ "$DST_DC_CHOICE" -ge 1 ] && [ "$DST_DC_CHOICE" -le "${#DATACENTERS[@]}" ]; then
            DEST_DATACENTER="${DATACENTERS[$((DST_DC_CHOICE-1))]}"
            break
        fi
        echo -e "${YELLOW}Invalid selection. Please try again.${RESET}"
    done
    
    echo -e "\n${GREEN}✓ Selected datacenter: ${LIGHT_CYAN}${BOLD}${DEST_DATACENTER}${RESET}\n"
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
        log "ERROR: Invalid datacenter specified: $AUTO_DATACENTER" true "error"
        echo -e "${CYAN}Available datacenters:${RESET}"
        for dc in "${DATACENTERS[@]}"; do
            echo -e "  ${LIGHT_CYAN}$dc${RESET}"
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
    echo -e "${CYAN}${BOLD}VM SELECTION${RESET} ${GRAY}(${DEST_DATACENTER})${RESET}"
    echo -e "${DARK_GRAY}------------------------------------------${RESET}"
    for i in "${!DEST_VMS[@]}"; do
        echo -e "  ${CYAN}${BOLD}$((i+1))${RESET} ${GRAY}|${RESET} ${LIGHT_CYAN}${DEST_VMS[$i]}${RESET}"
    done
    echo -e "  ${CYAN}${BOLD}$((${#DEST_VMS[@]}+1))${RESET} ${GRAY}|${RESET} ${LIGHT_CYAN}all ${DARK_GRAY}(select all VMs)${RESET}"
    echo -e "${DARK_GRAY}------------------------------------------${RESET}"

    # Get destination VM(s)
    while true; do
        echo -e "${DARK_GRAY}Enter VM numbers to select multiple VMs (e.g., '246' for VMs 2, 4, and 6)${RESET}"
        echo -en "${CYAN}Choose destination VM(s) ${RESET}(${LIGHT_CYAN}1${RESET}-${LIGHT_CYAN}$((${#DEST_VMS[@]}+1))${RESET}): "
        read DST_VM_CHOICE
        
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
                    echo -e "${YELLOW}Invalid VM number: $digit${RESET}"
                    valid_selection=false
                    break
                fi
            done
            
            if [[ "$valid_selection" == true ]]; then
                break
            fi
        else
            echo -e "${YELLOW}Invalid selection. Please try again.${RESET}"
        fi
    done
    
    # Display selected VMs
    echo -e "\n${GREEN}✓ Selected VMs:${RESET}"
    for vm in "${SELECTED_VMS[@]}"; do
        echo -e "  ${LIGHT_CYAN}• ${vm}${RESET}"
    done
    echo
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
                log "ERROR: Invalid VM index: $idx (must be between 1 and ${#DEST_VMS[@]})" true "error"
                exit 1
            fi
        done
    fi
    
    log "Selected VMs: ${SELECTED_VMS[*]}"
fi

# Display configuration summary and confirm unless --yes was specified
echo -e "${CYAN}${BOLD}CONFIGURATION SUMMARY${RESET}"
echo -e "${DARK_GRAY}------------------------------------------${RESET}"
echo -e "  ${GRAY}Source:${RESET}           ${LIGHT_CYAN}$(hostname)${RESET}"
echo -e "  ${GRAY}Destination:${RESET}      ${LIGHT_CYAN}${DEST_DATACENTER}${RESET}"
echo -e "  ${GRAY}Selected VMs:${RESET}     ${LIGHT_CYAN}${#SELECTED_VMS[@]}${RESET}"
echo -e "  ${GRAY}Parallel Jobs:${RESET}    ${LIGHT_CYAN}${MAX_PARALLEL_JOBS}${RESET}"
echo -e "${DARK_GRAY}------------------------------------------${RESET}"

if [ "$SKIP_CONFIRM" = false ]; then
    echo -en "\n${CYAN}Continue with this configuration? ${RESET}(${GREEN}y${RESET}/${RED}n${RESET}): "
    read CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log "Operation canceled by user" true "warning"
        rm -f "$PATTERN_FILE"
        exit 0
    fi
else
    log "Automatic confirmation (--yes flag provided)" true "info"
fi

# Pre-establish SSH connections for all VMs to speed up subsequent operations
echo
log "Pre-establishing SSH connections..." true "info"
echo -e "${DARK_GRAY}------------------------------------------${RESET}"

# Create a simple spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep -w $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Establish control sockets
for DEST_VM in "${SELECTED_VMS[@]}"; do
    # Set connection parameters for current VM
    DEST_USER=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "username")
    DEST_IP=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "ip")
    DEST_PORT=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "port")
    
    # Display connection attempt
    echo -en "  ${GRAY}Connecting to${RESET} ${LIGHT_CYAN}${DEST_VM}${RESET} "
    
    # Establish control socket and show spinner
    ssh $SSH_OPTS -p $DEST_PORT -M -f -N $DEST_USER@$DEST_IP &>/dev/null &
    spinner $!
    
    # Check if connection succeeded
    if ssh $SSH_OPTS -p $DEST_PORT -O check $DEST_USER@$DEST_IP &>/dev/null; then
        echo -e "${GREEN}✓${RESET}"
    else
        echo -e "${RED}✗${RESET}"
    fi
done
echo -e "${DARK_GRAY}------------------------------------------${RESET}"

# Setup trap to clean up connections and temp files on exit
cleanup() {
    echo
    log "Cleaning up connections and temporary files..." true "info"
    echo -e "${DARK_GRAY}------------------------------------------${RESET}"
    
    # Kill all SSH control masters
    for DEST_VM in "${SELECTED_VMS[@]}"; do
        DEST_USER=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "username")
        DEST_IP=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "ip")
        DEST_PORT=$(get_server_info "$DEST_DATACENTER" "$DEST_VM" "port")
        
        echo -en "  ${GRAY}Closing connection to${RESET} ${LIGHT_CYAN}${DEST_VM}${RESET} "
        if ssh $SSH_OPTS -p $DEST_PORT -O exit $DEST_USER@$DEST_IP &>/dev/null; then
            echo -e "${GREEN}✓${RESET}"
        else
            echo -e "${YELLOW}!${RESET}"
        fi
    done
    
    # Remove pattern file
    echo -en "  ${GRAY}Removing temporary files${RESET} "
    if rm -f "$PATTERN_FILE" &>/dev/null; then
        echo -e "${GREEN}✓${RESET}"
    else
        echo -e "${YELLOW}!${RESET}"
    fi
    
    echo -e "${DARK_GRAY}------------------------------------------${RESET}"
    log "Cleanup completed" true "success"
}
trap cleanup EXIT

# Function to display progress
show_progress() {
    # No complex progress bar, just colorize the output
    echo -e "${CYAN}$1${RESET}"
}

# Function to sync a VM
sync_vm() {
    local VM=$1
    
    # Create a VM-specific log file for capturing non-progress output
    local VM_LOG_FILE="/tmp/sync_${VM}_$.log"
    
    # Print header to console
    echo -e "\n${LIGHT_CYAN}${BOLD}● PROCESSING ${VM} ${RESET}"
    echo -e "${DARK_GRAY}------------------------------------------${RESET}"
    
    # Set connection parameters for current VM
    DEST_USER=$(get_server_info "$DEST_DATACENTER" "$VM" "username")
    DEST_HOST=$(get_server_info "$DEST_DATACENTER" "$VM" "host")
    DEST_IP=$(get_server_info "$DEST_DATACENTER" "$VM" "ip")
    DEST_PORT=$(get_server_info "$DEST_DATACENTER" "$VM" "port")

    # Extract VM number for source directory
    VM_NUMBER=$(echo "$VM" | sed -E 's/^cr([0-9]+).*/\1/')
    SOURCE_PATH="$HOME/1111-binance-services/cr$VM_NUMBER"
    DEST_PATH="/home/$DEST_USER"

    echo -e "  ${GRAY}VM:${RESET}        ${LIGHT_CYAN}${VM}${RESET} ${DARK_GRAY}(${DEST_HOST})${RESET}"
    echo -e "  ${GRAY}Source:${RESET}     ${LIGHT_CYAN}${SOURCE_PATH}${RESET}"
    echo -e "  ${GRAY}Destination:${RESET} ${LIGHT_CYAN}${DEST_PATH}${RESET}"

    # Check if the connection is working (log to file only if successful)
    if ! ssh $SSH_OPTS -p $DEST_PORT $DEST_USER@$DEST_IP "echo Connection successful" &>/dev/null; then
        echo -e "  ${RED}ERROR: Cannot connect to ${VM}${RESET}"
        echo -e "${DARK_GRAY}------------------------------------------${RESET}"
        echo -e "${RED}${BOLD}✗ FAILED ${VM} ${RESET}"
        log "ERROR: Cannot connect to $VM, skipping this VM" true "error"
        return 1
    fi
    log "Connection to $VM successful" false
    
    # Check if source directory exists
    if [ ! -d "$SOURCE_PATH" ]; then
        echo -e "  ${RED}ERROR: Source directory ${SOURCE_PATH} does not exist${RESET}"
        echo -e "${DARK_GRAY}------------------------------------------${RESET}"
        echo -e "${RED}${BOLD}✗ FAILED ${VM} ${RESET}"
        log "ERROR: Source directory $SOURCE_PATH does not exist, skipping this VM" true "error"
        return 1
    fi

    # Ensure destination directory exists
    ssh $SSH_OPTS -p $DEST_PORT $DEST_USER@$DEST_IP "mkdir -p $DEST_PATH" &>> "$VM_LOG_FILE"

    # Perform transfer - display progress directly to console
    echo -e "  ${GRAY}Starting transfer...${RESET}"
    echo -e "${DARK_GRAY}------------------------------------------${RESET}"
    
    # Run rsync with basic output formatting
    if rsync -az --progress --info=progress2 --include-from="$PATTERN_FILE" -e "ssh $SSH_OPTS -p $DEST_PORT" "$SOURCE_PATH/" "$DEST_USER@$DEST_IP:$DEST_PATH/" | 
        while IFS= read -r line; do
            if [[ "$line" == *"%"* ]]; then
                # Line with percentage - highlight it
                echo -e "    ${CYAN}$line${RESET}"
            else
                # Regular line - just indent it
                echo "    $line"
            fi
        done; then
        echo -e "${DARK_GRAY}------------------------------------------${RESET}"
        echo -e "${GREEN}${BOLD}✓ COMPLETED ${VM} ${RESET}"
        log "Transfer to $VM completed successfully" true "success"
        
        # Append non-progress logs to main log
        cat "$VM_LOG_FILE" >> "$LOG_FILE"
        rm -f "$VM_LOG_FILE"
        return 0
    else
        echo -e "${DARK_GRAY}------------------------------------------${RESET}"
        echo -e "${RED}${BOLD}✗ FAILED ${VM} ${RESET}"
        log "ERROR: Transfer to $VM failed" true "error"
        
        # Append non-progress logs to main log
        cat "$VM_LOG_FILE" >> "$LOG_FILE"
        rm -f "$VM_LOG_FILE"
        return 1
    fi
}

# Process VMs in parallel with job control
echo
echo -e "${LIGHT_CYAN}${BOLD}STARTING TRANSFERS${RESET}"
echo -e "${DARK_GRAY}------------------------------------------${RESET}"
echo -e "  ${GRAY}Max parallel jobs:${RESET} ${LIGHT_CYAN}${MAX_PARALLEL_JOBS}${RESET}"
echo -e "${DARK_GRAY}------------------------------------------${RESET}"
log "Starting parallel transfers (max $MAX_PARALLEL_JOBS concurrent jobs)..." true "info"

for DEST_VM in "${SELECTED_VMS[@]}"; do
    # Wait if we've reached max parallel jobs
    wait_for_jobs
    
    # Start a background job for this VM
    sync_vm "$DEST_VM" &
    
    # Increment running jobs counter
    ((RUNNING_JOBS++))
    log "Started sync job for $DEST_VM (running jobs: $RUNNING_JOBS)" true "info"
done

# Wait for all remaining jobs to complete
echo
log "Waiting for all transfers to complete..." true "info"
wait

echo
echo -e "${LIGHT_CYAN}${BOLD}===========================================${RESET}"
echo -e "${GREEN}${BOLD}          ALL TRANSFERS COMPLETED          ${RESET}"
echo -e "${LIGHT_CYAN}${BOLD}===========================================${RESET}"
log "All transfers completed" true "success"