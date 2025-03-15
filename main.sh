#!/bin/bash

# Modern Minimalist Color Scheme
# Soft, elegant colors that work well together
FG_WHITE='\033[38;5;255m'  # Soft white text
FG_GRAY='\033[38;5;240m'   # Subtle gray
FG_DARK='\033[38;5;237m'   # Dark shade for backgrounds
FG_CYAN='\033[38;5;81m'    # Soft cyan - primary accent
FG_BLUE='\033[38;5;75m'    # Soft blue - secondary accent
FG_GREEN='\033[38;5;114m'  # Soft green - success
FG_YELLOW='\033[38;5;221m' # Soft yellow - warning
FG_RED='\033[38;5;203m'    # Soft red - error
FG_PURPLE='\033[38;5;141m' # Soft purple - highlight

# Text styles
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
RESET='\033[0m'

# Info directory path
INFO_PATH="$(dirname "$0")/Info"
COLLECTED_FILE="$INFO_PATH/Collected_Input"

# Get terminal dimensions
TERM_WIDTH=$(tput cols)

# Parse VM list from configuration
parse_vm_list() {
    local section_header="$1"
    local stop_pattern="$2"
    local dc="$3"
    local vm_list_raw
    
    vm_list_raw=$(awk -v header="$section_header" -v stop="$stop_pattern" '
        $0 ~ header {flag=1; next}
        $0 ~ stop {flag=0}
        flag { if($0 ~ /-/) print $0 }
    ' "$COLLECTED_FILE")
    
    local available_vms=()
    while IFS= read -r line; do
         available_vms+=("$line")
    done < <(awk -F'|' -v dc="$dc" '$1==dc {print $2}' "$INFO_PATH/servers.conf")
    
    local vm_indices=()
    while IFS= read -r line; do
         vm_name=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*//')
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
    
    IFS=, ; echo "${vm_indices[*]}" ; IFS=' '
}

# Draw a horizontal line with ASCII-compatible characters
draw_line() {
    local width=${1:-$TERM_WIDTH}
    local style=${2:-"single"}
    local color=${3:-$FG_GRAY}
    
    # Use simple ASCII characters for better compatibility
    if [ "$style" = "double" ]; then
        local char="="
    elif [ "$style" = "dashed" ]; then
        local char="-"
    else
        local char="-"
    fi
    
    printf "$color"
    printf "%${width}s" | tr " " "$char"
    printf "$RESET\n"
}

# Modern, elegant spinner
loading_animation() {
    local message="$1"
    local duration=${2:-1}
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local delay=0.05
    
    printf "${FG_CYAN}${message}${RESET} "
    local end_time=$((SECONDS + duration))
    
    while [ $SECONDS -lt $end_time ]; do
        for (( i=0; i<${#chars}; i++ )); do
            printf "${FG_BLUE}%s${RESET}" "${chars:$i:1}"
            sleep $delay
            printf "\b"
        done
    done
    
    printf "${FG_GREEN}✓${RESET}\n"
}

# Print the main header with version info and datetime
print_header() {
    clear
    
    # Current date and time in elegant format
    local current_date=$(date "+%A, %B %d, %Y")
    local current_time=$(date "+%H:%M")
    
    # Top margin
    printf "\n"
    
    # Application title
    printf "  ${FG_CYAN}${BOLD}VM MANAGEMENT CONSOLE${RESET}\n"
    printf "  ${FG_GRAY}${ITALIC}System Administration Interface${RESET}\n\n"
    
    # Date and time on the right side
    printf "  ${FG_GRAY}%s ${FG_BLUE}%s${RESET}\n" "$current_date" "$current_time"
    
    # Subtle divider
    draw_line $TERM_WIDTH "dashed" $FG_GRAY
    
    # Info message
    printf "\n  ${FG_GRAY}${ITALIC}This script runs from the main VM with access to all other VMs${RESET}\n\n"
}

# Draw a card for menu options
draw_option_card() {
    local num="$1"
    local title="$2"
    local desc="$3"
    local icon="$4"
    local is_selected=${5:-false}
    
    # Use different styling based on selection state
    if [ "$is_selected" = true ]; then
        local num_color=$FG_WHITE
        local title_color=$FG_CYAN
        local desc_color=$FG_WHITE
        local indicator="▶"
    else
        local num_color=$FG_GRAY
        local title_color=$FG_BLUE
        local desc_color=$FG_GRAY
        local indicator=" "
    fi
    
    # Card layout
    printf "  ${num_color}${indicator} ${BOLD}${num}${RESET}  ${title_color}${BOLD}${title}${RESET}  ${FG_YELLOW}${icon}${RESET}\n"
    printf "     ${desc_color}${desc}${RESET}\n\n"
}

# Display all menu options
display_menu() {
    local selected=${1:-0}
    
    # Menu header
    printf "\n  ${FG_CYAN}${BOLD}MENU OPTIONS${RESET}\n\n"
    
    # Menu items with dynamic selection highlighting
    draw_option_card "1" "Synchronize" "Sync folders from Main VM to destination" "🔄" $([ $selected -eq 1 ] && echo true || echo false)
    draw_option_card "2" "Update Environment" "Update env files and EDN configuration" "⚙️" $([ $selected -eq 2 ] && echo true || echo false)
    draw_option_card "3" "Switch Services" "Execute sequential actions on remote VMs" "↔️" $([ $selected -eq 3 ] && echo true || echo false)
    draw_option_card "4" "Complete Workflow" "Run entire migration process sequentially" "🚀" $([ $selected -eq 4 ] && echo true || echo false)
    draw_option_card "0" "Exit" "Terminate script and return to shell" "🚪" $([ $selected -eq 0 ] && echo true || echo false)
    
    # Menu footer with instructions
    draw_line $TERM_WIDTH "dashed" $FG_GRAY
    printf "\n  ${FG_WHITE}Enter your choice ${FG_CYAN}(0-4)${FG_WHITE} and press ${FG_CYAN}[ENTER]${FG_WHITE} to continue${RESET}\n\n"
    
    # Command prompt
    printf "  ${FG_PURPLE}❯${RESET} "
}

# Show status messages
show_status() {
    local message="$1"
    local type="$2"
    
    case "$type" in
        "success")
            printf "\n  ${FG_GREEN}✓ ${message}${RESET}\n\n"
            ;;
        "error")
            printf "\n  ${FG_RED}✗ ${message}${RESET}\n\n"
            ;;
        "warning")
            printf "\n  ${FG_YELLOW}! ${message}${RESET}\n\n"
            ;;
        "info")
            printf "\n  ${FG_BLUE}i ${message}${RESET}\n\n"
            ;;
    esac
}

