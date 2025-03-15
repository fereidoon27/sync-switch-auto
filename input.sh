#!/bin/bash
# input.sh: Integrated input script with colorful menus, saving plain text output,
# and validating that source and destination VMs are not the same when datacenters are identical.
# Prompt order:
# 1. Select service(s)
# 2. Select SOURCE datacenter
# 3. Select DESTINATION datacenter
# 4. Select SOURCE VM(s)
# 5. Select DESTINATION VM(s)
# 6. Enter maximum parallel jobs

#--------------------------------------------------
# Color Definitions
#--------------------------------------------------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
BOLD="\033[1m"
BG_BLUE="\033[44m"
BG_GREEN="\033[42m"
BG_PURPLE="\033[45m"
BG_CYAN="\033[46m"
UNDERLINE="\033[4m"
RESET="\033[0m"

#--------------------------------------------------
# Paths & Defaults
#--------------------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="${SCRIPT_DIR}/Info"
SERVERS_CONF="${INFO_PATH}/servers.conf"

MAX_PARALLEL_JOBS=1
SERVICES=("binance" "kucoin" "gateio")

#--------------------------------------------------
# Helper Functions
#--------------------------------------------------
get_datacenters() {
    awk -F'|' '$1 != "" {print $1}' "$SERVERS_CONF" | sort -u
}

get_vms_for_datacenter() {
    local dc="$1"
    awk -F'|' -v dc="$dc" '$1 == dc {print $2}' "$SERVERS_CONF"
}

