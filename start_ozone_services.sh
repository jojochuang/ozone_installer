#!/bin/bash

# Start Ozone Services Script
# This script starts Ozone services in detached mode and waits for safe mode exit

set -e

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-$(dirname "$0")/multi-host.conf}"

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ozone_service_utils.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Source the configuration file
    source "$CONFIG_FILE"

    if [[ -z "$CLUSTER_HOSTS" ]]; then
        error "CLUSTER_HOSTS is empty in configuration file"
        exit 1
    fi
}

# Function to check if Ozone is installed
check_ozone_installation() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Checking Ozone installation on $host"

    local env_setup
    env_setup=$(generate_ozone_env_setup "/opt/ozone/conf")

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        $env_setup

        # Check if ozone command is available and show version
        echo \"Ozone command found: \$OZONE_CMD\"
        \$OZONE_CMD version
    "
}


# Function to start SCM
start_scm() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting SCM on $host"

    local env_setup
    env_setup=$(generate_ozone_env_setup "/opt/ozone/conf/scm")

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        $env_setup

        # Check if SCM is already running
        if ps aux | grep -v grep | grep \"org.apache.hadoop.hdds.scm.server.StorageContainerManager\" >/dev/null; then
            echo \"SCM is already running\"
        else
            echo \"Starting SCM in background with OZONE_CONF_DIR=\$OZONE_CONF_DIR...\"
            nohup \$OZONE_CMD --daemon start scm > /tmp/scm.log 2>&1 &
            sleep 5
            echo \"SCM startup initiated\"
        fi
    "
}

# Function to start OM
start_om() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting OM on $host"

    local env_setup
    env_setup=$(generate_ozone_env_setup "/opt/ozone/conf/om")

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        $env_setup

        # Check if OM is already running
        if ps aux | grep -v grep | grep \"org.apache.hadoop.ozone.om.OzoneManager\" >/dev/null; then
            echo \"OM is already running\"
        else
            echo \"Starting OM in background with OZONE_CONF_DIR=\$OZONE_CONF_DIR...\"
            nohup \$OZONE_CMD --daemon start om > /tmp/om.log 2>&1 &
            sleep 5
            echo \"OM startup initiated\"
        fi
    "
}

# Function to start DataNode
start_datanode() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting DataNode on $host"

    local env_setup
    env_setup=$(generate_ozone_env_setup "/opt/ozone/conf/datanode")

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        $env_setup

        # Ensure data directories exist with proper permissions before starting
        echo \"Ensuring DataNode data directories exist with proper permissions...\"
        sudo mkdir -p \"$OZONE_SCM_DATANODE_ID_DIR\" \"$DFS_CONTAINER_RATIS_DATANODE_STORAGE_DIR\" \"$HDDS_DATANODE_DIR\" \"$OZONE_DATANODE_METADATA_DIRS\"
        sudo chown -R \$(whoami):\$(id -gn) \"$OZONE_SCM_DATANODE_ID_DIR\" \"$DFS_CONTAINER_RATIS_DATANODE_STORAGE_DIR\" \"$HDDS_DATANODE_DIR\" \"$OZONE_DATANODE_METADATA_DIRS\"
        sudo chmod -R 750 \"$OZONE_SCM_DATANODE_ID_DIR\" \"$DFS_CONTAINER_RATIS_DATANODE_STORAGE_DIR\" \"$HDDS_DATANODE_DIR\" \"$OZONE_DATANODE_METADATA_DIRS\"

        # Check if DataNode is already running
        if ps aux | grep -v grep | grep \"org.apache.hadoop.ozone.HddsDatanodeService\" >/dev/null; then
            echo \"DataNode is already running\"
        else
            echo \"Starting DataNode in background with OZONE_CONF_DIR=\$OZONE_CONF_DIR...\"
            nohup \$OZONE_CMD --daemon start datanode > /tmp/datanode.log 2>&1 &
            sleep 5
            echo \"DataNode startup initiated\"
        fi
    "
}

