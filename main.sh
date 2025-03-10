#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Define the Info directory (assuming it is in the same folder as main.sh)
INFO_PATH="$(dirname "$0")/Info"
COLLECTED_FILE="$INFO_PATH/Collected_Input"

# Function to map selected VM names to their position numbers based on servers.conf
parse_vm_list() {
    local section_header="$1"
    local stop_pattern="$2"
    local dc="$3"
    local vm_list_raw
    # Extract the block of lines under the given header until the stop pattern is reached
    vm_list_raw=$(awk -v header="$section_header" -v stop="$stop_pattern" '
        $0 ~ header {flag=1; next}
        $0 ~ stop {flag=0}
        flag { if($0 ~ /-/) print $0 }
    ' "$COLLECTED_FILE")
    
    # Get the available VMs for the specified datacenter from servers.conf (preserving file order)
    local available_vms=()
    while IFS= read -r line; do
         available_vms+=("$line")
    done < <(awk -F'|' -v dc="$dc" '$1==dc {print $2}' "$INFO_PATH/servers.conf")
    
    local vm_indices=()
    # Process each line from the collected input block
    while IFS= read -r line; do
         # Remove leading spaces and the dash
         vm_name=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*//')
         # Find the position (1-indexed) of this VM name in available_vms array
         index=0
         found_index=""
         for v in "${available_vms[@]}"; do
             index=$((index+1))
             if [[ "$v" == "$vm_name" ]]; then
                 found_index=$index
                 break
             fi
         done
         if [[ -n "$found_index" ]]; then
             vm_indices+=("$found_index")
         fi
    done <<< "$vm_list_raw"
    
    # Join the indices with commas
    IFS=, ; echo "${vm_indices[*]}" ; IFS=' '
}

while true; do

    echo -e "${CYAN}========================================${RESET}"
    echo -e "\n${YELLOW}This script runs from the main VM, which has access to destination VMs.${RESET}"
    echo -e "\n${YELLOW}Select the action you would like to perform:${RESET}\n"

    echo -e "${GREEN}1: Synchronize${RESET}"
    echo -e "   - ${CYAN}Sync a folder from the Main VM to a destination VM.${RESET}"
    echo ""

    echo -e "${GREEN}2: Update Environment & Edit EDN${RESET}"
    echo -e "   - ${CYAN}Copy the appropriate environment file and modify proxy settings in configuration files.${RESET}"
    echo ""

    echo -e "${GREEN}3: Switch Services${RESET}"
    echo -e "   - ${CYAN}Execute sequential actions (deploy, start, stop, purge) on remote VMs for a selected service.${RESET}"
    echo ""

    echo -e "${GREEN}4: Run Complete Workflow Sequentially${RESET}"
    echo -e "   - ${CYAN}Collect inputs (via input.sh) and run synchronization, environment update, and service migration in sequence.${RESET}"
    echo ""

    echo -e "${RED}0: Exit - Terminate the main script.${RESET}"
    echo -e "${CYAN}========================================${RESET}"

    # Prompt the user for input
    read -p "Enter a number (0, 1, 2, 3, or 4): " choice

    case $choice in
        1)
            echo "Running Synchronization..."
            ./simple_synce-main2vm.sh
            ;;
        2)
            echo "Updating Environment Variables & Editing EDN..."
            ./edit_edn_base_on_ip.sh
            ;;
        3)
            echo "Executing Service Switch..."
            ./action.sh
            ;;
        4)
            echo "Running Complete Workflow Sequentially..."

            # Run input.sh to gather all necessary inputs if available.
            if [ -x "./input.sh" ]; then
                echo "Collecting input..."
                ./input.sh
            else
                echo "Warning: input.sh not found or not executable. Continuing with existing Collected_Input."
            fi

            # Verify that the Collected_Input file exists.
            if [ ! -f "$COLLECTED_FILE" ]; then
                echo "Error: Collected_Input file not found in $INFO_PATH. Aborting workflow."
                exit 1
            fi

            # Parse inputs from Collected_Input
            SOURCE_DC=$(grep "^SOURCE_DATACENTER:" "$COLLECTED_FILE" | cut -d':' -f2 | xargs)
            DEST_DC=$(grep "^DEST_DATACENTER:" "$COLLECTED_FILE" | cut -d':' -f2 | xargs)
            MAX_PARALLEL_JOBS=$(grep "^MAX_PARALLEL_JOBS:" "$COLLECTED_FILE" | cut -d':' -f2 | xargs)
            SELECTED_SERVICE=$(grep "^SELECTED_SERVICE:" "$COLLECTED_FILE" | cut -d':' -f2 | xargs)

            # Map VM names to position numbers based on servers.conf for each datacenter.
            SOURCE_VM_ARG=$(parse_vm_list "Selected SOURCE VMs:" "DEST_DATACENTER:" "$SOURCE_DC")
            DEST_VM_ARG=$(parse_vm_list "Selected DEST VMs:" "MAX_PARALLEL_JOBS:" "$DEST_DC")

            echo "Collected inputs:"
            echo "  SOURCE_DATACENTER: $SOURCE_DC"
            echo "  DEST_DATACENTER: $DEST_DC"
            echo "  Selected SOURCE VMs (positions): $SOURCE_VM_ARG"
            echo "  Selected DEST VMs (positions): $DEST_VM_ARG"
            echo "  MAX_PARALLEL_JOBS: $MAX_PARALLEL_JOBS"
            echo "  SELECTED_SERVICE: $SELECTED_SERVICE"

            # Execute the commands sequentially with the constructed parameters.
            echo "Step 1: Running Synchronization..."
            ./simple_synce-main2vm.sh -d "$DEST_DC" -v "$DEST_VM_ARG" -j "$MAX_PARALLEL_JOBS" -y

            echo "Step 2: Updating Environment & Editing EDN..."
            ./edit_edn_base_on_ip.sh --datacenter "$DEST_DC" --servers "$DEST_VM_ARG"

            echo "Step 3: Executing Service Switch..."
            ./action.sh -s "$SOURCE_DC" -d "$DEST_DC" -v "$SOURCE_VM_ARG" -p "$MAX_PARALLEL_JOBS" -r "$SELECTED_SERVICE" -y
            ;;
        0)
            echo "Exiting Main Script. Goodbye!"
            break
            ;;
        *)
            echo "Invalid choice. Please enter a valid number (0, 1, 2, 3, or 4)."
            ;;
    esac
done