# Elegant progress bar
progress_bar() {
    local title="$1"
    local current="$2"
    local total="$3"
    local width=${4:-40}
    
    local percent=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    # Progress title
    printf "  ${FG_WHITE}%-15s${RESET} " "$title"
    
    # Elegant progress indicator using block characters
    printf "${FG_CYAN}"
    for ((i=0; i<completed; i++)); do
        printf "■"
    done
    
    printf "${FG_GRAY}"
    for ((i=0; i<remaining; i++)); do
        printf "□"
    done
    
    # Show percentage
    printf "${RESET} ${FG_CYAN}%3d%%${RESET}\n" "$percent"
}

# Display section headers
section_header() {
    local title="$1"
    
    printf "\n  ${FG_CYAN}${BOLD}${title}${RESET}\n"
    draw_line $TERM_WIDTH "single" $FG_GRAY
    printf "\n"
}

# Display workflow step status
workflow_step() {
    local step="$1"
    local status="$2"
    local message="$3"
    
    case "$status" in
        "running")
            printf "  ${FG_BLUE}⟳ STEP ${step}:${RESET} ${FG_WHITE}${message}${RESET}\n"
            ;;
        "complete")
            printf "  ${FG_GREEN}✓ STEP ${step}:${RESET} ${FG_WHITE}${message}${RESET}\n"
            ;;
        "error")
            printf "  ${FG_RED}✗ STEP ${step}:${RESET} ${FG_WHITE}${message}${RESET}\n"
            ;;
    esac
}

# Display configuration in an elegant table
show_config_table() {
    local services="$1"
    local source_dc="$2"
    local dest_dc="$3"
    local source_vm="$4"
    local dest_vm="$5"
    local max_jobs="$6"
    
    section_header "CONFIGURATION DETAILS"
    
    # Table layout
    printf "  ${FG_GRAY}PARAMETER${RESET}          ${FG_GRAY}VALUE${RESET}\n"
    draw_line $TERM_WIDTH "dashed" $FG_GRAY
    
    printf "  ${FG_CYAN}%-20s${RESET} ${FG_WHITE}%s${RESET}\n" "SELECTED SERVICES" "$services"
    printf "  ${FG_CYAN}%-20s${RESET} ${FG_WHITE}%s${RESET}\n" "SOURCE DATACENTER" "$source_dc"
    printf "  ${FG_CYAN}%-20s${RESET} ${FG_WHITE}%s${RESET}\n" "DEST DATACENTER" "$dest_dc"
    printf "  ${FG_CYAN}%-20s${RESET} ${FG_WHITE}%s${RESET}\n" "SOURCE VM POSITIONS" "$source_vm"
    printf "  ${FG_CYAN}%-20s${RESET} ${FG_WHITE}%s${RESET}\n" "DEST VM POSITIONS" "$dest_vm"
    printf "  ${FG_CYAN}%-20s${RESET} ${FG_WHITE}%s${RESET}\n" "MAX PARALLEL JOBS" "$max_jobs"
}

# Show completion message
show_completion() {
    printf "\n\n"
    printf "  ${FG_GREEN}${BOLD}★ Complete workflow executed successfully! ★${RESET}\n"
    printf "\n"
}

# Continue prompt
continue_prompt() {
    printf "\n  ${FG_GRAY}Press Enter to continue...${RESET}"
    read
}