# Function to start Recon
start_recon() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting Recon on $host"

    local env_setup
    env_setup=$(generate_ozone_env_setup "/opt/ozone/conf/recon")

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        $env_setup

        # Ensure data directories exist with proper permissions before starting
        echo \"Ensuring Recon data directories exist with proper permissions...\"
        sudo mkdir -p \"$OZONE_RECON_DB_DIR\" \"$OZONE_RECON_SCM_DB_DIRS\" \"$OZONE_RECON_OM_DB_DIR\" \"$OZONE_RECON_METADATA_DIRS\"
        sudo chown -R \$(whoami):\$(id -gn) \"$OZONE_RECON_DB_DIR\" \"$OZONE_RECON_SCM_DB_DIRS\" \"$OZONE_RECON_OM_DB_DIR\" \"$OZONE_RECON_METADATA_DIRS\"
        sudo chmod -R 750 \"$OZONE_RECON_DB_DIR\" \"$OZONE_RECON_SCM_DB_DIRS\" \"$OZONE_RECON_OM_DB_DIR\" \"$OZONE_RECON_METADATA_DIRS\"

        # Check if Recon is already running
        if ps aux | grep -v grep | grep \"org.apache.hadoop.ozone.recon.ReconServer\" >/dev/null; then
            echo \"Recon is already running\"
        else
            # Ensure Recon directories exist with proper permissions
            echo \"Ensuring Recon directories exist with proper permissions...\"
            sudo mkdir -p /var/lib/hadoop-ozone/recon/data
            sudo mkdir -p /var/lib/hadoop-ozone/recon/scm/data
            sudo mkdir -p /var/lib/hadoop-ozone/recon/om/data
            sudo chown -R \$(whoami):\$(id -gn) /var/lib/hadoop-ozone/recon

            echo \"Starting Recon in background with OZONE_CONF_DIR=\$OZONE_CONF_DIR...\"
            nohup \$OZONE_CMD --daemon start recon > /tmp/recon.log 2>&1 &
            sleep 5
            echo \"Recon startup initiated\"
        fi
    "
}

# Function to start S3 Gateway
start_s3gateway() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting S3 Gateway on $host"

    local env_setup
    env_setup=$(generate_ozone_env_setup "/opt/ozone/conf")

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        $env_setup

        # Check if S3 Gateway is already running
        if pgrep -f \"org.apache.hadoop.ozone.s3.Gateway\" >/dev/null; then
            echo \"S3 Gateway is already running\"
        else
            echo \"Starting S3 Gateway in background...\"
            nohup \$OZONE_CMD --daemon start s3g > /tmp/s3gateway.log 2>&1 &
            sleep 5
            echo \"S3 Gateway startup initiated\"
        fi
    "
}

# Function to start HttpFS
start_httpfs() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting HttpFS on $host"

    local env_setup
    env_setup=$(generate_ozone_env_setup "/opt/ozone/conf")

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        $env_setup

        # Check if HttpFS is already running
        if pgrep -f \"org.apache.hadoop.fs.http.server.HttpFSServerWebApp\" >/dev/null; then
            echo \"HttpFS is already running\"
        else
            echo \"Starting HttpFS in background...\"
            nohup \$OZONE_CMD --daemon start httpfs > /tmp/httpfs.log 2>&1 &
            sleep 5
            echo \"HttpFS startup initiated\"
        fi
    "
}

# Function to wait for safe mode exit
wait_for_safe_mode_exit() {
    local primary_host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    local max_attempts=60
    local attempt=0

    info "Waiting for Ozone to exit safe mode on $primary_host"

    local env_setup
    env_setup=$(generate_ozone_env_setup "/opt/ozone/conf")

    while [[ $attempt -lt $max_attempts ]]; do
        log "Checking safe mode status (attempt $((attempt + 1))/$max_attempts)..."

        # Check safe mode status
        safe_mode_result=$(ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$primary_host" "
            $env_setup

            # Check safe mode
            \$OZONE_CMD admin safemode status 2>/dev/null || echo \"FAILED\"
        " 2>/dev/null || echo "FAILED")

        if [[ "$safe_mode_result" == *"OFF"* ]] || [[ "$safe_mode_result" == *"exited"* ]] || [[ "$safe_mode_result" == *"out of safe mode"* ]]; then
            log "Ozone has successfully exited safe mode!"
            return 0
        elif [[ "$safe_mode_result" == "FAILED" ]]; then
            warn "Unable to check safe mode status, services may still be starting up"
        else
            info "Safe mode status: $safe_mode_result"
        fi

        sleep 10
        ((attempt++))
    done

    warn "Timeout waiting for safe mode exit after $((max_attempts * 10)) seconds"
    warn "You may need to manually check the status with: ozone admin safemode status"
    return 1
}

# Function to check service status
check_service_status() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Checking service status on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        echo "Checking running Ozone processes:"

        scm_pid=$(ps aux | grep -v grep | grep "org.apache.hadoop.hdds.scm.server.StorageContainerManager" | awk "{print \$2}" | head -1)
        if [[ -n "$scm_pid" ]]; then
            echo "  ✓ SCM is running (PID: $scm_pid)"
        else
            echo "  ✗ SCM is not running"
        fi

        om_pid=$(ps aux | grep -v grep | grep "org.apache.hadoop.ozone.om.OzoneManager" | awk "{print \$2}" | head -1)
        if [[ -n "$om_pid" ]]; then
            echo "  ✓ OM is running (PID: $om_pid)"
        else
            echo "  ✗ OM is not running"
        fi

        datanode_pid=$(ps aux | grep -v grep | grep "org.apache.hadoop.ozone.HddsDatanodeService" | awk "{print \$2}" | head -1)
        if [[ -n "$datanode_pid" ]]; then
            echo "  ✓ DataNode is running (PID: $datanode_pid)"
        else
            echo "  ✗ DataNode is not running"
        fi

        recon_pid=$(ps aux | grep -v grep | grep "org.apache.hadoop.ozone.recon.ReconServer" | awk "{print \$2}" | head -1)
        if [[ -n "$recon_pid" ]]; then
            echo "  ✓ Recon is running (PID: $recon_pid)"
        else
            echo "  ✗ Recon is not running"
        fi

        if pgrep -f "org.apache.hadoop.ozone.s3.Gateway" >/dev/null; then
            echo "  ✓ S3 Gateway is running (PID: $(pgrep -f "org.apache.hadoop.ozone.s3.Gateway"))"
        else
            echo "  ✗ S3 Gateway is not running"
        fi

        if pgrep -f "org.apache.hadoop.fs.http.server.HttpFSServerWebApp" >/dev/null; then
            echo "  ✓ HttpFS is running (PID: $(pgrep -f "org.apache.hadoop.fs.http.server.HttpFSServerWebApp"))"
        else
            echo "  ✗ HttpFS is not running"
        fi
    '
}

