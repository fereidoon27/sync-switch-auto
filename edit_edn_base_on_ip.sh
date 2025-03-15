#!/bin/bash

# Get script directory and config paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="$(dirname "$0")/Info"
SERVERS_CONF="$INFO_PATH/servers.conf"
MAX_PARALLEL=6  # Maximum number of parallel processes
SSH_OPTS="-o StrictHostKeyChecking=no"  # SSH options for automation

# ANSI color and formatting codes
BLUE='\033[38;5;75m'      # Pastel blue
CYAN='\033[38;5;81m'      # Pastel cyan
GRAY='\033[38;5;240m'     # Gray for secondary info
GREEN='\033[38;5;114m'    # Pastel green for success
YELLOW='\033[38;5;221m'   # Pastel yellow for warnings
RED='\033[38;5;203m'      # Pastel red for errors
BOLD='\033[1m'
ITALIC='\033[3m'
RESET='\033[0m'

# UI Helper functions
print_header() {
    local text="$1"
    local width=60
    echo ""
    echo -e "${BOLD}${BLUE}${text}${RESET}"
    echo -e "${GRAY}$(printf '%.0s─' $(seq 1 $width))${RESET}"
}

print_spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local charwidth=${#spin}
    
    while kill -0 $pid 2>/dev/null; do
        local i=$(( (i + 1) % $charwidth ))
        printf "\r${GRAY}%s${RESET} ${CYAN}%s${RESET} " "$message" "${spin:$i:1}"
        sleep .1
    done
    printf "\r${GRAY}%s${RESET} ${GREEN}✓${RESET}  \n" "$message"
}

# Define usage function
show_usage() {
    echo ""
    echo -e "${BLUE}${BOLD}$(basename "$0")${RESET} - Server Configuration Tool"
    echo -e "${GRAY}$(printf '%.0s─' $(seq 1 50))${RESET}"
    echo ""
    echo -e "${BOLD}Usage:${RESET}"
    echo -e "  $(basename "$0") [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo -e "  ${CYAN}-d, --datacenter ${ITALIC}DATACENTER${RESET}  Specify the datacenter name"
    echo -e "  ${CYAN}-s, --servers ${ITALIC}SERVER_LIST${RESET}    Specify servers to process (comma-separated numbers or \"all\")"
    echo -e "  ${CYAN}-h, --help${RESET}                   Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo -e "  ${GRAY}$(basename "$0")${RESET}                          # Run in interactive mode"
    echo -e "  ${GRAY}$(basename "$0") -d cloudzy -s all${RESET}        # Process all cloudzy servers"
    echo -e "  ${GRAY}$(basename "$0") -d arvan -s 1,3,5${RESET}        # Process 1st, 3rd, and 5th arvan servers"
    echo -e "  ${GRAY}$(basename "$0") --datacenter azma --servers 2,4${RESET}    # Process 2nd and 4th azma servers"
    echo ""
    exit 0
}

# Initialize variables for command-line arguments
DATACENTER=""
SERVERS=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_usage
            ;;
        -d|--datacenter)
            DATACENTER="$2"
            shift 2
            ;;
        --datacenter=*)
            DATACENTER="${key#*=}"
            shift
            ;;
        -s|--servers)
            SERVERS="$2"
            shift 2
            ;;
        --servers=*)
            SERVERS="${key#*=}"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}"
            show_usage
            ;;
    esac
done

# Check if servers.conf exists
if [ ! -f "$SERVERS_CONF" ]; then
    echo -e "${RED}Error: servers.conf file not found at $SERVERS_CONF${RESET}"
    exit 1
fi

# Get list of datacenters
datacenters=($(awk -F'|' '{ print $1 }' "$SERVERS_CONF" | sort -u))

