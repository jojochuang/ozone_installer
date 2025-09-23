#!/bin/bash

# Start Ozone Services Script
# This script starts Ozone services in detached mode and waits for safe mode exit

set -e

# Configuration file path
CONFIG_FILE="$(dirname "$0")/ozone_installer.conf"

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

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
        export PATH="$OZONE_HOME/bin:$PATH"

        # Find and use the actual JAVA_HOME if java is installed
        if command -v java >/dev/null 2>&1; then
            java_bin=$(which java)
            if [[ -L "$java_bin" ]]; then
                java_bin=$(readlink -f "$java_bin")
            fi
            export JAVA_HOME=$(dirname "$(dirname "$java_bin")")
        fi

        # Check if ozone command is available
        if command -v ozone >/dev/null 2>&1; then
            echo "Ozone command found: $(which ozone)"
            ozone version
            exit 0
        elif [[ -f /opt/ozone/bin/ozone ]]; then
            echo "Ozone found at: /opt/ozone/bin/ozone"
            export OZONE_HOME=/opt/ozone
            /opt/ozone/bin/ozone version
            exit 0
        elif [[ -f /usr/local/ozone/bin/ozone ]]; then
            echo "Ozone found at: /usr/local/ozone/bin/ozone"
            export OZONE_HOME=/usr/local/ozone
            /usr/local/ozone/bin/ozone version
            exit 0
        else
            echo "ERROR: Ozone installation not found"
            echo "Please install Ozone before running this script"
            exit 1
        fi
    '
}

# Function to format SCM
format_scm() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Formatting SCM on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
        export OZONE_CONF_DIR=/opt/ozone/conf/scm
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

        # Format SCM if not already formatted
        echo "Formatting SCM with OZONE_CONF_DIR=$OZONE_CONF_DIR..."
        $OZONE_CMD scm --init || echo "SCM may already be formatted"
    '
}

# Function to format OM
format_om() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Formatting OM on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
        export OZONE_CONF_DIR=/opt/ozone/conf/om
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

        # Format OM if not already formatted
        echo "Formatting OM with OZONE_CONF_DIR=$OZONE_CONF_DIR..."
        $OZONE_CMD om --init || echo "OM may already be formatted"
    '
}

# Function to start SCM
start_scm() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting SCM on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
        export OZONE_CONF_DIR=/opt/ozone/conf/scm
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

        # Check if SCM is already running
        if ps aux | grep -v grep | grep "org.apache.hadoop.hdds.scm.server.StorageContainerManager" >/dev/null; then
            echo "SCM is already running"
        else
            echo "Starting SCM in background with OZONE_CONF_DIR=$OZONE_CONF_DIR..."
            nohup $OZONE_CMD --daemon start scm > /tmp/scm.log 2>&1 &
            sleep 5
            echo "SCM startup initiated"
        fi
    '
}

# Function to start OM
start_om() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting OM on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
        export OZONE_CONF_DIR=/opt/ozone/conf/om
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

        # Check if OM is already running
        if ps aux | grep -v grep | grep "org.apache.hadoop.ozone.om.OzoneManager" >/dev/null; then
            echo "OM is already running"
        else
            echo "Starting OM in background with OZONE_CONF_DIR=$OZONE_CONF_DIR..."
            nohup $OZONE_CMD --daemon start om > /tmp/om.log 2>&1 &
            sleep 5
            echo "OM startup initiated"
        fi
    '
}

# Function to start DataNode
start_datanode() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting DataNode on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
        export OZONE_CONF_DIR=/opt/ozone/conf/datanode
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

        # Check if DataNode is already running
        if ps aux | grep -v grep | grep "org.apache.hadoop.ozone.HddsDatanodeService" >/dev/null; then
            echo "DataNode is already running"
        else
            echo "Starting DataNode in background with OZONE_CONF_DIR=$OZONE_CONF_DIR..."
            nohup $OZONE_CMD --daemon start datanode > /tmp/datanode.log 2>&1 &
            sleep 5
            echo "DataNode startup initiated"
        fi
    '
}