# Function to draw a fancy box
draw_box() {
    local title="$1"
    local width=70
    local padding=$(( (width - ${#title}) / 2 - 2 ))
    
    echo -e "${BG_PURPLE}${BOLD}${WHITE}$(printf '═%.0s' $(seq 1 $width))${RESET}"
    echo -e "${BG_PURPLE}${BOLD}${WHITE}║$(printf ' %.0s' $(seq 1 $padding)) $title $(printf ' %.0s' $(seq 1 $padding))║${RESET}"
    echo -e "${BG_PURPLE}${BOLD}${WHITE}$(printf '═%.0s' $(seq 1 $width))${RESET}"
}

# Function to draw a fancy section header
draw_section() {
    local title="$1"
    echo -e "\n${CYAN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
    echo -e "${CYAN}${BOLD}┃  ${BG_CYAN}${WHITE}${BOLD} $title ${RESET}${CYAN}${BOLD}$(printf ' %.0s' $(seq 1 $(( 65 - ${#title} ))))┃${RESET}"
    echo -e "${CYAN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"
}

# Function to draw a menu item
draw_menu_item() {
    local number="$1"
    local text="$2"
    echo -e "  ${GREEN}${BOLD}[$number]${RESET} ${WHITE}$text${RESET}"
}

# Function to display selected items
display_selection() {
    local title="$1"
    shift
    local items=("$@")
    
    echo -e "\n${YELLOW}${BOLD}$title:${RESET}"
    echo -e "${YELLOW}┌───────────────────────────────────────────────────┐${RESET}"
    for item in "${items[@]}"; do
        echo -e "${YELLOW}│ ${GREEN}✓${RESET} $item$(printf ' %.0s' $(seq 1 $(( 48 - ${#item} ))))${YELLOW}│${RESET}"
    done
    echo -e "${YELLOW}└───────────────────────────────────────────────────┘${RESET}"
}

#--------------------------------------------------
# Integrated Input Function
#--------------------------------------------------
get_action_input() {
    if [ ! -f "$SERVERS_CONF" ]; then
        echo -e "${RED}${BOLD}ERROR:${RESET} Configuration file ${YELLOW}$SERVERS_CONF${RESET} not found."
        exit 1
    fi

    # Welcome Banner
    clear
    draw_box "VM MIGRATION TOOL"
    echo -e "\n${BLUE}${BOLD}Welcome to the VM Migration Tool. Please follow the prompts below.${RESET}\n"

    # 1. Service Selection (multiple allowed)
    draw_section "AVAILABLE SERVICES"
    echo
    for i in "${!SERVICES[@]}"; do
        draw_menu_item "$((i+1))" "${SERVICES[$i]}"
    done
    draw_menu_item "$(( ${#SERVICES[@]}+1 ))" "all (select all services)"
    echo
    
    while true; do
        read -p "$(echo -e ${BLUE}${BOLD}"➤ "${RESET}${BLUE}"Select service(s) (e.g., '12' for binance and kucoin, '4' for all): "${RESET})" svc_input
        SELECTED_SERVICES=()
        if [ "$svc_input" = "all" ]; then
            SELECTED_SERVICES=("${SERVICES[@]}")
            break
        elif [[ "$svc_input" =~ ^[0-9]+$ ]]; then
            if [ "$svc_input" -eq $(( ${#SERVICES[@]}+1 )) ]; then
                SELECTED_SERVICES=("${SERVICES[@]}")
                break
            fi
            valid=true
            for (( i=0; i<${#svc_input}; i++ )); do
                digit="${svc_input:$i:1}"
                if [ "$digit" -ge 1 ] && [ "$digit" -le "${#SERVICES[@]}" ]; then
                    SELECTED_SERVICES+=("${SERVICES[$((digit-1))]}")
                else
                    echo -e "${RED}${BOLD}✘ Invalid service number: $digit${RESET}"
                    valid=false
                    break
                fi
            done
            [ "$valid" = true ] && break
        else
            echo -e "${RED}${BOLD}✘ Invalid selection. Please try again.${RESET}"
        fi
    done
    
    display_selection "SELECTED SERVICES" "${SELECTED_SERVICES[@]}"

    # 2. Get available datacenters
    mapfile -t DATACENTERS < <(get_datacenters)
    draw_section "AVAILABLE DATACENTERS"
    echo
    for i in "${!DATACENTERS[@]}"; do
        draw_menu_item "$((i+1))" "${DATACENTERS[$i]}"
    done
    echo

    # 3. SOURCE_DATACENTER
    while true; do
        read -p "$(echo -e ${BLUE}${BOLD}"➤ "${RESET}${BLUE}"Select ${BOLD}SOURCE${RESET}${BLUE} datacenter (1-${#DATACENTERS[@]}): "${RESET})" src_choice
        if [[ "$src_choice" =~ ^[0-9]+$ ]] && [ "$src_choice" -ge 1 ] && [ "$src_choice" -le "${#DATACENTERS[@]}" ]; then
            SOURCE_DATACENTER="${DATACENTERS[$((src_choice-1))]}"
            break
        else
            echo -e "${RED}${BOLD}✘ Invalid selection. Please try again.${RESET}"
        fi
    done
    
    echo -e "\n${YELLOW}${BOLD}SOURCE DATACENTER:${RESET} ${BG_GREEN}${BLACK}${BOLD} $SOURCE_DATACENTER ${RESET}"

    # 4. DESTINATION_DATACENTER
    while true; do
        read -p "$(echo -e ${BLUE}${BOLD}"➤ "${RESET}${BLUE}"Select ${BOLD}DESTINATION${RESET}${BLUE} datacenter (1-${#DATACENTERS[@]}): "${RESET})" dst_choice
        if [[ "$dst_choice" =~ ^[0-9]+$ ]] && [ "$dst_choice" -ge 1 ] && [ "$dst_choice" -le "${#DATACENTERS[@]}" ]; then
            DEST_DATACENTER="${DATACENTERS[$((dst_choice-1))]}"
            break
        else
            echo -e "${RED}${BOLD}✘ Invalid selection. Please try again.${RESET}"
        fi
    done
    
    echo -e "\n${YELLOW}${BOLD}DESTINATION DATACENTER:${RESET} ${BG_GREEN}${BLACK}${BOLD} $DEST_DATACENTER ${RESET}"

    # 5. SOURCE VMs
    mapfile -t SOURCE_VMS < <(get_vms_for_datacenter "$SOURCE_DATACENTER")
    if [ ${#SOURCE_VMS[@]} -eq 0 ]; then
        echo -e "${RED}${BOLD}✘ No VMs found for source datacenter $SOURCE_DATACENTER.${RESET}"
        exit 1
    fi
    
    draw_section "SOURCE VMs in $SOURCE_DATACENTER"
    echo
    # Display in a grid format (3 columns)
    col_width=25
    row_count=$(( (${#SOURCE_VMS[@]} + 2) / 3 ))
    for (( row=0; row<row_count; row++ )); do
        line=""
        for (( col=0; col<3; col++ )); do
            idx=$((row + col*row_count))
            if [ $idx -lt ${#SOURCE_VMS[@]} ]; then
                vm_num=$((idx+1))
                vm_name="${SOURCE_VMS[$idx]}"
                line+="  ${GREEN}${BOLD}[$vm_num]${RESET} ${WHITE}${vm_name}${RESET}$(printf ' %.0s' $(seq 1 $(( col_width - ${#vm_name} - 6 ))))"
            fi
        done
        echo -e "$line"
    done
    echo -e "  ${GREEN}${BOLD}[$(( ${#SOURCE_VMS[@]}+1 ))]${RESET} ${WHITE}all (select all VMs)${RESET}"
    echo
    
    while true; do
        read -p "$(echo -e ${BLUE}${BOLD}"➤ "${RESET}${BLUE}"Select SOURCE VM(s) (e.g., '614' for VMs 6,1,4 or 'all'): "${RESET})" src_vm_input
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
                    echo -e "${RED}${BOLD}✘ Invalid VM number: $digit${RESET}"
                    valid=false
                    break
                fi
            done
            [ "$valid" = true ] && break
        else
            echo -e "${RED}${BOLD}✘ Invalid selection. Try again.${RESET}"
        fi
    done
    
    display_selection "SELECTED SOURCE VMs" "${SELECTED_SOURCE_VMS[@]}"

    # 6. DESTINATION VMs
    mapfile -t DEST_VMS < <(get_vms_for_datacenter "$DEST_DATACENTER")
    if [ ${#DEST_VMS[@]} -eq 0 ]; then
        echo -e "${RED}${BOLD}✘ No VMs found for destination datacenter $DEST_DATACENTER.${RESET}"
        exit 1
    fi
    
    draw_section "DESTINATION VMs in $DEST_DATACENTER"
    echo
    # Display in a grid format (3 columns)
    row_count=$(( (${#DEST_VMS[@]} + 2) / 3 ))
    for (( row=0; row<row_count; row++ )); do
        line=""
        for (( col=0; col<3; col++ )); do
            idx=$((row + col*row_count))
            if [ $idx -lt ${#DEST_VMS[@]} ]; then
                vm_num=$((idx+1))
                vm_name="${DEST_VMS[$idx]}"
                line+="  ${GREEN}${BOLD}[$vm_num]${RESET} ${WHITE}${vm_name}${RESET}$(printf ' %.0s' $(seq 1 $(( col_width - ${#vm_name} - 6 ))))"
            fi
        done
        echo -e "$line"
    done
    echo -e "  ${GREEN}${BOLD}[$(( ${#DEST_VMS[@]}+1 ))]${RESET} ${WHITE}all (select all VMs)${RESET}"
    echo
    
    while true; do
        read -p "$(echo -e ${BLUE}${BOLD}"➤ "${RESET}${BLUE}"Select DESTINATION VM(s) (e.g., '246' for VMs 2,4,6 or 'all'): "${RESET})" dst_vm_input
        SELECTED_DEST_VMS=()
        if [ "$dst_vm_input" = "all" ]; then
            SELECTED_DEST_VMS=("${DEST_VMS[@]}")
            valid=true
        elif [[ "$dst_vm_input" =~ ^[0-9]+$ ]]; then
            if [ "$dst_vm_input" -eq $(( ${#DEST_VMS[@]}+1 )) ]; then
                SELECTED_DEST_VMS=("${DEST_VMS[@]}")
                valid=true
            else
                valid=true
                for (( i=0; i<${#dst_vm_input}; i++ )); do
                    digit="${dst_vm_input:$i:1}"
                    if [ "$digit" -ge 1 ] && [ "$digit" -le "${#DEST_VMS[@]}" ]; then
                        SELECTED_DEST_VMS+=("${DEST_VMS[$((digit-1))]}")
                    else
                        echo -e "${RED}${BOLD}✘ Invalid VM number: $digit${RESET}"
                        valid=false
                        break
                    fi
                done
            fi
        else
            echo -e "${RED}${BOLD}✘ Invalid selection. Try again.${RESET}"
            valid=false
        fi

        # Only check overlap if source and destination datacenters are the same.
        if [ "$SOURCE_DATACENTER" = "$DEST_DATACENTER" ]; then
            overlap=false
            for sv in "${SELECTED_SOURCE_VMS[@]}"; do
                for dv in "${SELECTED_DEST_VMS[@]}"; do
                    if [ "$sv" = "$dv" ]; then
                        overlap=true
                        break
                    fi
                done
                [ "$overlap" = true ] && break
            done
            if [ "$overlap" = true ]; then
                echo -e "${RED}${BOLD}✘ Error: When source and destination datacenter are the same, they must not select the same VMs.${RESET}"
                continue
            fi
        fi

        if [ "$valid" = true ]; then
            break
        fi
    done
    
    display_selection "SELECTED DESTINATION VMs" "${SELECTED_DEST_VMS[@]}"

    # 7. MAX_PARALLEL_JOBS
    draw_section "PARALLEL JOBS CONFIGURATION"
    echo
    read -p "$(echo -e ${BLUE}${BOLD}"➤ "${RESET}${BLUE}"Enter maximum parallel jobs [default ${MAX_PARALLEL_JOBS}]: "${RESET})" jobs_input
    if [[ -n "$jobs_input" ]]; then
        if [[ "$jobs_input" =~ ^[1-9][0-9]*$ ]]; then
            MAX_PARALLEL_JOBS="$jobs_input"
        else
            echo -e "${RED}${BOLD}✘ Invalid input. Using default: $MAX_PARALLEL_JOBS${RESET}"
        fi
    fi
    
    echo -e "\n${YELLOW}${BOLD}MAX PARALLEL JOBS:${RESET} ${BG_GREEN}${BLACK}${BOLD} $MAX_PARALLEL_JOBS ${RESET}"
}

#--------------------------------------------------
# Main Execution
#--------------------------------------------------
get_action_input

# Display collected input (colorful)
clear
draw_box "MIGRATION SUMMARY"

echo -e "\n${PURPLE}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━ COLLECTED INPUT ━━━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"

echo -e "${YELLOW}${BOLD}SELECTED SERVICES:${RESET}"
echo -e "${YELLOW}┌───────────────────────────────────────────────────┐${RESET}"
echo -e "${YELLOW}│${RESET} ${GREEN}${BOLD}$(printf '%-51s' "${SELECTED_SERVICES[*]}")${RESET} ${YELLOW}│${RESET}"
echo -e "${YELLOW}└───────────────────────────────────────────────────┘${RESET}"

echo -e "${YELLOW}${BOLD}SOURCE DATACENTER:${RESET} ${BG_GREEN}${BLACK}${BOLD} $SOURCE_DATACENTER ${RESET}"
echo -e "${YELLOW}${BOLD}Selected SOURCE VMs:${RESET}"
echo -e "${YELLOW}┌───────────────────────────────────────────────────┐${RESET}"
for vm in "${SELECTED_SOURCE_VMS[@]}"; do
    echo -e "${YELLOW}│ ${GREEN}✓${RESET} $vm$(printf ' %.0s' $(seq 1 $(( 48 - ${#vm} ))))${YELLOW}│${RESET}"
done
echo -e "${YELLOW}└───────────────────────────────────────────────────┘${RESET}"

echo -e "${YELLOW}${BOLD}DESTINATION DATACENTER:${RESET} ${BG_GREEN}${BLACK}${BOLD} $DEST_DATACENTER ${RESET}"
echo -e "${YELLOW}${BOLD}Selected DESTINATION VMs:${RESET}"
echo -e "${YELLOW}┌───────────────────────────────────────────────────┐${RESET}"
for vm in "${SELECTED_DEST_VMS[@]}"; do
    echo -e "${YELLOW}│ ${GREEN}✓${RESET} $vm$(printf ' %.0s' $(seq 1 $(( 48 - ${#vm} ))))${YELLOW}│${RESET}"
done
echo -e "${YELLOW}└───────────────────────────────────────────────────┘${RESET}"

echo -e "${YELLOW}${BOLD}MAX PARALLEL JOBS:${RESET} ${BG_GREEN}${BLACK}${BOLD} $MAX_PARALLEL_JOBS ${RESET}"

echo -e "${PURPLE}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"

# Save plain text output to Collected_Input file (without colors)
OUTPUT_FILE="${INFO_PATH}/Collected_Input"
{
    echo "SELECTED SERVICES: ${SELECTED_SERVICES[*]}"
    echo "SOURCE_DATACENTER: $SOURCE_DATACENTER"
    echo "Selected SOURCE VMs:"
    for vm in "${SELECTED_SOURCE_VMS[@]}"; do
        echo "  - $vm"
    done
    echo "DEST_DATACENTER: $DEST_DATACENTER"
    echo "Selected DEST VMs:"
    for vm in "${SELECTED_DEST_VMS[@]}"; do
        echo "  - $vm"
    done
    echo "MAX_PARALLEL_JOBS: $MAX_PARALLEL_JOBS"
} > "$OUTPUT_FILE"

echo -e "\n${GREEN}${BOLD}✓ Collected input saved to:${RESET} $OUTPUT_FILE"
echo -e "${BLUE}${BOLD}Press any key to continue...${RESET}"
read -n 1