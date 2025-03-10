#!/bin/bash
# sc_2: Simple script to get user input for syncing (destination datacenter and VMs)

# Set script and config file paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="${SCRIPT_DIR}/Info"
SERVERS_CONF="${INFO_PATH}/servers.conf"

# Default configuration values
INTERACTIVE_MODE=true
AUTO_DATACENTER=""
AUTO_VMS=""
MAX_PARALLEL_JOBS=4
SKIP_CONFIRM=false

# Function to get unique datacenters from servers.conf
get_datacenters() {
    awk -F'|' '{print $1}' "$SERVERS_CONF" | sort -u
}

# Function to get VMs (vm_name field) for a given datacenter from servers.conf
get_vms_for_datacenter() {
    local dc="$1"
    awk -F'|' -v dc="$dc" '$1 == dc {print $2}' "$SERVERS_CONF"
}

# Function to get input from user (interactive or automated)
get_sync_input() {
    # Ensure servers.conf exists
    if [ ! -f "$SERVERS_CONF" ]; then
        echo "ERROR: Configuration file $SERVERS_CONF not found."
        exit 1
    fi

    # Get unique datacenters
    DATACENTERS=($(get_datacenters))
    
    # Destination datacenter selection
    if [ "$INTERACTIVE_MODE" = true ]; then
        echo "Available datacenters:"
        for i in "${!DATACENTERS[@]}"; do
            echo "$((i+1)). ${DATACENTERS[$i]}"
        done
        while true; do
            read -p "Choose destination datacenter (1-${#DATACENTERS[@]}): " DST_DC_CHOICE
            if [[ "$DST_DC_CHOICE" =~ ^[0-9]+$ ]] && [ "$DST_DC_CHOICE" -ge 1 ] && [ "$DST_DC_CHOICE" -le "${#DATACENTERS[@]}" ]; then
                DEST_DATACENTER="${DATACENTERS[$((DST_DC_CHOICE-1))]}"
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done
    else
        # Automated mode: use AUTO_DATACENTER if provided
        DEST_DATACENTER=""
        for dc in "${DATACENTERS[@]}"; do
            if [ "$dc" = "$AUTO_DATACENTER" ]; then
                DEST_DATACENTER="$dc"
                break
            fi
        done
        if [ -z "$DEST_DATACENTER" ]; then
            echo "ERROR: Invalid datacenter specified: $AUTO_DATACENTER"
            echo "Available datacenters: ${DATACENTERS[*]}"
            exit 1
        fi
    fi
    echo "Selected destination datacenter: $DEST_DATACENTER"
    
    # Retrieve VMs for the chosen datacenter
    DEST_VMS=($(get_vms_for_datacenter "$DEST_DATACENTER"))
    if [ ${#DEST_VMS[@]} -eq 0 ]; then
        echo "No VMs found for datacenter $DEST_DATACENTER."
        exit 1
    fi

    # VM selection (interactive or automated)
    if [ "$INTERACTIVE_MODE" = true ]; then
        echo "Available VMs in $DEST_DATACENTER:"
        for i in "${!DEST_VMS[@]}"; do
            echo "$((i+1)). ${DEST_VMS[$i]}"
        done
        echo "$(( ${#DEST_VMS[@]}+1 )). all (select all VMs)"
        while true; do
            read -p "Choose destination VM(s) (enter digits e.g., '246' for VMs 2,4,6): " DST_VM_CHOICE
            SELECTED_VMS=()
            if [[ "$DST_VM_CHOICE" == "$(( ${#DEST_VMS[@]}+1 ))" ]]; then
                SELECTED_VMS=("${DEST_VMS[@]}")
                break
            elif [[ "$DST_VM_CHOICE" =~ ^[0-9]+$ ]]; then
                valid=true
                for (( i=0; i<${#DST_VM_CHOICE}; i++ )); do
                    digit="${DST_VM_CHOICE:$i:1}"
                    if [ "$digit" -ge 1 ] && [ "$digit" -le "${#DEST_VMS[@]}" ]; then
                        SELECTED_VMS+=("${DEST_VMS[$((digit-1))]}")
                    else
                        echo "Invalid VM number: $digit"
                        valid=false
                        break
                    fi
                done
                if [ "$valid" = true ]; then
                    break
                fi
            else
                echo "Invalid selection. Please try again."
            fi
        done
    else
        # Automated mode: use AUTO_VMS if provided
        if [ "$AUTO_VMS" = "all" ]; then
            SELECTED_VMS=("${DEST_VMS[@]}")
        else
            SELECTED_VMS=()
            IFS=',' read -ra VM_INDEXES <<< "$AUTO_VMS"
            for idx in "${VM_INDEXES[@]}"; do
                if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le "${#DEST_VMS[@]}" ]; then
                    SELECTED_VMS+=("${DEST_VMS[$((idx-1))]}")
                else
                    echo "ERROR: Invalid VM index: $idx"
                    exit 1
                fi
            done
        fi
    fi
}

# Main execution
get_sync_input

# Print the collected input values
echo ""
echo "======================================"
echo "Collected User Input:"
echo "Destination Datacenter: $DEST_DATACENTER"
echo "Selected VMs:"
for vm in "${SELECTED_VMS[@]}"; do
    echo " - $vm"
done
echo "Max Parallel Jobs: $MAX_PARALLEL_JOBS"
echo "Skip Confirmation: $SKIP_CONFIRM"
echo "======================================"