# Function to start Recon
start_recon() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting Recon on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
        export OZONE_CONF_DIR=/opt/ozone/conf/recon
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

        # Check if Recon is already running
        if ps aux | grep -v grep | grep "org.apache.hadoop.ozone.recon.ReconServer" >/dev/null; then
            echo "Recon is already running"
        else
            # Ensure Recon directories exist with proper permissions
            echo "Ensuring Recon directories exist with proper permissions..."
            sudo mkdir -p /var/lib/hadoop-ozone/recon/data
            sudo mkdir -p /var/lib/hadoop-ozone/recon/scm/data
            sudo mkdir -p /var/lib/hadoop-ozone/recon/om/data
            sudo chown -R $(whoami):$(id -gn) /var/lib/hadoop-ozone/recon
            
            # Clean up stale RocksDB lock files before starting Recon
            echo "Cleaning up stale RocksDB lock files..."
            find /var/lib/hadoop-ozone/recon/data -name "LOCK" -type f -delete 2>/dev/null || true
            find /var/lib/hadoop-ozone/recon/scm/data -name "LOCK" -type f -delete 2>/dev/null || true
            find /var/lib/hadoop-ozone/recon/om/data -name "LOCK" -type f -delete 2>/dev/null || true
            
            echo "Starting Recon in background with OZONE_CONF_DIR=$OZONE_CONF_DIR..."
            nohup $OZONE_CMD --daemon start recon > /tmp/recon.log 2>&1 &
            sleep 5
            echo "Recon startup initiated"
        fi
    '
}

# Function to start S3 Gateway
start_s3gateway() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting S3 Gateway on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
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

        # Check if S3 Gateway is already running
        if pgrep -f "org.apache.hadoop.ozone.s3.Gateway" >/dev/null; then
            echo "S3 Gateway is already running"
        else
            echo "Starting S3 Gateway in background..."
            nohup $OZONE_CMD --daemon start s3g > /tmp/s3gateway.log 2>&1 &
            sleep 5
            echo "S3 Gateway startup initiated"
        fi
    '
}

# Function to start HttpFS
start_httpfs() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Starting HttpFS on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Set up environment variables
        export JAVA_HOME=/usr/lib/jvm/java
        export OZONE_HOME=/opt/ozone
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

        # Check if HttpFS is already running
        if pgrep -f "org.apache.hadoop.fs.http.server.HttpFSServerWebApp" >/dev/null; then
            echo "HttpFS is already running"
        else
            echo "Starting HttpFS in background..."
            nohup $OZONE_CMD --daemon start httpfs > /tmp/httpfs.log 2>&1 &
            sleep 5
            echo "HttpFS startup initiated"
        fi
    '
}

# Function to wait for safe mode exit
wait_for_safe_mode_exit() {
    local primary_host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    local max_attempts=60
    local attempt=0

    info "Waiting for Ozone to exit safe mode on $primary_host"

    while [[ $attempt -lt $max_attempts ]]; do
        log "Checking safe mode status (attempt $((attempt + 1))/$max_attempts)..."

        # Check safe mode status
        safe_mode_result=$(ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$primary_host" '
            # Set up environment variables
            export JAVA_HOME=/usr/lib/jvm/java
            export OZONE_HOME=/opt/ozone
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

            # Check safe mode
            $OZONE_CMD admin safemode status 2>/dev/null || echo "FAILED"
        ' 2>/dev/null || echo "FAILED")

        if [[ "$safe_mode_result" == *"OFF"* ]] || [[ "$safe_mode_result" == *"exited"* ]]; then
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

    local primary_host=$(echo "${HOSTS[0]}" | xargs)

    # Check Ozone installation on all hosts
    log "Checking Ozone installation on all hosts..."
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        if ! check_ozone_installation "$host"; then
            error "Ozone installation check failed on $host"
            exit 1
        fi
    done

    # Format SCM on primary host
    format_scm "$primary_host"

    # Format OM on primary host
    format_om "$primary_host"

    # Start SCM on primary host
    start_scm "$primary_host"

    # Wait a bit for SCM to start
    sleep 10

    # Start OM on primary host
    start_om "$primary_host"

    # Wait a bit for OM to start
    sleep 10

    # Start DataNodes on all hosts
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        start_datanode "$host"
    done

    # Start Recon on primary host
    start_recon "$primary_host"

    # Start S3 Gateway on primary host
    start_s3gateway "$primary_host"

    # Start HttpFS on primary host
    start_httpfs "$primary_host"

    # Wait for services to fully start
    log "Waiting for services to start up..."
    sleep 30

    # Check service status on all hosts
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        check_service_status "$host"
    done

    # Wait for safe mode exit
    wait_for_safe_mode_exit "$primary_host"

    log "Ozone services startup completed!"
    log ""
    log "Service URLs (on $primary_host):"
    log "  SCM Web UI: http://$primary_host:9876"
    log "  OM Web UI: http://$primary_host:9874"
    log "  Recon Web UI: http://$primary_host:9888"
    log "  S3 Gateway: http://$primary_host:9878"
    log "  HttpFS: http://$primary_host:14000"
    log ""
    log "To check cluster status:"
    log "  ozone admin safemode status"
    log "  ozone admin cluster info"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi