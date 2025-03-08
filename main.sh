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

    echo -e "${GREEN}2: Set environment variable & Edit EDN Based on IP${RESET}"
    echo -e "   - ${CYAN}Copies the appropriate environment file and modifies proxy settings in configuration files.${RESET}"
    echo ""

    echo -e "${GREEN}3: Switch${RESET}"
    echo -e "   - ${CYAN}Remotely execute sequential actions on a destination VM (deploy, start) and the source VM (stop, purge).${RESET}"
    echo ""

    echo -e "${RED}0: Exit - Terminate the main script.${RESET}"
    echo -e "${CYAN}========================================${RESET}"

    # Prompt the user for input
    read -p "Enter a number (0, 1, 2, or 3): " choice

    case $choice in
        1)
            # Run simple_synce-main2vm.sh script
            echo "Running Synchronization..."
            ./simple_synce-main2vm.sh
            ;;
        2)
            # Run edit_edn_base_on_ip.sh script
            echo "Setting Environment Variable & Editing EDN Based on IP..."
            ./edit_edn_base_on_ip.sh
            ;;
        3)
            # Run action.sh script
            echo "Executing Switch..."
            ./action.sh
            ;;
        0)
            # Exit the script
            echo "Exiting Main Script. Goodbye!"
            break
            ;;
        *)
            # Handle invalid input
            echo "Invalid choice. Please enter a valid number (0, 1, 2, or 3)."
            ;;
    esac
done
