#!/bin/bash
# sc_1: Simple script to get user input (datacenter and VMs) from servers.conf

# Get script directory and set config file path
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="${SCRIPT_DIR}/Info"
SERVERS_CONF="${INFO_PATH}/servers.conf"

# Function: get_user_input
# Reads servers.conf, prompts for datacenter and VM selection, and stores selections in variables.
get_user_input() {
    # Check for servers.conf existence
    if [ ! -f "$SERVERS_CONF" ]; then
        echo "Error: servers.conf not found at $SERVERS_CONF"
        exit 1
    fi

    # Get unique datacenters from servers.conf (format: datacenter|vm_name|ip|host|username|port)
    mapfile -t datacenters < <(awk -F'|' '$1 != "" {print $1}' "$SERVERS_CONF" | sort -u)
    
    echo "Available Datacenters:"
    for i in "${!datacenters[@]}"; do
        echo "$((i+1)). ${datacenters[$i]}"
    done

    # Prompt user to select a datacenter
    read -p "Select datacenter (1-${#datacenters[@]}): " dc_choice
    if ! [[ "$dc_choice" =~ ^[0-9]+$ ]] || [ "$dc_choice" -lt 1 ] || [ "$dc_choice" -gt "${#datacenters[@]}" ]; then
        echo "Invalid selection. Exiting."
        exit 1
    fi
    SELECTED_DC="${datacenters[$((dc_choice-1))]}"
    echo "Selected Datacenter: $SELECTED_DC"

    # Get VMs for the selected datacenter (from the second field)
    mapfile -t available_vms < <(awk -F'|' -v dc="$SELECTED_DC" '$1 == dc {print $2}' "$SERVERS_CONF")
    if [ ${#available_vms[@]} -eq 0 ]; then
        echo "No VMs found for datacenter $SELECTED_DC."
        exit 1
    fi

    echo "Available VMs in $SELECTED_DC:"
    for i in "${!available_vms[@]}"; do
        echo "$((i+1)). ${available_vms[$i]}"
    done
    echo "$(( ${#available_vms[@]}+1 )). all (select all VMs)"

    # Prompt user to select VMs (accepting comma-separated numbers or "all")
    read -p "Enter VM numbers (e.g., 1,3,5 or all): " vm_input
    # Normalize input: remove spaces and convert to lowercase
    vm_input=$(echo "$vm_input" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    
    SELECTED_VMS=()
    if [ "$vm_input" = "all" ] || [ "$vm_input" = "$(( ${#available_vms[@]}+1 ))" ]; then
        SELECTED_VMS=("${available_vms[@]}")
    else
        IFS=',' read -ra vm_numbers <<< "$vm_input"
        for num in "${vm_numbers[@]}"; do
            if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#available_vms[@]}" ]; then
                echo "Warning: Invalid VM number '$num' skipped."
            else
                SELECTED_VMS+=("${available_vms[$((num-1))]}")
            fi
        done
    fi

    if [ ${#SELECTED_VMS[@]} -eq 0 ]; then
        echo "No valid VMs selected. Exiting."
        exit 1
    fi
}

# Main execution
get_user_input

# Print the selections
echo ""
echo "======================================"
echo "User Selections:"
echo "Datacenter: $SELECTED_DC"
echo "VMs:"
for vm in "${SELECTED_VMS[@]}"; do
    echo " - $vm"
done
echo "======================================"