# Function to validate service host configurations
validate_service_hosts() {
    log "Validating service host configurations..."
    
    # Set defaults if service-specific hosts are not specified
    if [[ -z "$OM_HOSTS" ]]; then
        OM_HOSTS="${HOSTS[0]}"  # Default to first host
        log "OM_HOSTS not specified, defaulting to: $OM_HOSTS"
    fi
    if [[ -z "$SCM_HOSTS" ]]; then
        SCM_HOSTS="${HOSTS[0]}"  # Default to first host
        log "SCM_HOSTS not specified, defaulting to: $SCM_HOSTS"
    fi
    if [[ -z "$DATANODE_HOSTS" ]]; then
        DATANODE_HOSTS="$CLUSTER_HOSTS"  # Default to all hosts
        log "DATANODE_HOSTS not specified, defaulting to: $DATANODE_HOSTS"
    fi
    if [[ -z "$RECON_HOSTS" ]]; then
        RECON_HOSTS="${HOSTS[0]}"  # Default to first host
        log "RECON_HOSTS not specified, defaulting to: $RECON_HOSTS"
    fi
    if [[ -z "$S3GATEWAY_HOSTS" ]]; then
        S3GATEWAY_HOSTS="${HOSTS[0]}"  # Default to first host
        log "S3GATEWAY_HOSTS not specified, defaulting to: $S3GATEWAY_HOSTS"
    fi
    if [[ -z "$HTTPFS_HOSTS" ]]; then
        HTTPFS_HOSTS="${HOSTS[0]}"  # Default to first host
        log "HTTPFS_HOSTS not specified, defaulting to: $HTTPFS_HOSTS"
    fi
    
    log "Service distribution:"
    log "  OM hosts: $OM_HOSTS"
    log "  SCM hosts: $SCM_HOSTS"
    log "  DataNode hosts: $DATANODE_HOSTS"
    log "  Recon hosts: $RECON_HOSTS"
    log "  S3Gateway hosts: $S3GATEWAY_HOSTS"
    log "  HttpFS hosts: $HTTPFS_HOSTS"
}

