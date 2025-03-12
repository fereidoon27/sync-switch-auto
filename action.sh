#!/bin/bash

# Log file setup
ACTION_LOG="$HOME/service_actions_$(date +%Y%m%d).log"

# Set directory paths
INFO_PATH="$(dirname "$0")/Info"
DEPLOYMENT_SCRIPTS_PATH="$(dirname "$0")/deployment_scripts"
SERVERS_CONF="$INFO_PATH/servers.conf"

# SSH connection optimization
SSH_CONTROL_PATH="/tmp/ssh_mux_%h_%p_%r"
SSH_MUX_OPTS="-o ControlMaster=auto -o ControlPath=$SSH_CONTROL_PATH -o ControlPersist=1h"
SSH_OPTS="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=15 $SSH_MUX_OPTS"

# Temporary dir for remote scripts
REMOTE_TMP_DIR="/tmp/deployment_scripts"

# Available services
SERVICES=("binance" "kucoin" "gateio")

# Default values
SOURCE_DATACENTER=""
DEST_DATACENTER=""
SOURCE_VM_INPUT=""
DEST_VM_INPUT=""
MAX_PARALLEL_JOBS=1
SELECTED_SERVICES=()
NON_INTERACTIVE=false
VERBOSE=false

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# UI elements
HEADER_BG="${BLUE}${BOLD}"
OPTION_COLOR="${CYAN}"
SELECTED_COLOR="${GREEN}"
ERROR_COLOR="${RED}${BOLD}"
SUCCESS_COLOR="${GREEN}${BOLD}"
HIGHLIGHT="${YELLOW}${BOLD}"
INFO_COLOR="${MAGENTA}"

# Parse command-line arguments
usage() {
    echo -e "${HEADER_BG}Usage:${NC} $0 [OPTIONS]"
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${OPTION_COLOR}-s${NC} SOURCE_DC     Source datacenter name"
    echo -e "  ${OPTION_COLOR}-d${NC} DEST_DC       Destination datacenter name"
    echo -e "  ${OPTION_COLOR}-v${NC} SRC_VMS       Source VM numbers (comma-separated, e.g., '3,4,5' or 'all')"
    echo -e "  ${OPTION_COLOR}-D${NC} DEST_VMS      Destination VM numbers (comma-separated, e.g., '1,2,6')"
    echo -e "  ${OPTION_COLOR}-p${NC} PARALLEL      Maximum parallel jobs (default: 1)"
    echo -e "  ${OPTION_COLOR}-r${NC} SERVICES      Services to migrate (comma-separated, e.g., 'binance,kucoin')"
    echo -e "  ${OPTION_COLOR}-y${NC}               Non-interactive mode (skip confirmation prompts)"
    echo -e "  ${OPTION_COLOR}-V${NC}               Verbose mode"
    echo -e "  ${OPTION_COLOR}-h${NC}               Display this help message"
    echo
    echo -e "${BOLD}Example:${NC} $0 -s arvan -d cloudzy -v 3,4,5 -D 1,2,6 -p 3 -r binance,kucoin -y"
    exit 1
}

while getopts "s:d:v:D:p:r:yVh" opt; do
    case $opt in
        s)
            SOURCE_DATACENTER="$OPTARG"
            ;;
        d)
            DEST_DATACENTER="$OPTARG"
            ;;
        v)
            SOURCE_VM_INPUT="$OPTARG"
            ;;
        D)
            DEST_VM_INPUT="$OPTARG"
            ;;
        p)
            MAX_PARALLEL_JOBS="$OPTARG"
            ;;
        r)
            IFS=',' read -ra SELECTED_SERVICES <<< "$OPTARG"
            ;;
        y)
            NON_INTERACTIVE=true
            ;;
        V)
            VERBOSE=true
            ;;
        h|*)
            usage
            ;;
    esac
done

# Function for drawing boxes
draw_box() {
    local title="$1"
    local width=80
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo -e "${HEADER_BG}"
    printf '╭%s╮\n' "$(printf '═%.0s' $(seq 1 $((width-2))))"
    printf '│%-*s%s%*s│\n' "$padding" " " "$title" "$((width - padding - ${#title}))" " "
    printf '╰%s╯\n' "$(printf '═%.0s' $(seq 1 $((width-2))))"
    echo -e "${NC}"
}

# Function for logging
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local action=$1
    local server=$2
    local status=$3
    local action_name=$4
    local task_desc=$5
    local job_num=${6:-""}
    
    # Use a fixed-width template format for perfect alignment
    if [[ -n "$status" ]]; then
        local icon="   "
        if [[ "$status" == "Started" ]]; then
            icon="──▶"
        elif [[ "$status" == "Completed" ]]; then
            icon="✅ "
        elif [[ "$status" == "Failed" ]]; then
            icon="❌ "
        fi
        
        # Truncate or pad strings to exact lengths for perfect alignment
        local action_str=$(printf "%-12.12s" "$action")
        local action_name_str=$(printf "%-30.30s" "$action_name")
        local task_desc_str=$(printf "%-30.30s" "$task_desc")
        local server_str=$(printf "%-20.20s" "$server")
        local job_str=""
        
        if [[ -n "$job_num" ]]; then
            job_str="| Job $job_num"
        fi
        
        # Create the log message with exact spacing and alignment
        printf "[%s] %s [Action %s] | %-30s | Server: %-20s | STATUS: %-10s %s\n" \
            "$timestamp" "$icon" "$action_str" "$task_desc_str" "$server_str" "$status" "$job_str" | tee -a "$ACTION_LOG"
    else
        # Simple log line for messages without structured format
        echo "[$timestamp] $1" | tee -a "$ACTION_LOG"
    fi
}

