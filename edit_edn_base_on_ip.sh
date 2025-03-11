#!/bin/bash

# Get script directory and config paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFO_PATH="$(dirname "$0")/Info"
SERVERS_CONF="$INFO_PATH/servers.conf"
MAX_PARALLEL=6  # Maximum number of parallel processes
SSH_OPTS="-o StrictHostKeyChecking=no"  # SSH options for automation

# Define usage function
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -d, --datacenter DATACENTER  Specify the datacenter name
  -s, --servers SERVER_LIST    Specify servers to process (comma-separated numbers or "all")
  -h, --help                   Show this help message

Examples:
  $(basename "$0")                          # Run in interactive mode
  $(basename "$0") -d cloudzy -s all        # Process all cloudzy servers
  $(basename "$0") -d arvan -s 1,3,5        # Process 1st, 3rd, and 5th arvan servers
  $(basename "$0") --datacenter azma --servers 2,4    # Process 2nd and 4th azma servers

EOF
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
            echo "Unknown option: $1"
            show_usage
            ;;
    esac
done

# Check if servers.conf exists
if [ ! -f "$SERVERS_CONF" ]; then
    echo "Error: servers.conf file not found at $SERVERS_CONF"
    exit 1
fi

# Get list of datacenters
datacenters=($(awk -F'|' '{ print $1 }' "$SERVERS_CONF" | sort -u))

# Datacenter selection
if [ -z "$DATACENTER" ]; then
    # Interactive mode - prompt for datacenter
    echo "Available datacenters:"
    for i in "${!datacenters[@]}"; do
        echo "$((i+1)). ${datacenters[$i]}"
    done

    read -p "Select datacenter (1-${#datacenters[@]}): " dc_choice
    if ! [[ "$dc_choice" =~ ^[0-9]+$ ]] || [ "$dc_choice" -lt 1 ] || [ "$dc_choice" -gt "${#datacenters[@]}" ]; then
        echo "Invalid selection. Exiting."
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
        echo "Error: Datacenter '$DATACENTER' not found in servers.conf"
        echo "Available datacenters: ${datacenters[*]}"
        exit 1
    fi
fi

echo "Selected datacenter: $SELECTED_DC"

# Get servers for selected datacenter
servers=($(awk -F'|' -v dc="$SELECTED_DC" '$1 == dc { print $2 }' "$SERVERS_CONF"))

# Server selection
selected_indices=()

if [ -z "$SERVERS" ]; then
    # Interactive mode - prompt for servers
    echo "Available VMs in $SELECTED_DC datacenter:"
    for i in "${!servers[@]}"; do
        echo "$((i+1)). ${servers[$i]}"
    done
    echo "$((${#servers[@]}+1)). all"
    
    read -p "Choose destination VM(s) (e.g., 246 for multiple or '${#servers[@]}+1' for all): " server_choice
    
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
                echo "Warning: Invalid server number '$num' - skipping"
            fi
        done
    fi
fi

# Check if at least one server was selected
if [ ${#selected_indices[@]} -eq 0 ]; then
    echo "No valid servers selected. Exiting."
    exit 1
fi

# Display selected servers
echo "Selected servers:"
for idx in "${selected_indices[@]}"; do
    echo "- ${servers[$idx]}"
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
        echo "✓ Completed: $SELECTED_SERVER" # Output to main console
    } &
    
    # Store the PID for monitoring
    echo $! >> "$TEMP_DIR/pids"
}

# Clear any existing PID file
rm -f "$TEMP_DIR/pids"
touch "$TEMP_DIR/pids"

# Process servers in parallel, but limit concurrency
echo "Processing servers in parallel (max $MAX_PARALLEL at once)..."
active_jobs=0
for idx in "${selected_indices[@]}"; do
    # Check if we're at max capacity
    while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
        # Wait for any job to finish
        sleep 0.5
    done
    
    # Start processing this server
    echo "Starting: ${servers[$idx]}"
    process_server $idx
    
    # Brief pause to prevent race conditions
    sleep 0.2
done

# Wait for all background processes to complete
echo "Waiting for all processes to complete..."
wait $(cat "$TEMP_DIR/pids")

# Display final results
echo ""
echo "==============================================="
echo "All operations completed for selected servers."
echo "==============================================="

# Output logs from all servers
echo "Summary of operations:"
for idx in "${selected_indices[@]}"; do
    SERVER="${servers[$idx]}"
    echo ""
    echo "--- Summary for $SERVER ---"
    grep -E "Network type|Setting proxy|Completed processing" "$TEMP_DIR/$SERVER.log"
done

echo ""
echo "NOTE: For the environment variables to be fully available in all new sessions, users may need to log out and log back in."

# Clean up
rm -rf "$TEMP_DIR"