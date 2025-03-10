#!/bin/bash
# sc_3: Simple script to get action input (based on action.sh) and print the values

# Set script and configuration file paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="${SCRIPT_DIR}/Info"
SERVERS_CONF="${INFO_PATH}/servers.conf"

# Default values (as in action.sh)
SOURCE_DATACENTER=""
DEST_DATACENTER=""
SOURCE_VM_INPUT=""
MAX_PARALLEL_JOBS=2
SELECTED_SERVICE=""
NON_INTERACTIVE=false
VERBOSE=false

# Available services (as in action.sh)
SERVICES=("binance" "kucoin" "gateio")

# Function: get_action_input
# Prompts the user for required inputs and stores them in global variables.
get_action_input() {
    # Ensure servers.conf exists
    if [ ! -f "$SERVERS_CONF" ]; then
        echo "ERROR: servers.conf not found at $SERVERS_CONF"
        exit 1
    fi

    # Get unique datacenters from servers.conf
    mapfile -t DATACENTERS < <(awk -F'|' '$1 != "" {print $1}' "$SERVERS_CONF" | sort -u)
    
    echo "Available Datacenters:"
    for i in "${!DATACENTERS[@]}"; do
        echo "$((i+1)). ${DATACENTERS[$i]}"
    done

    # Prompt for SOURCE_DATACENTER
    while true; do
        read -p "Select source datacenter (1-${#DATACENTERS[@]}): " src_choice
        if [[ "$src_choice" =~ ^[0-9]+$ ]] && [ "$src_choice" -ge 1 ] && [ "$src_choice" -le "${#DATACENTERS[@]}" ]; then
            SOURCE_DATACENTER="${DATACENTERS[$((src_choice-1))]}"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
    echo "Selected Source Datacenter: $SOURCE_DATACENTER"
    
    # Prompt for DEST_DATACENTER (must be different from source)
    while true; do
        read -p "Select destination datacenter (1-${#DATACENTERS[@]}): " dst_choice
        if [[ "$dst_choice" =~ ^[0-9]+$ ]] && [ "$dst_choice" -ge 1 ] && [ "$dst_choice" -le "${#DATACENTERS[@]}" ]; then
            DEST_DATACENTER="${DATACENTERS[$((dst_choice-1))]}"
            if [ "$DEST_DATACENTER" = "$SOURCE_DATACENTER" ]; then
                echo "Destination must differ from source. Please choose again."
            else
                break
            fi
        else
            echo "Invalid selection. Please try again."
        fi
    done
    echo "Selected Destination Datacenter: $DEST_DATACENTER"

    # Get source VMs for SOURCE_DATACENTER (from field 2)
    mapfile -t SOURCE_VMS < <(awk -F'|' -v dc="$SOURCE_DATACENTER" '$1 == dc {print $2}' "$SERVERS_CONF")
    if [ ${#SOURCE_VMS[@]} -eq 0 ]; then
        echo "No VMs found for source datacenter $SOURCE_DATACENTER."
        exit 1
    fi

    echo "Available Source VMs in $SOURCE_DATACENTER:"
    for i in "${!SOURCE_VMS[@]}"; do
        echo "$((i+1)). ${SOURCE_VMS[$i]}"
    done
    echo "$(( ${#SOURCE_VMS[@]}+1 )). all (select all VMs)"
    
    # Prompt for SOURCE_VM_INPUT (accept digits string or "all")
    read -p "Select source VMs (enter digits without spaces, e.g. '614' for VMs 6,1,4, or 'all'): " input_vm
    if [ "$input_vm" = "all" ] || [ "$input_vm" = "$(( ${#SOURCE_VMS[@]}+1 ))" ]; then
        SOURCE_VM_INPUT="all"
    else
        valid=true
        for (( i=0; i<${#input_vm}; i++ )); do
            digit="${input_vm:$i:1}"
            if ! [[ "$digit" =~ ^[0-9]+$ ]] || [ "$digit" -lt 1 ] || [ "$digit" -gt "${#SOURCE_VMS[@]}" ]; then
                echo "Warning: Invalid VM number: $digit"
                valid=false
                break
            fi
        done
        if [ "$valid" = true ]; then
            SOURCE_VM_INPUT="$input_vm"
        else
            echo "No valid VMs selected. Exiting."
            exit 1
        fi
    fi
    echo "Selected Source VMs: $SOURCE_VM_INPUT"

    # Prompt for MAX_PARALLEL_JOBS
    read -p "Enter maximum parallel jobs [default $MAX_PARALLEL_JOBS]: " jobs_input
    if [[ -n "$jobs_input" ]]; then
        if [[ "$jobs_input" =~ ^[1-9][0-9]*$ ]]; then
            MAX_PARALLEL_JOBS="$jobs_input"
        else
            echo "Invalid number. Using default: $MAX_PARALLEL_JOBS"
        fi
    fi
    echo "Max Parallel Jobs: $MAX_PARALLEL_JOBS"

    # Prompt for SELECTED_SERVICE from available SERVICES
    echo "Available Services:"
    for i in "${!SERVICES[@]}"; do
        echo "$((i+1)). ${SERVICES[$i]}"
    done
    while true; do
        read -p "Select service (1-${#SERVICES[@]}): " svc_choice
        if [[ "$svc_choice" =~ ^[0-9]+$ ]] && [ "$svc_choice" -ge 1 ] && [ "$svc_choice" -le "${#SERVICES[@]}" ]; then
            SELECTED_SERVICE="${SERVICES[$((svc_choice-1))]}"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
    echo "Selected Service: $SELECTED_SERVICE"

    # NON_INTERACTIVE and VERBOSE remain as default (false)
    NON_INTERACTIVE=false
    VERBOSE=false
}

# Main execution
get_action_input

echo ""
echo "==================== Collected Input ===================="
echo "Source Datacenter: $SOURCE_DATACENTER"
echo "Destination Datacenter: $DEST_DATACENTER"
echo "Source VM Input: $SOURCE_VM_INPUT"
echo "Max Parallel Jobs: $MAX_PARALLEL_JOBS"
echo "Selected Service: $SELECTED_SERVICE"
echo "Non-interactive: $NON_INTERACTIVE"
echo "Verbose: $VERBOSE"
echo "========================================================="