# Log section headers
log_header() {
    local header_text=$1
    local header_width=60
    local line=$(printf '%*s' "$header_width" | tr ' ' '-')
    local header=$(printf "|%*s%s%*s|" $(( (header_width - 2 - ${#header_text}) / 2 )) "" "$header_text" $(( (header_width - 2 - ${#header_text} + 1) / 2 )) "")
    
    echo "" | tee -a "$ACTION_LOG"
    echo "$line" | tee -a "$ACTION_LOG"
    echo "$header" | tee -a "$ACTION_LOG"
    echo "$line" | tee -a "$ACTION_LOG"
    echo "" | tee -a "$ACTION_LOG"
}

# Function to parse servers configuration
parse_servers_config() {
    if [ ! -f "$SERVERS_CONF" ]; then
        echo -e "${ERROR_COLOR}ERROR: Servers configuration file not found at $SERVERS_CONF${NC}"
        exit 1
    fi
    
    # Extract unique datacenters
    DATACENTERS=($(awk -F'|' '{print $1}' "$SERVERS_CONF" | sort | uniq))
}

# Function to get VM names for a specific datacenter
get_datacenter_vms() {
    local datacenter=$1
    awk -F'|' -v dc="$datacenter" '$1 == dc {print $2}' "$SERVERS_CONF"
}

# Function to get server details
get_server_details() {
    local datacenter=$1
    local vm_name=$2
    
    local details=$(awk -F'|' -v dc="$datacenter" -v vm="$vm_name" '$1 == dc && $2 == vm {print $0}' "$SERVERS_CONF")
    
    if [ -z "$details" ]; then
        log "ERROR: No details found for $datacenter $vm_name"
        return 1
    fi
    
    # Split details into array
    IFS='|' read -r DATACENTER VM_NAME IP HOST USERNAME PORT <<< "$details"
    return 0
}

# Function to establish SSH connection (open multiplexed connection)
setup_ssh_connection() {
    local user=$1
    local host=$2
    local port=$3
    local vm_name=$4
    
    # Check if connection is already established
    ssh -O check $SSH_MUX_OPTS -p $port $user@$host 2>/dev/null
    if [ $? -ne 0 ]; then
        log "Setting up SSH connection" "$vm_name" "Started" "SSH Connection" "Establishing SSH connection" "$job_number"
        # Create a background connection that will persist
        ssh $SSH_OPTS -p $port -M -f -N $user@$host
        if [ $? -ne 0 ]; then
            log "Setting up SSH connection" "$vm_name" "Failed" "SSH Connection" "Establishing SSH connection" "$job_number"
            return 1
        fi
        log "Setting up SSH connection" "$vm_name" "Completed" "SSH Connection" "Establishing SSH connection" "$job_number"
    fi
    return 0
}

# Function to close SSH connection
close_ssh_connection() {
    local user=$1
    local host=$2
    local port=$3
    local vm_name=$4
    
    log "Closing SSH connection" "$vm_name" "Started" "SSH Connection" "Closing SSH connection" "$job_number"
    ssh -O exit $SSH_MUX_OPTS -p $port $user@$host 2>/dev/null
    log "Closing SSH connection" "$vm_name" "Completed" "SSH Connection" "Closing SSH connection" "$job_number"
}

# Function to copy specific deployment scripts based on selected services
copy_deployment_scripts() {
    local user=$1
    local host=$2
    local port=$3
    local vm_name=$4
    local services=("${@:5}")
    local job_number=${services[-1]}  # Last element is job number
    unset 'services[-1]'            # Remove job number from services array
    
    # Create remote tmp directory in one shot
    ssh $SSH_OPTS -p $port $user@$host "mkdir -p $REMOTE_TMP_DIR"
    if [ $? -ne 0 ]; then
        log "Create remote directory" "$vm_name" "Failed" "Copy Scripts" "Creating remote directory" "$job_number"
        return 1
    fi
    
    # Copy only the specific service scripts (faster than copying all scripts)
    log "Copying deployment scripts" "$vm_name" "Started" "Copy Scripts" "Copy Scripts for ${services[*]}" "$job_number"
    
    # Process each selected service
    for service in "${services[@]}"; do
        # Check if the service scripts exist
        if [ ! -f "$DEPLOYMENT_SCRIPTS_PATH/deploy_all_${service}.sh" ] || \
           [ ! -f "$DEPLOYMENT_SCRIPTS_PATH/start_all_${service}.sh" ] || \
           [ ! -f "$DEPLOYMENT_SCRIPTS_PATH/stop_all_${service}.sh" ] || \
           [ ! -f "$DEPLOYMENT_SCRIPTS_PATH/purge_all_${service}.sh" ]; then
            log "Missing required scripts" "$vm_name" "Failed" "Copy Scripts" "Missing scripts for service $service" "$job_number"
            return 1
        fi
        
        # Copy service-specific scripts one by one
        scp $SSH_OPTS -P $port "$DEPLOYMENT_SCRIPTS_PATH/deploy_all_${service}.sh" "$user@$host:$REMOTE_TMP_DIR/"
        if [ $? -ne 0 ]; then
            log "Copy deploy script" "$vm_name" "Failed" "Copy Scripts" "copy deploy_all_${service}.sh" "$job_number"
            return 1
        fi
        
        scp $SSH_OPTS -P $port "$DEPLOYMENT_SCRIPTS_PATH/start_all_${service}.sh" "$user@$host:$REMOTE_TMP_DIR/"
        if [ $? -ne 0 ]; then
            log "Copy start script" "$vm_name" "Failed" "Copy Scripts" "copy start_all_${service}.sh" "$job_number"
            return 1
        fi
        
        scp $SSH_OPTS -P $port "$DEPLOYMENT_SCRIPTS_PATH/stop_all_${service}.sh" "$user@$host:$REMOTE_TMP_DIR/"
        if [ $? -ne 0 ]; then
            log "Copy stop script" "$vm_name" "Failed" "Copy Scripts" "copy stop_all_${service}.sh" "$job_number"
            return 1
        fi
        
        scp $SSH_OPTS -P $port "$DEPLOYMENT_SCRIPTS_PATH/purge_all_${service}.sh" "$user@$host:$REMOTE_TMP_DIR/"
        if [ $? -ne 0 ]; then
            log "Copy purge script" "$vm_name" "Failed" "Copy Scripts" "copy purge_all_${service}.sh" "$job_number"
            return 1
        fi
    done
    
    # Make scripts executable
    ssh $SSH_OPTS -p $port $user@$host "chmod +x $REMOTE_TMP_DIR/*.sh"
    if [ $? -ne 0 ]; then
        log "Make scripts executable" "$vm_name" "Failed" "Copy Scripts" "Making scripts executable" "$job_number"
        return 1
    fi
    
    log "Copying deployment scripts" "$vm_name" "Completed" "Copy Scripts" "Copy Scripts for ${services[*]}" "$job_number"
    return 0
}

# Function to execute action with service-specific script
execute_action() {
    local action_num=$1
    local user=$2
    local host=$3
    local port=$4
    local target_path=$5
    local vm_name=$6
    local service=$7
    local job_number=$8
    
    case $action_num in
        1)
            action_script="deploy_all_${service}.sh"
            action_name="Deploy ${service^} Service"
            ;;
        2)
            action_script="start_all_${service}.sh"
            action_name="Start ${service^} Service"
            ;;
        3)
            action_script="stop_all_${service}.sh"
            action_name="Stop ${service^} Service"
            ;;
        4)
            action_script="purge_all_${service}.sh"
            action_name="Purge ${service^} Service"
            ;;
        *)
            log "ERROR: Invalid action number: $action_num" "" "" "" "" "$job_number"
            return 1
            ;;
    esac
    
    log "$action_num" "$vm_name" "Started" "$action_name" "$action_name" "$job_number"
    
    # Execute the script on the remote machine (reusing connection)
    ssh $SSH_OPTS -p $port $user@$host "cd $target_path && $REMOTE_TMP_DIR/$action_script"
    local result=$?
    
    if [ $result -eq 0 ]; then
        log "$action_num" "$vm_name" "Completed" "$action_name" "$action_name" "$job_number"
    else
        log "$action_num" "$vm_name" "Failed" "$action_name" "$action_name" "$job_number"
        echo -e "${ERROR_COLOR}ERROR: Action $action_num ($action_name) failed on $vm_name${NC}"
        return 1
    fi
}

