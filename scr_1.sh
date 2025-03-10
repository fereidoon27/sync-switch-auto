#!/bin/bash
# sc_1.sh: A simple script to get user input and print the results

# This function prompts for a datacenter and server(s) selection,
# storing the selections in the variables SELECTED_DC and SERVERS_SELECTED.
get_user_input() {
    # Simulated list of datacenters (in real use, these may come from a config file)
    local datacenters=("cloudzy" "arvan" "azma")
    
    # Prompt for datacenter if not provided via environment variable DATACENTER
    if [ -z "$DATACENTER" ]; then
        echo "Available Datacenters:"
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
        SELECTED_DC="$DATACENTER"
    fi

    # Simulate server list for the chosen datacenter
    if [ "$SELECTED_DC" == "cloudzy" ]; then
        servers=("server1" "server2" "server3")
    elif [ "$SELECTED_DC" == "arvan" ]; then
        servers=("arvan1" "arvan2" "arvan3")
    else
        servers=("azma1" "azma2" "azma3")
    fi

    # Prompt for server selection if not provided via environment variable SERVERS
    if [ -z "$SERVERS" ]; then
        echo "Available Servers in $SELECTED_DC:"
        for i in "${!servers[@]}"; do
            echo "$((i+1)). ${servers[$i]}"
        done
        echo "$(( ${#servers[@]}+1 )). all"
        read -p "Select server(s) (e.g., 13 for servers 1 and 3, or 'all'): " server_choice
        
        local selected_indices=()
        if [ "$server_choice" == "$(( ${#servers[@]}+1 ))" ] || [ "$server_choice" == "all" ]; then
            for i in "${!servers[@]}"; do
                selected_indices+=("$i")
            done
        else
            # Process each digit of the input string
            for (( i=0; i<${#server_choice}; i++ )); do
                digit="${server_choice:$i:1}"
                if [[ "$digit" =~ ^[0-9]$ ]] && [ "$digit" -ge 1 ] && [ "$digit" -le "${#servers[@]}" ]; then
                    selected_indices+=($((digit-1)))
                fi
            done
        fi
        
        local servers_selected=""
        for idx in "${selected_indices[@]}"; do
            servers_selected+="${servers[$idx]} "
        done
        SERVERS_SELECTED=$(echo "$servers_selected" | xargs)  # Trim any extra spaces
    else
        SERVERS_SELECTED="$SERVERS"
    fi

    # Print the selections
    echo "Selected Datacenter: $SELECTED_DC"
    echo "Selected Servers: $SERVERS_SELECTED"
}

# Main execution: call the function to get input and then display the results
get_user_input
