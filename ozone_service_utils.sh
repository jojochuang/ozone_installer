#!/bin/bash

# Ozone Service Utilities
# Common functions for managing Ozone services across multiple scripts
# This script should be sourced by other scripts that manage Ozone services

# Function to generate the remote environment setup script
# This script will be executed on the remote host via SSH
# Parameters:
#   $1 - OZONE_CONF_DIR (optional, defaults to /opt/ozone/conf)
generate_ozone_env_setup() {
    local conf_dir="${1:-/opt/ozone/conf}"
    
    cat << 'EOF_ENV'
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
        export OZONE_CONF_DIR=CONF_DIR_PLACEHOLDER
        export PATH="$OZONE_HOME/bin:$PATH"

        # Find and use the actual JAVA_HOME if java is installed
        if command -v java >/dev/null 2>&1; then
            java_bin=$(which java)
            if [[ -L "$java_bin" ]]; then
                java_bin=$(readlink -f "$java_bin")
            fi
            export JAVA_HOME=$(dirname "$(dirname "$java_bin")")
        fi

        # Find ozone binary and set OZONE_HOME accordingly
        if command -v ozone >/dev/null 2>&1; then
            OZONE_CMD="ozone"
        elif [[ -f /opt/ozone/bin/ozone ]]; then
            OZONE_CMD="/opt/ozone/bin/ozone"
            export OZONE_HOME=/opt/ozone
        elif [[ -f /usr/local/ozone/bin/ozone ]]; then
            OZONE_CMD="/usr/local/ozone/bin/ozone"
            export OZONE_HOME=/usr/local/ozone
        else
            echo "ERROR: Ozone command not found"
            exit 1
        fi
EOF_ENV
    # Replace placeholder with actual conf_dir
    sed "s|CONF_DIR_PLACEHOLDER|$conf_dir|g"
}

# Function to execute a command on a remote host with Ozone environment setup
# Parameters:
#   $1 - host
#   $2 - OZONE_CONF_DIR (optional)
#   $3 - command to execute (will have access to $OZONE_CMD)
execute_remote_ozone_command() {
    local host="$1"
    local conf_dir="${2:-/opt/ozone/conf}"
    local remote_command="$3"
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    local env_setup
    env_setup=$(generate_ozone_env_setup "$conf_dir")
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        $env_setup
        
        $remote_command
    "
}

# Function to generate environment setup for a service with conf dir
# This returns the environment setup script that can be used in heredocs
# Parameters:
#   $1 - service name (scm, om, datanode, recon, etc.) - used to determine conf dir
get_service_env_setup() {
    local service="$1"
    local conf_dir="/opt/ozone/conf/$service"
    
    generate_ozone_env_setup "$conf_dir"
}