# Process a single migration job
process_migration_job() {
    local job_number=$1
    local source_datacenter=$2
    local dest_datacenter=$3
    local source_vm_index=$4
    local dest_vm_index=$5
    local services=("${@:6:${#SELECTED_SERVICES[@]}}")
    local source_vms=("${@:6+${#SELECTED_SERVICES[@]}}")
    
    # Log job header
    log_header "Service Transfer Operation - Job $job_number"
    
    # Get the source VM name
    SOURCE_VM=${source_vms[$source_vm_index]}
    
    # Get source VM details
    if ! get_server_details "$source_datacenter" "$SOURCE_VM"; then
        log "ERROR: Failed to get details for source VM $SOURCE_VM in $source_datacenter" "" "" "" "" "$job_number"
        return 1
    fi
    
    SOURCE_USER=$USERNAME
    SOURCE_IP=$IP
    SOURCE_HOST=$HOST
    SOURCE_PORT=$PORT
    SOURCE_PATH="/home/$USERNAME/"
    
    # Get the destination VM name from DEST_VMS array
    DEST_VM=${DEST_VMS[$dest_vm_index]}
    
    # Get destination VM details
    if ! get_server_details "$dest_datacenter" "$DEST_VM"; then
        log "ERROR: Failed to get details for destination VM $DEST_VM in $dest_datacenter" "" "" "" "" "$job_number"
        return 1
    fi
    
    DEST_USER=$USERNAME
    DEST_IP=$IP
    DEST_HOST=$HOST
    DEST_PORT=$PORT
    DEST_PATH="/home/$USERNAME/"
    
    echo -e "\n${HEADER_BG}Job #$job_number Configuration:${NC}"
    echo -e "${INFO_COLOR}Source:${NC} $source_datacenter - $SOURCE_VM ($SOURCE_HOST)"
    echo -e "${INFO_COLOR}Destination:${NC} $dest_datacenter - $DEST_VM ($DEST_HOST)"
    echo -e "${INFO_COLOR}Services:${NC} ${services[*]}"
    
    # Setup SSH connections once for both source and destination
    setup_ssh_connection "$SOURCE_USER" "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_VM"
    setup_ssh_connection "$DEST_USER" "$DEST_HOST" "$DEST_PORT" "$DEST_VM"
    
    # Add job number to services array for logging
    local services_with_job=("${services[@]}" "$job_number")
    
    # Copy deployment scripts for all selected services to both servers
    copy_deployment_scripts "$SOURCE_USER" "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_VM" "${services_with_job[@]}"
    copy_deployment_scripts "$DEST_USER" "$DEST_HOST" "$DEST_PORT" "$DEST_VM" "${services_with_job[@]}"
    
    # Process each service
    local all_success=true
    for service in "${services[@]}"; do
        echo -e "\n${HIGHLIGHT}Processing service: ${service^}${NC}"
        
        # Execute actions on destination VM (deploy and start)
        echo -e "${INFO_COLOR}Executing actions on Destination VM ($DEST_VM)...${NC}"
        local dest_success=true
        for action in 1 2; do
            echo -e "  ➤ Executing step $action on Destination VM (${service^} service)"
            if ! execute_action $action "$DEST_USER" "$DEST_HOST" "$DEST_PORT" "$DEST_PATH" "$DEST_VM" "$service" "$job_number"; then
                echo -e "${ERROR_COLOR}  ✗ Sequence failed at step $action on Destination VM${NC}"
                dest_success=false
                all_success=false
                break
            else
                echo -e "${SUCCESS_COLOR}  ✓ Step $action completed successfully${NC}"
            fi
        done
        
        # Only continue to source VM actions if destination was successful
        if $dest_success; then
            # 5-second pause between destination and source actions
            echo -e "${INFO_COLOR}Pausing for 5 seconds before proceeding to source VM actions...${NC}"
            sleep 5
            
            # Execute actions on source VM (stop and purge)
            echo -e "${INFO_COLOR}Executing actions on Source VM ($SOURCE_VM)...${NC}"
            for action in 3 4; do
                echo -e "  ➤ Executing step $action on Source VM (${service^} service)"
                if ! execute_action $action "$SOURCE_USER" "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_PATH" "$SOURCE_VM" "$service" "$job_number"; then
                    echo -e "${ERROR_COLOR}  ✗ Sequence failed at step $action on Source VM${NC}"
                    all_success=false
                    break
                else
                    echo -e "${SUCCESS_COLOR}  ✓ Step $action completed successfully${NC}"
                fi
            done
        fi
    done
    
    # Close SSH connections
    close_ssh_connection "$SOURCE_USER" "$SOURCE_HOST" "$SOURCE_PORT" "$SOURCE_VM"
    close_ssh_connection "$DEST_USER" "$DEST_HOST" "$DEST_PORT" "$DEST_VM"
    
    if $all_success; then
        echo -e "\n${SUCCESS_COLOR}Job #$job_number completed successfully!${NC}\n"
        return 0
    else
        echo -e "\n${ERROR_COLOR}Job #$job_number failed!${NC}\n"
        return 1
    fi
}