# Function to start services on specified hosts
start_service_on_hosts() {
    local service_name="$1"
    local hosts_list="$2"
    local start_function="$3"
    local format_function="$4"
    
    if [[ -z "$hosts_list" ]]; then
        warn "No hosts specified for $service_name, skipping"
        return
    fi
    
    # Convert comma-separated list to array
    IFS=',' read -ra SERVICE_HOSTS <<< "$hosts_list"
    
    log "Starting $service_name on hosts: $hosts_list"
    
    for host in "${SERVICE_HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        log "Starting $service_name on $host..."
        
        # Format if format function is provided
        if [[ -n "$format_function" && "$format_function" != "none" ]]; then
            log "Formatting $service_name on $host..."
            "$format_function" "$host"
        fi
        
        # Start the service
        "$start_function" "$host"
    done
}
# Main function
main() {
    log "Starting Ozone Services"

    # Load configuration
    load_config

    # Convert CLUSTER_HOSTS to array
    IFS=',' read -ra HOSTS <<< "$CLUSTER_HOSTS"

    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        error "No hosts specified in CLUSTER_HOSTS"
        exit 1
    fi

    # Validate and set service host configurations
    validate_service_hosts

    # Check Ozone installation on all hosts
    log "Checking Ozone installation on all hosts..."
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        if ! check_ozone_installation "$host"; then
            error "Ozone installation check failed on $host"
            exit 1
        fi
    done

    # Start services in order (SCM first, then OM, then others)
    
    # Step 1: Start SCM on specified hosts. Do not format SCM.
    start_service_on_hosts "SCM" "$SCM_HOSTS" "start_scm" "none"
    
    # Wait for SCM to start
    log "Waiting for SCM to start..."
    sleep 15

    # Step 2: Start OM on specified hosts. Do not format OM.
    start_service_on_hosts "OM" "$OM_HOSTS" "start_om" "none"
    
    # Wait for OM to start
    log "Waiting for OM to start..."
    sleep 15

    # Step 3: Start DataNodes on specified hosts
    start_service_on_hosts "DataNode" "$DATANODE_HOSTS" "start_datanode" "none"

    # Step 4: Start other services
    start_service_on_hosts "Recon" "$RECON_HOSTS" "start_recon" "none"
    start_service_on_hosts "S3Gateway" "$S3GATEWAY_HOSTS" "start_s3gateway" "none"
    start_service_on_hosts "HttpFS" "$HTTPFS_HOSTS" "start_httpfs" "none"

    # Wait for services to fully start
    log "Waiting for services to start up..."
    sleep 30

    # Check service status on all hosts
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        check_service_status "$host"
    done

    # Wait for safe mode exit (use first OM host)
    IFS=',' read -ra OM_HOSTS_ARRAY <<< "$OM_HOSTS"
    local primary_om_host=$(echo "${OM_HOSTS_ARRAY[0]}" | xargs)
    wait_for_safe_mode_exit "$primary_om_host"

    log "Ozone services startup completed!"
    log ""
    log "Service URLs:"
    
    # Show URLs for all service hosts
    log "  OM Web UIs:"
    IFS=',' read -ra OM_HOSTS_ARRAY <<< "$OM_HOSTS"
    for host in "${OM_HOSTS_ARRAY[@]}"; do
        host=$(echo "$host" | xargs)
        log "    http://$host:9874"
    done
    
    log "  SCM Web UIs:"
    IFS=',' read -ra SCM_HOSTS_ARRAY <<< "$SCM_HOSTS"
    for host in "${SCM_HOSTS_ARRAY[@]}"; do
        host=$(echo "$host" | xargs)
        log "    http://$host:9876"
    done
    
    log "  DataNode Web UIs:"
    IFS=',' read -ra DATANODE_HOSTS_ARRAY <<< "$DATANODE_HOSTS"
    for host in "${DATANODE_HOSTS_ARRAY[@]}"; do
        host=$(echo "$host" | xargs)
        log "    http://$host:9882"
    done
    
    if [[ -n "$RECON_HOSTS" ]]; then
        log "  Recon Web UIs:"
        IFS=',' read -ra RECON_HOSTS_ARRAY <<< "$RECON_HOSTS"
        for host in "${RECON_HOSTS_ARRAY[@]}"; do
            host=$(echo "$host" | xargs)
            log "    http://$host:9888"
        done
    fi
    
    if [[ -n "$S3GATEWAY_HOSTS" ]]; then
        log "  S3 Gateway APIs:"
        IFS=',' read -ra S3GATEWAY_HOSTS_ARRAY <<< "$S3GATEWAY_HOSTS"
        for host in "${S3GATEWAY_HOSTS_ARRAY[@]}"; do
            host=$(echo "$host" | xargs)
            log "    http://$host:9878"
        done
    fi
    
    if [[ -n "$HTTPFS_HOSTS" ]]; then
        log "  HttpFS APIs:"
        IFS=',' read -ra HTTPFS_HOSTS_ARRAY <<< "$HTTPFS_HOSTS"
        for host in "${HTTPFS_HOSTS_ARRAY[@]}"; do
            host=$(echo "$host" | xargs)
            log "    http://$host:14000"
        done
    fi
    
    log ""
    log "To check cluster status:"
    log "  ozone admin safemode status"
    log "  ozone admin cluster info"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
