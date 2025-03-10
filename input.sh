#!/bin/bash
# input.sh: Integrated input script with colorful, attractive menus.
# The collected input is also saved in Collected_Input.txt.

#--------------------------------------------------
# Color Definitions
#--------------------------------------------------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

#--------------------------------------------------
# Paths & Defaults
#--------------------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="${SCRIPT_DIR}/Info"
SERVERS_CONF="${INFO_PATH}/servers.conf"

MAX_PARALLEL_JOBS=4
SERVICES=("binance" "kucoin" "gateio")

#--------------------------------------------------
# Helper Functions
#--------------------------------------------------

# Get unique datacenters from servers.conf (ignoring empty first fields)
get_datacenters() {
    awk -F'|' '$1 != "" {print $1}' "$SERVERS_CONF" | sort -u
}

# Get VMs (second field) for a given datacenter
get_vms_for_datacenter() {
    local dc="$1"
    awk -F'|' -v dc="$dc" '$1 == dc {print $2}' "$SERVERS_CONF"
}

#--------------------------------------------------
# Integrated Input Function
#--------------------------------------------------
get_action_input() {
    # Check if servers.conf exists
    if [ ! -f "$SERVERS_CONF" ]; then
        echo -e "${RED}${BOLD}ERROR:${RESET} Configuration file ${YELLOW}$SERVERS_CONF${RESET} not found."
        exit 1
    fi

    # Get available datacenters
    mapfile -t DATACENTERS < <(get_datacenters)
    echo -e "\n${CYAN}${BOLD}=== Available Datacenters ===${RESET}"
    for i in "${!DATACENTERS[@]}"; do
        echo -e "${GREEN}$((i+1)). ${DATACENTERS[$i]}${RESET}"
    done

    # Prompt for SOURCE_DATACENTER
    while true; do
        read -p "$(echo -e ${BLUE}"Select ${BOLD}SOURCE${RESET}${BLUE} datacenter (1-${#DATACENTERS[@]}): "${RESET})" src_choice
        if [[ "$src_choice" =~ ^[0-9]+$ ]] && [ "$src_choice" -ge 1 ] && [ "$src_choice" -le "${#DATACENTERS[@]}" ]; then
            SOURCE_DATACENTER="${DATACENTERS[$((src_choice-1))]}"
            break
        else
            echo -e "${RED}Invalid selection. Please try again.${RESET}"
        fi
    done
    echo -e "${YELLOW}Selected SOURCE Datacenter: ${BOLD}$SOURCE_DATACENTER${RESET}"

    # Get available source VMs
    mapfile -t SOURCE_VMS < <(get_vms_for_datacenter "$SOURCE_DATACENTER")
    if [ ${#SOURCE_VMS[@]} -eq 0 ]; then
        echo -e "${RED}No VMs found for source datacenter $SOURCE_DATACENTER.${RESET}"
        exit 1
    fi
    echo -e "\n${CYAN}${BOLD}=== Available Source VMs in $SOURCE_DATACENTER ===${RESET}"
    for i in "${!SOURCE_VMS[@]}"; do
        echo -e "${GREEN}$((i+1)). ${SOURCE_VMS[$i]}${RESET}"
    done
    echo -e "${GREEN}$(( ${#SOURCE_VMS[@]}+1 )). all (select all VMs)${RESET}"
    while true; do
        read -p "$(echo -e ${BLUE}"Select SOURCE VM(s) (e.g., '614' for VMs 6,1,4 or 'all'): "${RESET})" src_vm_input
        SELECTED_SOURCE_VMS=()
        if [ "$src_vm_input" = "all" ] || [ "$src_vm_input" = "$(( ${#SOURCE_VMS[@]}+1 ))" ]; then
            SELECTED_SOURCE_VMS=("${SOURCE_VMS[@]}")
            break
        elif [[ "$src_vm_input" =~ ^[0-9]+$ ]]; then
            valid=true
            for (( i=0; i<${#src_vm_input}; i++ )); do
                digit="${src_vm_input:$i:1}"
                if [ "$digit" -ge 1 ] && [ "$digit" -le "${#SOURCE_VMS[@]}" ]; then
                    SELECTED_SOURCE_VMS+=("${SOURCE_VMS[$((digit-1))]}")
                else
                    echo -e "${RED}Invalid VM number: $digit${RESET}"
                    valid=false
                    break
                fi
            done
            [ "$valid" = true ] && break
        else
            echo -e "${RED}Invalid selection. Try again.${RESET}"
        fi
    done

    # Prompt for DESTINATION_DATACENTER (must be different from source)
    while true; do
        read -p "$(echo -e ${BLUE}"Select DESTINATION datacenter (1-${#DATACENTERS[@]}): "${RESET})" dst_choice
        if [[ "$dst_choice" =~ ^[0-9]+$ ]] && [ "$dst_choice" -ge 1 ] && [ "$dst_choice" -le "${#DATACENTERS[@]}" ]; then
            DEST_DATACENTER="${DATACENTERS[$((dst_choice-1))]}"
            if [ "$DEST_DATACENTER" = "$SOURCE_DATACENTER" ]; then
                echo -e "${RED}Destination datacenter must differ from source. Try again.${RESET}"
            else
                break
            fi
        else
            echo -e "${RED}Invalid selection. Try again.${RESET}"
        fi
    done
    echo -e "${YELLOW}Selected DESTINATION Datacenter: ${BOLD}$DEST_DATACENTER${RESET}"

    # Get available destination VMs
    mapfile -t DEST_VMS < <(get_vms_for_datacenter "$DEST_DATACENTER")
    if [ ${#DEST_VMS[@]} -eq 0 ]; then
        echo -e "${RED}No VMs found for destination datacenter $DEST_DATACENTER.${RESET}"
        exit 1
    fi
    echo -e "\n${CYAN}${BOLD}=== Available Destination VMs in $DEST_DATACENTER ===${RESET}"
    for i in "${!DEST_VMS[@]}"; do
        echo -e "${GREEN}$((i+1)). ${DEST_VMS[$i]}${RESET}"
    done
    echo -e "${GREEN}$(( ${#DEST_VMS[@]}+1 )). all (select all VMs)${RESET}"
    while true; do
        read -p "$(echo -e ${BLUE}"Select DESTINATION VM(s) (e.g., '246' for VMs 2,4,6 or 'all'): "${RESET})" dst_vm_input
        SELECTED_DEST_VMS=()
        if [ "$dst_vm_input" = "all" ] || [ "$dst_vm_input" = "$(( ${#DEST_VMS[@]}+1 ))" ]; then
            SELECTED_DEST_VMS=("${DEST_VMS[@]}")
            break
        elif [[ "$dst_vm_input" =~ ^[0-9]+$ ]]; then
            valid=true
            for (( i=0; i<${#dst_vm_input}; i++ )); do
                digit="${dst_vm_input:$i:1}"
                if [ "$digit" -ge 1 ] && [ "$digit" -le "${#DEST_VMS[@]}" ]; then
                    SELECTED_DEST_VMS+=("${DEST_VMS[$((digit-1))]}")
                else
                    echo -e "${RED}Invalid VM number: $digit${RESET}"
                    valid=false
                    break
                fi
            done
            [ "$valid" = true ] && break
        else
            echo -e "${RED}Invalid selection. Try again.${RESET}"
        fi
    done

    # Prompt for MAX_PARALLEL_JOBS
    read -p "$(echo -e ${BLUE}"Enter maximum parallel jobs [default ${MAX_PARALLEL_JOBS}]: "${RESET})" jobs_input
    if [[ -n "$jobs_input" ]]; then
        if [[ "$jobs_input" =~ ^[1-9][0-9]*$ ]]; then
            MAX_PARALLEL_JOBS="$jobs_input"
        else
            echo -e "${RED}Invalid input. Using default: $MAX_PARALLEL_JOBS${RESET}"
        fi
    fi

    # Prompt for service selection
    echo -e "\n${CYAN}${BOLD}=== Available Services ===${RESET}"
    for i in "${!SERVICES[@]}"; do
        echo -e "${GREEN}$((i+1)). ${SERVICES[$i]}${RESET}"
    done
    while true; do
        read -p "$(echo -e ${BLUE}"Select service (1-${#SERVICES[@]}): "${RESET})" svc_choice
        if [[ "$svc_choice" =~ ^[0-9]+$ ]] && [ "$svc_choice" -ge 1 ] && [ "$svc_choice" -le "${#SERVICES[@]}" ]; then
            SELECTED_SERVICE="${SERVICES[$((svc_choice-1))]}"
            break
        else
            echo -e "${RED}Invalid selection. Try again.${RESET}"
        fi
    done
}

#--------------------------------------------------
# Main Execution
#--------------------------------------------------
get_action_input

# Save and display the collected input in a colorful format,
# while also writing it to Collected_Input.txt.
{
    echo -e "\n${PURPLE}${BOLD}================== Collected Input ==================${RESET}"
    echo -e "${YELLOW}SOURCE_DATACENTER:${RESET} $SOURCE_DATACENTER"
    echo -e "${YELLOW}Selected SOURCE VMs:${RESET}"
    for vm in "${SELECTED_SOURCE_VMS[@]}"; do
        echo -e "  - $vm"
    done
    echo -e "${YELLOW}DEST_DATACENTER:${RESET} $DEST_DATACENTER"
    echo -e "${YELLOW}Selected DEST VMs:${RESET}"
    for vm in "${SELECTED_DEST_VMS[@]}"; do
        echo -e "  - $vm"
    done
    echo -e "${YELLOW}MAX_PARALLEL_JOBS:${RESET} $MAX_PARALLEL_JOBS"
    echo -e "${YELLOW}SELECTED_SERVICE:${RESET} $SELECTED_SERVICE"
    echo -e "${PURPLE}${BOLD}=====================================================${RESET}"
} | tee $INFO_PATH/Collected_Input.txt