# Process multiple migration jobs in parallel
process_parallel_jobs() {
    local source_datacenter=$1
    local dest_datacenter=$2
    local source_vm_choices=$3
    local dest_vm_choices=$4
    local max_parallel_jobs=${MAX_PARALLEL_JOBS:-1}
    
    local active_jobs=0
    local job_pids=()
    local job_numbers=()
    
    for (( i=0; i<${#source_vm_choices}; i++ )); do
        local src_choice=${source_vm_choices:$i:1}
        local dst_choice=${dest_vm_choices:$i:1}
        local src_vm_index=$((src_choice-1))
        local dst_vm_index=$((dst_choice-1))
        local job_number=$((i+1))
        
        echo -e "\n${HEADER_BG}╭───────────────────────────────────────────────────────────╮${NC}"
        echo -e "${HEADER_BG}│           Starting Migration Job #$job_number                       │${NC}"
        echo -e "${HEADER_BG}╰───────────────────────────────────────────────────────────╯${NC}"
        echo -e "${HIGHLIGHT}Source VM:${NC} ${SOURCE_VMS[$src_vm_index]}"
        echo -e "${HIGHLIGHT}Destination VM:${NC} ${DEST_VMS[$dst_vm_index]}"
        echo -e "${HIGHLIGHT}Services:${NC} ${SELECTED_SERVICES[*]^}"
        
        # Run the job in background
        (process_migration_job "$job_number" "$source_datacenter" "$dest_datacenter" "$src_vm_index" "$dst_vm_index" "${SELECTED_SERVICES[@]}" "${SOURCE_VMS[@]}") &
        local pid=$!
        job_pids+=($pid)
        job_numbers+=($job_number)
        active_jobs=$((active_jobs+1))
        
        # Wait if we've reached the maximum number of parallel jobs
        if [[ $active_jobs -ge $max_parallel_jobs ]]; then
            echo -e "${INFO_COLOR}Waiting for a job to complete before starting more...${NC}"
            # Wait for any job to finish
            wait -n
            
            # Update active jobs count
            for (( j=0; j<${#job_pids[@]}; j++ )); do
                if ! kill -0 ${job_pids[$j]} 2>/dev/null; then
                    # Check if job was successful
                    wait ${job_pids[$j]}
                    local status=$?
                    
                    if [[ $status -ne 0 ]]; then
                        echo -e "${ERROR_COLOR}Migration job #${job_numbers[$j]} failed!${NC}"
                        log "Migration job #${job_numbers[$j]} failed!" "" "" "" "" "$job_number"
                        
                        if [[ "$NON_INTERACTIVE" == "false" ]]; then
                            read -p "$(echo -e ${BOLD}Continue with remaining jobs? \(y/n\): ${NC})" continue_choice
                            if [[ $continue_choice != "y" && $continue_choice != "Y" ]]; then
                                log "Operation cancelled by user after job #${job_numbers[$j]} failure" "" "" "" "" "$job_number"
                                
                                # Kill all remaining jobs
                                for pid in "${job_pids[@]}"; do
                                    kill $pid 2>/dev/null
                                done
                                
                                return 1
                            fi
                        else
                            # In non-interactive mode, continue by default
                            log "Continuing with remaining jobs after failure (non-interactive mode)" "" "" "" "" "$job_number"
                        fi
                    fi
                    
                    # Remove this job from tracking arrays
                    unset job_pids[$j]
                    unset job_numbers[$j]
                    job_pids=("${job_pids[@]}")
                    job_numbers=("${job_numbers[@]}")
                    
                    active_jobs=$((active_jobs-1))
                    break
                fi
            done
        fi
    done
    
    if [[ $active_jobs -gt 0 ]]; then
        echo -e "${INFO_COLOR}Waiting for remaining jobs to complete...${NC}"
    fi
    
    # Wait for all remaining jobs to finish
    for (( j=0; j<${#job_pids[@]}; j++ )); do
        wait ${job_pids[$j]}
        local status=$?
        
        if [[ $status -ne 0 ]]; then
            echo -e "${ERROR_COLOR}Migration job #${job_numbers[$j]} failed!${NC}"
            log "Migration job #${job_numbers[$j]} failed!" "" "" "" "" ""
        fi
    done
    
    return 0
}

# Validate datacenter name
validate_datacenter() {
    local dc_name=$1
    local valid=false
    
    for dc in "${DATACENTERS[@]}"; do
        if [[ "$dc" == "$dc_name" ]]; then
            valid=true
            break
        fi
    done
    
    if [[ "$valid" == "false" ]]; then
        return 1
    fi
    return 0
}

# Validate service name
validate_service() {
    local service_name=$1
    local valid=false
    
    for service in "${SERVICES[@]}"; do
        if [[ "$service" == "$service_name" ]]; then
            valid=true
            break
        fi
    done
    
    if [[ "$valid" == "false" ]]; then
        return 1
    fi
    return 0
}

# Convert 'all' to a sequence of VM numbers
convert_all_vms() {
    local max_vm=$1
    local vm_choices=""
    
    for (( i=1; i<=$max_vm; i++ )); do
        vm_choices="${vm_choices}${i}"
    done
    
    echo "$vm_choices"
}

# Convert comma-separated VM list to digit string
parse_vm_args() {
    local input=$1
    local max_vm=$2
    local vm_choices=""
    
    # Handle 'all' option
    if [[ "$input" == "all" ]]; then
        for (( i=1; i<=$max_vm; i++ )); do
            vm_choices="${vm_choices}${i}"
        done
        echo "$vm_choices"
        return 0
    fi
    
    # Convert comma-separated list to string of digits
    IFS=',' read -ra VM_ARRAY <<< "$input"
    for vm in "${VM_ARRAY[@]}"; do
        # Validate each VM number
        if [[ ! $vm =~ ^[1-9][0-9]*$ ]] || [[ $vm -gt $max_vm ]]; then
            echo "error"
            return 1
        fi
        vm_choices="${vm_choices}${vm}"
    done
    
    echo "$vm_choices"
}

# Main script execution
main() {
    # Append to log file if it exists, create it if it doesn't
    if [ ! -f "$ACTION_LOG" ]; then
        touch "$ACTION_LOG"
        echo "# Service Migration Log - Started $(date)" >> "$ACTION_LOG"
        echo "# Format: Timestamp | Action | Task Description | Server | Status | Job" >> "$ACTION_LOG"
        echo "# --------------------------------------------------------------------" >> "$ACTION_LOG"
    else
        echo "" >> "$ACTION_LOG"
        echo "# New Migration Session - $(date)" >> "$ACTION_LOG"
        echo "# --------------------------------------------------------------------" >> "$ACTION_LOG"
    fi
    
    # Clear screen for better UI
    clear
    
    # Draw title banner
    echo -e "${HEADER_BG}"
    echo -e "╭────────────────────────────────────────────────────────────────────────────╮"
    echo -e "│                                                                            │"
    echo -e "│                    ADVANCED SERVICE MIGRATION TOOL                         │"
    echo -e "│                                                                            │"
    echo -e "╰────────────────────────────────────────────────────────────────────────────╯"
    echo -e "${NC}"
    
    # Parse servers configuration and get datacenters
    echo -e "${INFO_COLOR}Loading configuration...${NC}"
    parse_servers_config
    
    # Verify the required parameters for automated mode
    auto_mode_valid=true
    source_dc_index=-1
    dest_dc_index=-1
    source_vm_choices=""
    dest_vm_choices=""
    
    # Process SOURCE_DATACENTER
    if [[ -n "$SOURCE_DATACENTER" ]]; then
        if ! validate_datacenter "$SOURCE_DATACENTER"; then
            echo -e "${ERROR_COLOR}ERROR: Invalid source datacenter: $SOURCE_DATACENTER${NC}"
            echo -e "${INFO_COLOR}Available datacenters:${NC}"
            for dc in "${DATACENTERS[@]}"; do
                echo "  $dc"
            done
            auto_mode_valid=false
        else
            # Find the index of the source datacenter
            for i in "${!DATACENTERS[@]}"; do
                if [[ "${DATACENTERS[$i]}" == "$SOURCE_DATACENTER" ]]; then
                    source_dc_index=$i
                    break
                fi
            done
        fi
    else
        auto_mode_valid=false
    fi
    
    # Process DEST_DATACENTER
    if [[ -n "$DEST_DATACENTER" ]]; then
        if ! validate_datacenter "$DEST_DATACENTER"; then
            echo -e "${ERROR_COLOR}ERROR: Invalid destination datacenter: $DEST_DATACENTER${NC}"
            echo -e "${INFO_COLOR}Available datacenters:${NC}"
            for dc in "${DATACENTERS[@]}"; do
                echo "  $dc"
            done
            auto_mode_valid=false
        else
            # Find the index of the destination datacenter
            for i in "${!DATACENTERS[@]}"; do
                if [[ "${DATACENTERS[$i]}" == "$DEST_DATACENTER" ]]; then
                    dest_dc_index=$i
                    break
                fi
            done
        fi
    else
        auto_mode_valid=false
    fi
    
    # Get VMs for source and destination datacenters if we have valid datacenter selections
    if [[ $source_dc_index -ge 0 ]]; then
        SOURCE_VMS=($(get_datacenter_vms "$SOURCE_DATACENTER"))
    fi
    
    if [[ $dest_dc_index -ge 0 ]]; then
        DEST_VMS=($(get_datacenter_vms "$DEST_DATACENTER"))
    fi
    
    # Process SOURCE_VM_INPUT if provided
    if [[ -n "$SOURCE_VM_INPUT" && -n "$SOURCE_VMS" ]]; then
        # Parse comma-separated input or 'all'
        source_vm_choices=$(parse_vm_args "$SOURCE_VM_INPUT" "${#SOURCE_VMS[@]}")
        
        if [[ "$source_vm_choices" == "error" ]]; then
            echo -e "${ERROR_COLOR}ERROR: Invalid source VM format: $SOURCE_VM_INPUT${NC}"
            echo -e "${INFO_COLOR}Must be comma-separated numbers (e.g., '3,4,5') or 'all'${NC}"
            auto_mode_valid=false
        fi
    else
        auto_mode_valid=false
    fi
    
    # Process DEST_VM_INPUT if provided
    if [[ -n "$DEST_VM_INPUT" && -n "$DEST_VMS" && -n "$source_vm_choices" ]]; then
        # Parse comma-separated input
        dest_vm_choices=$(parse_vm_args "$DEST_VM_INPUT" "${#DEST_VMS[@]}")
        
        if [[ "$dest_vm_choices" == "error" ]]; then
            echo -e "${ERROR_COLOR}ERROR: Invalid destination VM format: $DEST_VM_INPUT${NC}"
            echo -e "${INFO_COLOR}Must be comma-separated numbers (e.g., '1,2,6')${NC}"
            auto_mode_valid=false
        else
            # Check if destination VM count matches source VM count
            if [[ ${#dest_vm_choices} -ne ${#source_vm_choices} ]]; then
                echo -e "${ERROR_COLOR}ERROR: Source and destination VM lists must have the same length${NC}"
                echo -e "${INFO_COLOR}Source VMs: ${#source_vm_choices} entries, Destination VMs: ${#dest_vm_choices} entries${NC}"
                auto_mode_valid=false
            fi
            
            # When source and destination datacenters are the same, check for overlapping VMs
            if [[ "$SOURCE_DATACENTER" == "$DEST_DATACENTER" ]]; then
                for (( i=0; i<${#source_vm_choices}; i++ )); do
                    local src_choice=${source_vm_choices:$i:1}
                    local dst_choice=${dest_vm_choices:$i:1}
                    
                    if [[ $src_choice -eq $dst_choice ]]; then
                        echo -e "${ERROR_COLOR}ERROR: Source and destination VMs cannot be the same when using the same datacenter${NC}"
                        echo -e "${INFO_COLOR}Problem detected: VM #$src_choice is used as both source and destination${NC}"
                        auto_mode_valid=false
                        break
                    fi
                done
            fi
        fi
    else
        auto_mode_valid=false
    fi
    
    # Process SELECTED_SERVICES
    if [[ ${#SELECTED_SERVICES[@]} -gt 0 ]]; then
        for service in "${SELECTED_SERVICES[@]}"; do
            if ! validate_service "$service"; then
                echo -e "${ERROR_COLOR}ERROR: Invalid service: $service${NC}"
                echo -e "${INFO_COLOR}Available services:${NC}"
                for svc in "${SERVICES[@]}"; do
                    echo "  $svc"
                done
                auto_mode_valid=false
                break
            fi
        done
        
        # If no services were specified, consider it invalid
        if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
            auto_mode_valid=false
        fi
    else
        auto_mode_valid=false
    fi
    
    # Validate MAX_PARALLEL_JOBS
    if [[ -n "$MAX_PARALLEL_JOBS" ]]; then
        if [[ ! $MAX_PARALLEL_JOBS =~ ^[1-9][0-9]*$ ]]; then
            echo -e "${ERROR_COLOR}ERROR: Invalid maximum parallel jobs: $MAX_PARALLEL_JOBS${NC}"
            echo -e "${INFO_COLOR}Must be a positive integer${NC}"
            MAX_PARALLEL_JOBS=1
            echo -e "${INFO_COLOR}Using default value: $MAX_PARALLEL_JOBS${NC}"
        fi
    else
        MAX_PARALLEL_JOBS=1
    fi
    
    # Interactive mode if not all parameters are valid or provided
    if [[ "$auto_mode_valid" == "false" ]]; then
        # Display datacenter options
        draw_box "DATACENTER SELECTION"
        echo -e "${HIGHLIGHT}Available Datacenters:${NC}"
        for i in "${!DATACENTERS[@]}"; do
            echo -e "  ${OPTION_COLOR}$((i+1)).${NC} ${DATACENTERS[i]}"
        done
        echo

        # Select source datacenter if not valid from command line
        if [[ $source_dc_index -lt 0 ]]; then
            while true; do
                read -p "$(echo -e ${BOLD}Select source datacenter \(1-${#DATACENTERS[@]}\): ${NC})" source_dc_choice
                if [[ $source_dc_choice =~ ^[1-${#DATACENTERS[@]}]$ ]]; then
                    SOURCE_DATACENTER=${DATACENTERS[$((source_dc_choice-1))]}
                    break
                else
                    echo -e "${ERROR_COLOR}Invalid choice. Please try again.${NC}"
                fi
            done
        else
            echo -e "${SELECTED_COLOR}Using source datacenter: $SOURCE_DATACENTER${NC}"
        fi

        # Select destination datacenter if not valid from command line
        if [[ $dest_dc_index -lt 0 ]]; then
            while true; do
                read -p "$(echo -e ${BOLD}Select destination datacenter \(1-${#DATACENTERS[@]}\): ${NC})" dest_dc_choice
                if [[ $dest_dc_choice =~ ^[1-${#DATACENTERS[@]}]$ ]]; then
                    DEST_DATACENTER=${DATACENTERS[$((dest_dc_choice-1))]}
                    # Ensure destination is different from source
                    if [ "$DEST_DATACENTER" != "$SOURCE_DATACENTER" ]; then
                        break
                    else
                        echo -e "${ERROR_COLOR}Destination datacenter must be different from source. Please try again.${NC}"
                    fi
                else
                    echo -e "${ERROR_COLOR}Invalid choice. Please try again.${NC}"
                fi
            done
        else
            echo -e "${SELECTED_COLOR}Using destination datacenter: $DEST_DATACENTER${NC}"
        fi

        # Get VMs for source datacenter
        SOURCE_VMS=($(get_datacenter_vms "$SOURCE_DATACENTER"))
        
        # Get VMs for destination datacenter
        DEST_VMS=($(get_datacenter_vms "$DEST_DATACENTER"))

        # Display source VM options with "all" option
        echo
        draw_box "VM SELECTION"
        echo -e "${HIGHLIGHT}Available Source VMs:${NC}"
        for i in "${!SOURCE_VMS[@]}"; do
            echo -e "  ${OPTION_COLOR}$((i+1)).${NC} ${SOURCE_VMS[i]}"
        done
        echo -e "  ${OPTION_COLOR}$((${#SOURCE_VMS[@]}+1)).${NC} all"
        echo

        # Select source VMs if not valid from command line
        if [[ -z "$source_vm_choices" ]]; then
            while true; do
                read -p "$(echo -e ${BOLD}Select source VMs \(comma-separated, e.g. 6,1,4 for VMs 6, 1, and 4, or 'all'\): ${NC})" source_vm_input
                
                # Check if user selected "all"
                if [[ $source_vm_input == "all" ]]; then
                    source_vm_choices=$(convert_all_vms "${#SOURCE_VMS[@]}")
                    break
                fi
                
                # Convert and validate comma-separated VM input
                source_vm_choices=$(parse_vm_args "$source_vm_input" "${#SOURCE_VMS[@]}")
                
                if [[ "$source_vm_choices" == "error" ]]; then
                    echo -e "${ERROR_COLOR}Invalid input. Please enter valid VM numbers (1-${#SOURCE_VMS[@]}).${NC}"
                    continue
                fi
                
                break
            done
        else
            echo -e "${SELECTED_COLOR}Using source VMs: $source_vm_choices${NC}"
        fi
        
        # Display destination VM options with "all" option
        echo
        echo -e "${HIGHLIGHT}Available Destination VMs:${NC}"
        for i in "${!DEST_VMS[@]}"; do
            echo -e "  ${OPTION_COLOR}$((i+1)).${NC} ${DEST_VMS[i]}"
        done
        echo
        
        # Select destination VMs
        if [[ -z "$dest_vm_choices" ]]; then
            while true; do
                read -p "$(echo -e ${BOLD}Select destination VMs \(comma-separated, e.g. 6,1,4 for VMs 6, 1, and 4\): ${NC})" dest_vm_input
                
                # Convert and validate comma-separated VM input
                dest_vm_choices=$(parse_vm_args "$dest_vm_input" "${#DEST_VMS[@]}")
                
                if [[ "$dest_vm_choices" == "error" ]]; then
                    echo -e "${ERROR_COLOR}Invalid input. Please enter valid VM numbers (1-${#DEST_VMS[@]}).${NC}"
                    continue
                fi
                
                # Check if destination VM count matches source VM count
                if [[ ${#dest_vm_choices} -ne ${#source_vm_choices} ]]; then
                    echo -e "${ERROR_COLOR}Error: The number of destination VMs must match the number of source VMs.${NC}"
                    echo -e "${INFO_COLOR}You selected ${#source_vm_choices} source VMs but ${#dest_vm_choices} destination VMs.${NC}"
                    continue
                fi
                
                # When source and destination datacenters are the same, check for overlapping VMs
                if [[ "$SOURCE_DATACENTER" == "$DEST_DATACENTER" ]]; then
                    local overlap_detected=false
                    for (( i=0; i<${#source_vm_choices}; i++ )); do
                        local src_choice=${source_vm_choices:$i:1}
                        local dst_choice=${dest_vm_choices:$i:1}
                        
                        if [[ $src_choice -eq $dst_choice ]]; then
                            echo -e "${ERROR_COLOR}Error: Source and destination VMs cannot be the same when using the same datacenter.${NC}"
                            echo -e "${INFO_COLOR}Problem detected: VM #$src_choice (${SOURCE_VMS[$((src_choice-1))]})"
                            overlap_detected=true
                            break
                        fi
                    done
                    
                    if [[ "$overlap_detected" == "true" ]]; then
                        continue
                    fi
                fi
                
                break
            done
        else
            echo -e "${SELECTED_COLOR}Using destination VMs: $dest_vm_choices${NC}"
        fi
        
        # Display service options if not provided
        echo
        draw_box "SERVICE SELECTION" 
        echo -e "${HIGHLIGHT}Available Services:${NC}"
        for i in "${!SERVICES[@]}"; do
            echo -e "  ${OPTION_COLOR}$((i+1)).${NC} ${SERVICES[i]}"
        done
        echo -e "  ${OPTION_COLOR}$((${#SERVICES[@]}+1)).${NC} all"
        echo
        
        # Select services
        if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
            while true; do
                read -p "$(echo -e ${BOLD}Select services \(digits without spaces, e.g. 12 for services 1 and 2, or select 'all'\): ${NC})" service_choice
                
                # Check if user selected "all"
                if [[ $service_choice =~ ^[aA][lL][lL]$ ]] || [[ $service_choice -eq $((${#SERVICES[@]}+1)) ]]; then
                    SELECTED_SERVICES=("${SERVICES[@]}")
                    break
                fi
                
                # Validate input - only digits allowed
                if [[ ! $service_choice =~ ^[1-9]+$ ]]; then
                    echo -e "${ERROR_COLOR}Invalid input. Please enter only digits corresponding to service numbers.${NC}"
                    continue
                fi
                
                # Validate and collect selected services
                SELECTED_SERVICES=()
                local invalid_choice=false
                for (( i=0; i<${#service_choice}; i++ )); do
                    local choice=${service_choice:$i:1}
                    if [[ $choice -gt ${#SERVICES[@]} ]]; then
                        echo -e "${ERROR_COLOR}Invalid choice: $choice. Maximum is ${#SERVICES[@]}.${NC}"
                        invalid_choice=true
                        break
                    fi
                    SELECTED_SERVICES+=("${SERVICES[$((choice-1))]}")
                done
                
                if [ "$invalid_choice" = true ]; then
                    continue
                fi
                
                break
            done
        else
            echo -e "${SELECTED_COLOR}Using services: ${SELECTED_SERVICES[*]}${NC}"
        fi
        
        # Ask for parallel job count
        echo
        draw_box "PARALLEL JOBS" 
        if [[ "$auto_mode_valid" == "false" ]]; then
            read -p "$(echo -e ${BOLD}Enter maximum number of parallel jobs [1]: ${NC})" MAX_PARALLEL_JOBS
            MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-1}  # Default to 1 if empty
            
            # Validate input for parallel jobs
            if [[ ! $MAX_PARALLEL_JOBS =~ ^[1-9][0-9]*$ ]]; then
                echo -e "${ERROR_COLOR}Invalid input. Using default value of 1 parallel job.${NC}"
                MAX_PARALLEL_JOBS=1
            fi
        else
            # For automated mode
            if [[ -z "$MAX_PARALLEL_JOBS" ]]; then
                MAX_PARALLEL_JOBS=1
            fi
            echo -e "${SELECTED_COLOR}Using maximum parallel jobs: $MAX_PARALLEL_JOBS${NC}"
        fi
    fi

    # Show configuration summary and get final approval
    echo
    draw_box "CONFIGURATION SUMMARY"
    echo -e "${HIGHLIGHT}Source datacenter:${NC} $SOURCE_DATACENTER"
    echo -e "${HIGHLIGHT}Destination datacenter:${NC} $DEST_DATACENTER"
    echo -e "${HIGHLIGHT}Maximum parallel jobs:${NC} $MAX_PARALLEL_JOBS"
    echo -e "${HIGHLIGHT}Selected services:${NC} ${SELECTED_SERVICES[*]^}"
    echo -e "\n${HIGHLIGHT}VM Mappings:${NC}"
    
    for (( i=0; i<${#source_vm_choices}; i++ )); do
        local src_choice=${source_vm_choices:$i:1}
        local dst_choice=${dest_vm_choices:$i:1}
        local src_vm_index=$((src_choice-1))
        local dst_vm_index=$((dst_choice-1))
        
        echo -e "  ${SOURCE_VMS[$src_vm_index]} ${CYAN}→${NC} ${DEST_VMS[$dst_vm_index]}"
    done
    
    # Get confirmation in interactive mode
    if [[ "$NON_INTERACTIVE" == "false" ]]; then
        echo
        read -p "$(echo -e ${BOLD}Continue? \(y/n\): ${NC})" confirm
        if [[ $confirm != "y" && $confirm != "Y" ]]; then
            log "Operation cancelled by user"
            echo -e "${INFO_COLOR}Operation cancelled by user${NC}"
            exit 0
        fi
    else
        echo -e "\n${INFO_COLOR}Running in non-interactive mode. Proceeding without confirmation...${NC}"
    fi

    # Process migration jobs in parallel
    echo
    draw_box "EXECUTING MIGRATION JOBS"
    echo -e "${INFO_COLOR}Starting migration process...${NC}"
    process_parallel_jobs "$SOURCE_DATACENTER" "$DEST_DATACENTER" "$source_vm_choices" "$dest_vm_choices"

    # Log completion
    log_header "All Service Transfer Operations Completed"
    
    echo
    draw_box "MIGRATION COMPLETED"
    echo -e "${SUCCESS_COLOR}All migration jobs completed!${NC}"
    echo -e "${INFO_COLOR}Action log: $ACTION_LOG${NC}"
}

# Run the main script
main