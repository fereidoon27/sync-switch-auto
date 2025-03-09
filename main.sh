#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

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

    echo -e "${GREEN}4: Run Full Workflow Sequentially${RESET}"
    echo -e "   - ${CYAN}Execute synchronization, then update environment settings, and finally perform service migration.${RESET}"
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
            echo "Running Full Workflow Sequentially..."
            echo "Step 1: Synchronizing files..."
            ./simple_synce-main2vm.sh
            echo "Step 2: Updating Environment and Editing EDN..."
            ./edit_edn_base_on_ip.sh
            echo "Step 3: Executing Service Switch..."
            ./action.sh
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