# Datacenter selection
if [ -z "$DATACENTER" ]; then
    # Interactive mode - prompt for datacenter
    print_header "Datacenter Selection"
    echo -e "${BOLD}Available datacenters:${RESET}"
    echo ""
    
    for i in "${!datacenters[@]}"; do
        echo -e "  ${CYAN}${BOLD}$((i+1))${RESET} ${GRAY}•${RESET} ${datacenters[$i]}"
    done
    
    echo ""
    read -p "$(echo -e "${BLUE}Select datacenter ${RESET}[1-${#datacenters[@]}]${BLUE}: ${RESET}")" dc_choice
    if ! [[ "$dc_choice" =~ ^[0-9]+$ ]] || [ "$dc_choice" -lt 1 ] || [ "$dc_choice" -gt "${#datacenters[@]}" ]; then
        echo -e "${RED}Invalid selection. Exiting.${RESET}"
        exit 1
    fi
    SELECTED_DC="${datacenters[$((dc_choice-1))]}"
else
    # Automated mode - use provided datacenter
    SELECTED_DC=""
    for dc in "${datacenters[@]}"; do
        if [ "$dc" = "$DATACENTER" ]; then
            SELECTED_DC="$dc"
            break
        fi
    done
    
    if [ -z "$SELECTED_DC" ]; then
        echo -e "${RED}Error: Datacenter '$DATACENTER' not found in servers.conf${RESET}"
        echo -e "${GRAY}Available datacenters: ${RESET}${datacenters[*]}"
        exit 1
    fi
fi

echo ""
echo -e "${BOLD}${GREEN}✓ Selected datacenter: ${RESET}${BLUE}$SELECTED_DC${RESET}"

# Get servers for selected datacenter
servers=($(awk -F'|' -v dc="$SELECTED_DC" '$1 == dc { print $2 }' "$SERVERS_CONF"))

# Server selection
selected_indices=()

if [ -z "$SERVERS" ]; then
    # Interactive mode - prompt for servers
    print_header "Server Selection"
    echo -e "${BOLD}Available VMs in ${BLUE}$SELECTED_DC${RESET} datacenter:${RESET}"
    echo ""
    
    for i in "${!servers[@]}"; do
        echo -e "  ${CYAN}${BOLD}$((i+1))${RESET} ${GRAY}•${RESET} ${servers[$i]}"
    done
    echo -e "  ${CYAN}${BOLD}$((${#servers[@]}+1))${RESET} ${GRAY}•${RESET} all"
    
    echo ""
    read -p "$(echo -e "${BLUE}Choose destination VM(s) ${RESET}(e.g., 246 for multiple or '${#servers[@]}+1' for all)${BLUE}: ${RESET}")" server_choice
    
    # Process interactive selection
    if [ "$server_choice" == "$((${#servers[@]}+1))" ] || [ "$server_choice" == "all" ]; then
        # All servers selected
        for i in "${!servers[@]}"; do
            selected_indices+=($i)
        done
    else
        # Process individual digits for multiple selection
        for (( i=0; i<${#server_choice}; i++ )); do
            digit=${server_choice:$i:1}
            if [[ "$digit" =~ ^[0-9]$ ]] && [ "$digit" -ge 1 ] && [ "$digit" -le "${#servers[@]}" ]; then
                selected_indices+=($((digit-1)))
            fi
        done
    fi
else
    # Automated mode - use provided servers
    if [ "$SERVERS" = "all" ]; then
        # All servers selected
        for i in "${!servers[@]}"; do
            selected_indices+=($i)
        done
    else
        # Process comma-separated list of server numbers
        IFS=',' read -ra SERVER_NUMS <<< "$SERVERS"
        for num in "${SERVER_NUMS[@]}"; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#servers[@]}" ]; then
                selected_indices+=($((num-1)))
            else
                echo -e "${YELLOW}Warning: Invalid server number '$num' - skipping${RESET}"
            fi
        done
    fi
fi

# Check if at least one server was selected
if [ ${#selected_indices[@]} -eq 0 ]; then
    echo -e "${RED}No valid servers selected. Exiting.${RESET}"
    exit 1
fi

# Display selected servers
print_header "Operation Summary"
echo -e "${BOLD}Selected servers:${RESET}"
for idx in "${selected_indices[@]}"; do
    echo -e "  ${GREEN}•${RESET} ${servers[$idx]}"
done

# Create temporary directory for SSH control sockets
SSH_CONTROL_DIR=$(mktemp -d)
trap 'rm -rf "$SSH_CONTROL_DIR"' EXIT

# Create the network detection script once
NETWORK_DETECT_SCRIPT=$(cat <<'EOF'
#!/bin/bash
CURRENT_IP=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)
if [[ "$CURRENT_IP" == 172.20.* ]]; then
    echo "internal"
else
    echo "external"
fi
EOF
)

# Create the update script template once
UPDATE_SCRIPT_TEMPLATE=$(cat <<'EOF'
#!/bin/bash

# Configure proxy settings based on network type
SHOULD_USE_PROXY="__SHOULD_USE_PROXY__"
DEST_ENV_FILE="__DEST_ENV_FILE__"

echo "Setting proxy to: $SHOULD_USE_PROXY"

# Process the proxy settings in system*.edn files
for dir in $HOME/van-buren-*; do
    if [ -d "$dir" ]; then
        find "$dir" -name "system*.edn" | while read file; do
            echo "Processing: $file"
            
            if [ "$SHOULD_USE_PROXY" = "true" ]; then
                sed -i 's/\(:use-proxy?[[:space:]]*\)false/\1true/g' "$file"
                sed -i 's/\(Set-Proxy?[[:space:]]*\)false/\1true/g' "$file"
            else
                sed -i 's/\(:use-proxy?[[:space:]]*\)true/\1false/g' "$file"
                sed -i 's/\(Set-Proxy?[[:space:]]*\)true/\1false/g' "$file"
            fi
        done
    fi
done

# Ensure the environment file is sourced in multiple places
if ! grep -q "source /etc/profile.d/$DEST_ENV_FILE" $HOME/.bashrc; then
    echo "Adding source command to .bashrc"
    echo "source /etc/profile.d/$DEST_ENV_FILE" >> $HOME/.bashrc
fi

if ! grep -q "source /etc/profile.d/$DEST_ENV_FILE" $HOME/.profile 2>/dev/null; then
    echo "Adding source command to .profile"
    echo "source /etc/profile.d/$DEST_ENV_FILE" >> $HOME/.profile
fi

echo "Environment and proxy settings updated."
EOF
)

# Destination environment filename
DEST_ENV_FILE="hermes-env.sh"

# Prepare temporary files for the environments
TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/internal" "$TEMP_DIR/external"
cp "$HOME/ansible/env/envs" "$TEMP_DIR/internal/envs"
cp "$HOME/ansible/env/newpin/envs" "$TEMP_DIR/external/envs"

# Prepare the environment files
for env_file in "$TEMP_DIR/internal/envs" "$TEMP_DIR/external/envs"; do
    # Add shebang if missing
    if ! grep -q "#!/bin/bash" "$env_file"; then
        sed -i "1i#!/bin/bash" "$env_file"
    fi
    # Convert variables to use export
    sed -i "s/^[[:space:]]*\([A-Za-z0-9_]*=\)/export \1/g" "$env_file"
done

# Function to process a single server
process_server() {
    local idx=$1
    local SELECTED_SERVER="${servers[$idx]}"
    local SERVER_INFO=$(grep "^$SELECTED_DC|$SELECTED_SERVER|" "$SERVERS_CONF")
    local DEST_IP=$(echo "$SERVER_INFO" | awk -F'|' '{ print $4 }')
    local DEST_USER=$(echo "$SERVER_INFO" | awk -F'|' '{ print $5 }')
    local DEST_PORT=$(echo "$SERVER_INFO" | awk -F'|' '{ print $6 }')
    local SSH_CONTROL="$SSH_CONTROL_DIR/$SELECTED_SERVER"
    local LOG_FILE="$TEMP_DIR/$SELECTED_SERVER.log"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') Starting processing for $SELECTED_SERVER" > "$LOG_FILE"
    
    # Setup SSH connection sharing
    ssh $SSH_OPTS -o ControlMaster=yes -o ControlPath="$SSH_CONTROL" -o ControlPersist=10m -p "$DEST_PORT" -n "${DEST_USER}@${DEST_IP}" true >> "$LOG_FILE" 2>&1
    
    # Detect network type, copy environment, and configure all in one SSH session
    {
        # Step 1: Detect network type
        echo "$(date '+%Y-%m-%d %H:%M:%S') Detecting network type for $SELECTED_SERVER" >> "$LOG_FILE"
        NETWORK_TYPE=$(ssh $SSH_OPTS -o ControlPath="$SSH_CONTROL" -p "$DEST_PORT" "${DEST_USER}@${DEST_IP}" "$NETWORK_DETECT_SCRIPT")
        echo "$(date '+%Y-%m-%d %H:%M:%S') Network type for $SELECTED_SERVER: $NETWORK_TYPE" >> "$LOG_FILE"
        
        # Step 2: Set variables based on network type
        if [ "$NETWORK_TYPE" = "internal" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') $SELECTED_SERVER: Internal network - Setting proxy to true" >> "$LOG_FILE"
            SHOULD_USE_PROXY=true
            ENV_SOURCE="$TEMP_DIR/internal/envs"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') $SELECTED_SERVER: External network - Setting proxy to false" >> "$LOG_FILE"
            SHOULD_USE_PROXY=false
            ENV_SOURCE="$TEMP_DIR/external/envs"
        fi
        
        # Step 3: Copy environment file using rsync with connection sharing
        echo "$(date '+%Y-%m-%d %H:%M:%S') Copying environment file to $SELECTED_SERVER" >> "$LOG_FILE"
        rsync -az --rsh="ssh $SSH_OPTS -o ControlPath=$SSH_CONTROL -p $DEST_PORT" "$ENV_SOURCE" "${DEST_USER}@${DEST_IP}:/tmp/envs" >> "$LOG_FILE" 2>&1
        
        # Step 4: Prepare update script with the correct variables
        UPDATE_SCRIPT=${UPDATE_SCRIPT_TEMPLATE//__SHOULD_USE_PROXY__/$SHOULD_USE_PROXY}
        UPDATE_SCRIPT=${UPDATE_SCRIPT//__DEST_ENV_FILE__/$DEST_ENV_FILE}
        
        # Step 5: Execute setup and configuration in a single SSH session
        echo "$(date '+%Y-%m-%d %H:%M:%S') Setting up environment and configuring proxy for $SELECTED_SERVER" >> "$LOG_FILE"
        
        ssh $SSH_OPTS -o ControlPath="$SSH_CONTROL" -p "$DEST_PORT" "${DEST_USER}@${DEST_IP}" "
            # Move the environment file to the final location
            sudo cp /tmp/envs /etc/profile.d/$DEST_ENV_FILE && 
            sudo chmod 755 /etc/profile.d/$DEST_ENV_FILE &&
            
            # Source the environment file immediately
            source /etc/profile.d/$DEST_ENV_FILE &&
            
            # Export variables to make them immediately available
            export \$(grep -v '^#' /etc/profile.d/$DEST_ENV_FILE | cut -d= -f1) &&
            
            # Execute the update script to configure proxy settings
            $UPDATE_SCRIPT &&
            
            # Verify environment variables
            echo 'Verifying environment variables:' &&
            env | grep -E '^(HTTP_PROXY|HTTPS_PROXY|NO_PROXY|http_proxy|https_proxy|no_proxy)'
        " >> "$LOG_FILE" 2>&1
        
        # Close SSH connection sharing
        ssh $SSH_OPTS -o ControlPath="$SSH_CONTROL" -O exit "${DEST_USER}@${DEST_IP}" >> "$LOG_FILE" 2>&1
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') Completed processing for $SELECTED_SERVER" >> "$LOG_FILE"
        echo -e "${GREEN}✓${RESET} Completed: ${BLUE}$SELECTED_SERVER${RESET}" # Output to main console
    } &
    
    # Store the PID for monitoring
    echo $! >> "$TEMP_DIR/pids"
}

# Clear any existing PID file
rm -f "$TEMP_DIR/pids"
touch "$TEMP_DIR/pids"

# Process servers in parallel, but limit concurrency
echo -e "${GRAY}$(printf '%.0s─' $(seq 1 50))${RESET}"
echo -e "${BOLD}Processing servers in parallel ${GRAY}(max $MAX_PARALLEL at once)${RESET}..."
echo -e "${GRAY}$(printf '%.0s─' $(seq 1 50))${RESET}"

active_jobs=0
for idx in "${selected_indices[@]}"; do
    # Check if we're at max capacity
    while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
        # Show a simple spinner while waiting
        echo -ne "${GRAY}Waiting for available slot...${RESET}\r"
        sleep 0.5
    done
    
    # Start processing this server
    echo -e "${CYAN}⟳${RESET} Starting: ${BLUE}${servers[$idx]}${RESET}"
    process_server $idx
    
    # Brief pause to prevent race conditions
    sleep 0.2
done

# Wait for all background processes to complete
echo -e "\n${BOLD}Waiting for all processes to complete...${RESET}"

# Simple spinner while waiting for background processes
spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
i=0
while [ $(jobs -r | wc -l) -gt 0 ]; do
    echo -ne "\r${CYAN}${spin[$i]}${RESET} ${GRAY}Completing remaining tasks...${RESET}"
    i=$(( (i+1) % 10 ))
    sleep 0.1
done
echo -e "\r${GREEN}✓${RESET} ${BOLD}All tasks completed${RESET}      "

# Display final results
print_header "Operation Complete"
echo -e "${BOLD}${GREEN}✓ All operations completed for selected servers.${RESET}"

# Output logs from all servers
print_header "Operation Summary"
for idx in "${selected_indices[@]}"; do
    SERVER="${servers[$idx]}"
    echo -e "${BOLD}${BLUE}$SERVER${RESET}"
    echo -e "${GRAY}$(printf '%.0s─' $(seq 1 30))${RESET}"
    
    # Parse the log to extract network type and proxy setting
    NETWORK_TYPE=$(grep "Network type" "$TEMP_DIR/$SERVER.log" | tail -1 | awk -F': ' '{print $2}')
    PROXY_SETTING=$(grep "Setting proxy" "$TEMP_DIR/$SERVER.log" | tail -1 | awk -F': ' '{print $2}')
    
    if [ "$NETWORK_TYPE" = "internal" ]; then
        echo -e "  ${GRAY}Network:${RESET} ${CYAN}Internal${RESET}"
    else
        echo -e "  ${GRAY}Network:${RESET} ${BLUE}External${RESET}"
    fi
    
    if [ "$PROXY_SETTING" = "true" ]; then
        echo -e "  ${GRAY}Proxy:${RESET}   ${GREEN}Enabled${RESET}"
    else
        echo -e "  ${GRAY}Proxy:${RESET}   ${YELLOW}Disabled${RESET}"
    fi
    
    echo -e "  ${GRAY}Status:${RESET}  ${GREEN}Completed${RESET}"
    echo ""
done

echo ""
echo -e "${GRAY}NOTE: For the environment variables to be fully available in all new sessions,${RESET}"
echo -e "${GRAY}users may need to log out and log back in.${RESET}"

# Clean up
rm -rf "$TEMP_DIR"