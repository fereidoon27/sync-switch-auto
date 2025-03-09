#!/bin/bash

# Define color codes for a nicer output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Set script directory and paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="$SCRIPT_DIR/Info"
SERVERS_CONF="$INFO_PATH/servers.conf"

# Check if servers.conf exists
if [ ! -f "$SERVERS_CONF" ]; then
    echo -e "${RED}Error: servers.conf not found in $INFO_PATH${RESET}"
    exit 1
fi

# ----------------------------------------------------
# Step 1: Read and Display Datacenters from servers.conf
# ----------------------------------------------------
# Get unique datacenters from servers.conf (using pipe as delimiter)
DATACENTERS=($(awk -F'|' '{print $1}' "$SERVERS_CONF" | sort -u))
if [ ${#DATACENTERS[@]} -eq 0 ]; then
    echo -e "${RED}No datacenters found in servers.conf.${RESET}"
    exit 1
fi

echo -e "${CYAN}Available Datacenters:${RESET}"
for i in "${!DATACENTERS[@]}"; do
    echo "$((i+1)). ${DATACENTERS[$i]}"
done

# ----------------------------------------------------
# Step 2: Get Source and Destination Datacenters
# ----------------------------------------------------
# Prompt for source datacenter
while true; do
    read -p "Select source datacenter (1-${#DATACENTERS[@]}): " src_choice
    if [[ "$src_choice" =~ ^[0-9]+$ ]] && [ "$src_choice" -ge 1 ] && [ "$src_choice" -le "${#DATACENTERS[@]}" ]; then
        SOURCE_DC="${DATACENTERS[$((src_choice-1))]}"
        break
    else
        echo -e "${RED}Invalid selection. Please try again.${RESET}"
    fi
done

# Prompt for destination datacenter (must be different)
while true; do
    read -p "Select destination datacenter (1-${#DATACENTERS[@]}): " dest_choice
    if [[ "$dest_choice" =~ ^[0-9]+$ ]] && [ "$dest_choice" -ge 1 ] && [ "$dest_choice" -le "${#DATACENTERS[@]}" ]; then
        DEST_DC="${DATACENTERS[$((dest_choice-1))]}"
        if [ "$DEST_DC" == "$SOURCE_DC" ]; then
            echo -e "${RED}Destination datacenter must be different from source.${RESET}"
        else
            break
        fi
    else
        echo -e "${RED}Invalid selection. Please try again.${RESET}"
    fi
done

# ----------------------------------------------------
# Step 3: Get VMs to Migrate from the Source Datacenter
# ----------------------------------------------------
# Get available VMs for the selected source datacenter
SOURCE_VMS=($(awk -F'|' -v dc="$SOURCE_DC" '$1 == dc {print $2}' "$SERVERS_CONF"))
if [ ${#SOURCE_VMS[@]} -eq 0 ]; then
    echo -e "${RED}No VMs found for source datacenter: $SOURCE_DC${RESET}"
    exit 1
fi

echo -e "${CYAN}Available VMs in source datacenter ($SOURCE_DC):${RESET}"
for i in "${!SOURCE_VMS[@]}"; do
    echo "$((i+1)). ${SOURCE_VMS[$i]}"
done
echo "$(( ${#SOURCE_VMS[@]} + 1 )). all (select all VMs)"

# Prompt for VMs to migrate (input as digits, e.g., "12" for VM 1 and 2)
while true; do
    read -p "Select VMs to migrate (enter digits, e.g. '12' for VMs 1 and 2, or '${#SOURCE_VMS[@]}+1' for all): " vm_choice
    SELECTED_VMS=()
    if [ "$vm_choice" == "$(( ${#SOURCE_VMS[@]} + 1 ))" ]; then
        # If "all" is chosen, select all VMs
        SELECTED_VMS=("${SOURCE_VMS[@]}")
        break
    elif [[ "$vm_choice" =~ ^[0-9]+$ ]]; then
        valid=true
        for (( i=0; i<${#vm_choice}; i++ )); do
            digit=${vm_choice:$i:1}
            if [ "$digit" -ge 1 ] && [ "$digit" -le "${#SOURCE_VMS[@]}" ]; then
                SELECTED_VMS+=("${SOURCE_VMS[$((digit-1))]}")
            else
                echo -e "${RED}Invalid VM number: $digit${RESET}"
                valid=false
                break
            fi
        done
        if $valid; then
            break
        fi
    else
        echo -e "${RED}Invalid input. Please try again.${RESET}"
    fi
done

# Display the common inputs
echo -e "\n${GREEN}Common inputs collected:${RESET}"
echo "Source Datacenter: $SOURCE_DC"
echo "Destination Datacenter: $DEST_DC"
echo "VMs to Migrate: ${SELECTED_VMS[@]}"

# Export or prepare the common variables to pass on
export SOURCE_DC
export DEST_DC
# Convert the selected VMs array into a comma-separated list
VM_LIST=$(IFS=,; echo "${SELECTED_VMS[*]}")
export VM_LIST

# ----------------------------------------------------
# Step 4: Main Menu to Call Sub-scripts
# ----------------------------------------------------
while true; do
    echo -e "\n${CYAN}========================================${RESET}"
    echo -e "\n${YELLOW}Select the action you would like to perform:${RESET}\n"
    echo -e "${GREEN}1: Synchronize${RESET}"
    echo -e "   - Sync a folder from the Main VM to a destination VM."
    echo ""
    echo -e "${GREEN}2: Set Environment Variable & Edit EDN Based on IP${RESET}"
    echo -e "   - Copy the environment file and update proxy settings."
    echo ""
    echo -e "${GREEN}3: Switch (Service Transfer Operations)${RESET}"
    echo -e "   - Execute deployment and migration actions on selected VMs."
    echo ""
    echo -e "${RED}0: Exit - Terminate the main script.${RESET}"
    echo -e "${CYAN}========================================${RESET}"

    read -p "Enter a number (0, 1, 2, or 3): " choice
    case $choice in
        1)
            echo -e "\n${GREEN}Running Synchronization...${RESET}"
            ./simple_synce-main2vm.sh "$SOURCE_DC" "$DEST_DC" "$VM_LIST"
            ;;
        2)
            echo -e "\n${GREEN}Setting Environment Variable & Editing EDN Based on IP...${RESET}"
            ./edit_edn_base_on_ip.sh "$SOURCE_DC" "$DEST_DC" "$VM_LIST"
            ;;
        3)
            echo -e "\n${GREEN}Executing Switch (Service Transfer Operations)...${RESET}"
            read -p "Enter maximum number of parallel jobs [2]: " PARALLEL_JOBS
            PARALLEL_JOBS=${PARALLEL_JOBS:-2}
            ./action.sh "$SOURCE_DC" "$DEST_DC" "$VM_LIST" "$PARALLEL_JOBS"
            ;;
        0)
            echo -e "\n${RED}Exiting Main Script. Goodbye!${RESET}"
            break
            ;;
        *)
            echo -e "\n${RED}Invalid choice. Please enter 0, 1, 2, or 3.${RESET}"
            ;;
    esac
done