# Main script loop
while true; do
    # Print application header
    print_header

    # ASCII Art Banner with glow effect
    echo -e "${CYAN}${BOLD}"
    echo "                                                                        "
    echo "    ██████╗ ██████╗ ███╗   ██╗████████╗██████╗  ██████╗ ██╗            "
    echo "   ██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██╔══██╗██╔═══██╗██║            "
    echo "   ██║     ██║   ██║██╔██╗ ██║   ██║   ██████╔╝██║   ██║██║            "
    echo "   ██║     ██║   ██║██║╚██╗██║   ██║   ██╔══██╗██║   ██║██║            "
    echo "   ╚██████╗╚██████╔╝██║ ╚████║   ██║   ██║  ██║╚██████╔╝███████╗       "
    echo "    ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝       "
    echo "        ██████╗ ███████╗███╗   ██╗████████╗███████╗██████╗             "
    echo "       ██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██╔════╝██╔══██╗            "
    echo "       ██║      █████╗  ██╔██╗ ██║   ██║   █████╗  ██████╔╝            "
    echo "       ██║      ██╔══╝  ██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗            "
    echo "       ╚██████╗ ███████╗██║ ╚████║   ██║   ███████╗██║  ██║            "
    echo "        ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝            "
    echo -e "${RESET}"

    # Show menu and get user selection
    display_menu
    read choice
    
    case $choice in
        1)
            print_header
            loading_animation "Initializing synchronization process..." 1
            
            section_header "SYNCHRONIZATION"
            
            # Fast progress indicator
            for i in {1..5}; do
                progress_bar "Preparing Files" $i 5 
                sleep 0.02
            done
            
            ./simple_synce-main2vm.sh
            
            show_status "Synchronization completed successfully!" "success"
            
            continue_prompt
            ;;
        2)
            print_header
            loading_animation "Preparing environment update..." 1
            
            section_header "ENVIRONMENT UPDATE"
            
            ./edit_edn_base_on_ip.sh
            
            show_status "Environment variables and EDN updated successfully!" "success"
            
            continue_prompt
            ;;
        3)
            print_header
            loading_animation "Initializing service switching..." 1
            
            section_header "SERVICE SWITCHING"
            
            ./action.sh
            
            show_status "Service switching completed successfully!" "success"
            
            continue_prompt
            ;;
        4)
            print_header
            loading_animation "Preparing complete workflow sequence..." 1
            
            section_header "COMPLETE WORKFLOW"

            # Loop until user approves the Collected_Input
            while true; do
                if [ -x "./input.sh" ]; then
                    loading_animation "Collecting input data..." 1
                    ./input.sh
                else
                    show_status "input.sh not found or not executable. Continuing with existing Collected_Input." "warning"
                fi

                if [ ! -f "$COLLECTED_FILE" ]; then
                    show_status "Collected_Input file not found in $INFO_PATH. Aborting workflow." "error"
                    exit 1
                fi

                printf "\n  ${FG_CYAN}CONFIRMATION${RESET} ${FG_WHITE}Do you approve the final Collected Input? (Y/n):${RESET} "
                read approval
                case "$approval" in
                    [Yy]*|"")
                        show_status "Input data approved!" "success"
                        break
                        ;;
                    [Nn]*)
                        show_status "Re-running input collection process..." "warning"
                        ;;
                    *)
                        show_status "Please answer yes or no." "error"
                        ;;
                esac
            done

            # Parse inputs from Collected_Input
            SELECTED_SERVICES=$(grep "^SELECTED SERVICES:" "$COLLECTED_FILE" | cut -d':' -f2 | xargs)
            SELECTED_SERVICES=$(echo "$SELECTED_SERVICES" | tr ' ' ',')
            SOURCE_DC=$(grep "^SOURCE_DATACENTER:" "$COLLECTED_FILE" | cut -d':' -f2 | xargs)
            DEST_DC=$(grep "^DEST_DATACENTER:" "$COLLECTED_FILE" | cut -d':' -f2 | xargs)
            MAX_PARALLEL_JOBS=$(grep "^MAX_PARALLEL_JOBS:" "$COLLECTED_FILE" | cut -d':' -f2 | xargs)

            # Map VM names to position numbers
            SOURCE_VM_ARG=$(parse_vm_list "Selected SOURCE VMs:" "DEST_DATACENTER:" "$SOURCE_DC")
            DEST_VM_ARG=$(parse_vm_list "Selected DEST VMs:" "MAX_PARALLEL_JOBS:" "$DEST_DC")

            # Display configuration with elegant styling
            show_config_table "$SELECTED_SERVICES" "$SOURCE_DC" "$DEST_DC" "$SOURCE_VM_ARG" "$DEST_VM_ARG" "$MAX_PARALLEL_JOBS"
            
            printf "\n"
            
            # Execute commands with elegant status display
            workflow_step "1" "running" "Running Synchronization"
            ./simple_synce-main2vm.sh -d "$DEST_DC" -v "$DEST_VM_ARG" -j "$MAX_PARALLEL_JOBS" -y
            workflow_step "1" "complete" "Synchronization Complete"
            printf "\n"

            workflow_step "2" "running" "Updating Environment & Editing EDN"
            ./edit_edn_base_on_ip.sh --datacenter "$DEST_DC" --servers "$DEST_VM_ARG"
            workflow_step "2" "complete" "Environment Update Complete"
            printf "\n"

            workflow_step "3" "running" "Executing Service Switch"
            ./action.sh -s "$SOURCE_DC" -d "$DEST_DC" -v "$SOURCE_VM_ARG" -D "$DEST_VM_ARG" -p "$MAX_PARALLEL_JOBS" -r "$SELECTED_SERVICES" -y
            workflow_step "3" "complete" "Service Switch Complete"
            
            # Final success message
            show_completion
            
            continue_prompt
            ;;
        0)
            # Exit with elegant animation
            print_header
            loading_animation "Exiting script..." 1
            printf "\n  ${FG_CYAN}${BOLD}GOODBYE${RESET} ${FG_WHITE}Have a great day!${RESET}\n\n"
            break
            ;;
        *)
            show_status "Invalid choice. Please enter a valid number (0, 1, 2, 3, or 4)." "error"
            sleep 2
            ;;
    esac
done