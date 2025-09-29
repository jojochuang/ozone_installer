#!/bin/bash

# Stop Ozone Services Script
# This script stops Ozone services by service type and/or host
# Usage: ./stop_ozone_services.sh [service] [host]
# If no arguments provided, stops all services on all hosts

set -e

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-$(dirname "$0")/multi-host.conf}"

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [service] [host]"
    echo ""
    echo "Stop Ozone services. If no arguments provided, stops all services on all hosts."
    echo ""
    echo "Parameters:"
    echo "  service   Optional. Service type to stop: scm, om, datanode, recon, s3gateway, httpfs"
    echo "  host      Optional. Specific host to stop services on"
    echo ""
    echo "Examples:"
    echo "  $0                    # Stop all services on all hosts"
    echo "  $0 scm               # Stop SCM service on all configured SCM hosts"
    echo "  $0 om host1          # Stop OM service on host1"
    echo "  $0 all host2         # Stop all services on host2"
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

# Function to stop SCM
stop_scm() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Stopping SCM on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Find SCM process and stop it
        scm_pids=$(ps aux | grep -v grep | grep "org.apache.hadoop.hdds.scm.server.StorageContainerManager" | awk "{print \$2}")
        if [[ -n "$scm_pids" ]]; then
            echo "Found SCM processes: $scm_pids"
            for pid in $scm_pids; do
                echo "Stopping SCM process $pid..."
                kill -TERM "$pid" || kill -KILL "$pid"
            done
            echo "SCM stopped successfully"
        else
            echo "SCM is not running"
        fi
    '
}

# Function to stop OM
stop_om() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Stopping OM on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Find OM process and stop it
        om_pids=$(ps aux | grep -v grep | grep "org.apache.hadoop.ozone.om.OzoneManager" | awk "{print \$2}")
        if [[ -n "$om_pids" ]]; then
            echo "Found OM processes: $om_pids"
            for pid in $om_pids; do
                echo "Stopping OM process $pid..."
                kill -TERM "$pid" || kill -KILL "$pid"
            done
            echo "OM stopped successfully"
        else
            echo "OM is not running"
        fi
    '
}

# Function to stop DataNode
stop_datanode() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Stopping DataNode on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Find DataNode process and stop it
        datanode_pids=$(ps aux | grep -v grep | grep "org.apache.hadoop.ozone.HddsDatanodeService" | awk "{print \$2}")
        if [[ -n "$datanode_pids" ]]; then
            echo "Found DataNode processes: $datanode_pids"
            for pid in $datanode_pids; do
                echo "Stopping DataNode process $pid..."
                kill -TERM "$pid" || kill -KILL "$pid"
            done
            echo "DataNode stopped successfully"
        else
            echo "DataNode is not running"
        fi
    '
}

# Function to stop Recon
stop_recon() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Stopping Recon on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Find Recon process and stop it
        recon_pids=$(ps aux | grep -v grep | grep "org.apache.hadoop.ozone.recon.ReconServer" | awk "{print \$2}")
        if [[ -n "$recon_pids" ]]; then
            echo "Found Recon processes: $recon_pids"
            for pid in $recon_pids; do
                echo "Stopping Recon process $pid..."
                kill -TERM "$pid" || kill -KILL "$pid"
            done
            echo "Recon stopped successfully"
        else
            echo "Recon is not running"
        fi
    '
}

# Function to stop S3 Gateway
stop_s3gateway() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Stopping S3 Gateway on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Find S3 Gateway process and stop it
        s3gateway_pids=$(pgrep -f "org.apache.hadoop.ozone.s3.Gateway")
        if [[ -n "$s3gateway_pids" ]]; then
            echo "Found S3 Gateway processes: $s3gateway_pids"
            for pid in $s3gateway_pids; do
                echo "Stopping S3 Gateway process $pid..."
                kill -TERM "$pid" || kill -KILL "$pid"
            done
            echo "S3 Gateway stopped successfully"
        else
            echo "S3 Gateway is not running"
        fi
    '
}

# Function to stop HttpFS
stop_httpfs() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Stopping HttpFS on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Find HttpFS process and stop it
        httpfs_pids=$(pgrep -f "org.apache.hadoop.fs.http.server.HttpFSServerWebApp")
        if [[ -n "$httpfs_pids" ]]; then
            echo "Found HttpFS processes: $httpfs_pids"
            for pid in $httpfs_pids; do
                echo "Stopping HttpFS process $pid..."
                kill -TERM "$pid" || kill -KILL "$pid"
            done
            echo "HttpFS stopped successfully"
        else
            echo "HttpFS is not running"
        fi
    '
}

# Function to stop all services on a specific host
stop_all_services_on_host() {
    local host=$1
    
    log "Stopping all services on $host..."
    
    # Stop services in reverse order (reverse of startup order)
    stop_httpfs "$host"
    stop_s3gateway "$host"
    stop_recon "$host"
    stop_datanode "$host"
    stop_om "$host"
    stop_scm "$host"
}

# Function to validate service host configurations
validate_service_hosts() {
    log "Validating service host configurations..."
    
    # Convert CLUSTER_HOSTS to array
    IFS=',' read -ra HOSTS <<< "$CLUSTER_HOSTS"
    
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

# Function to stop services on specified hosts
stop_service_on_hosts() {
    local service_name="$1"
    local hosts_list="$2"
    local stop_function="$3"
    
    if [[ -z "$hosts_list" ]]; then
        warn "No hosts specified for $service_name, skipping"
        return
    fi
    
    # Convert comma-separated list to array
    IFS=',' read -ra SERVICE_HOSTS <<< "$hosts_list"
    
    log "Stopping $service_name on hosts: $hosts_list"
    
    for host in "${SERVICE_HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        log "Stopping $service_name on $host..."
        "$stop_function" "$host"
    done
}

# Function to check if a host is valid in our cluster configuration
is_valid_host() {
    local target_host="$1"
    local all_hosts="$OM_HOSTS,$SCM_HOSTS,$DATANODE_HOSTS,$RECON_HOSTS,$S3GATEWAY_HOSTS,$HTTPFS_HOSTS"
    
    IFS=',' read -ra HOST_ARRAY <<< "$all_hosts"
    for host in "${HOST_ARRAY[@]}"; do
        host=$(echo "$host" | xargs)
        if [[ "$host" == "$target_host" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to get hosts for a service
get_service_hosts() {
    local service="$1"
    case "$service" in
        "scm"|"SCM")
            echo "$SCM_HOSTS"
            ;;
        "om"|"OM")
            echo "$OM_HOSTS"
            ;;
        "datanode"|"DataNode"|"DATANODE")
            echo "$DATANODE_HOSTS"
            ;;
        "recon"|"Recon"|"RECON")
            echo "$RECON_HOSTS"
            ;;
        "s3gateway"|"S3Gateway"|"S3GATEWAY")
            echo "$S3GATEWAY_HOSTS"
            ;;
        "httpfs"|"HttpFS"|"HTTPFS")
            echo "$HTTPFS_HOSTS"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Main function
main() {
    local service_arg="${1:-}"
    local host_arg="${2:-}"

    # Show help if requested
    if [[ "$service_arg" == "-h" || "$service_arg" == "--help" ]]; then
        show_usage
        exit 0
    fi

    log "Stopping Ozone Services"

    # Load configuration
    load_config
    validate_service_hosts

    # Convert CLUSTER_HOSTS to array
    IFS=',' read -ra HOSTS <<< "$CLUSTER_HOSTS"

    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        error "No hosts specified in CLUSTER_HOSTS"
        exit 1
    fi

    # Process arguments
    if [[ -z "$service_arg" && -z "$host_arg" ]]; then
        # No arguments - stop all services on all hosts
        log "No arguments provided. Stopping all services on all hosts..."
        
        # Stop services in reverse order (reverse of startup order)
        stop_service_on_hosts "HttpFS" "$HTTPFS_HOSTS" "stop_httpfs"
        stop_service_on_hosts "S3Gateway" "$S3GATEWAY_HOSTS" "stop_s3gateway"
        stop_service_on_hosts "Recon" "$RECON_HOSTS" "stop_recon"
        stop_service_on_hosts "DataNode" "$DATANODE_HOSTS" "stop_datanode"
        stop_service_on_hosts "OM" "$OM_HOSTS" "stop_om"
        stop_service_on_hosts "SCM" "$SCM_HOSTS" "stop_scm"
        
    elif [[ -n "$service_arg" && -z "$host_arg" ]]; then
        # Service specified but no host - stop service on all its configured hosts
        if [[ "$service_arg" == "all" || "$service_arg" == "ALL" ]]; then
            error "Service 'all' requires a specific host. Use '$0 all <host>' or '$0' to stop all services on all hosts"
            exit 1
        fi
        
        service_hosts=$(get_service_hosts "$service_arg")
        if [[ -z "$service_hosts" ]]; then
            error "Invalid service: $service_arg"
            error "Valid services: scm, om, datanode, recon, s3gateway, httpfs"
            exit 1
        fi
        
        log "Stopping $service_arg service on configured hosts: $service_hosts"
        case "$service_arg" in
            "scm"|"SCM")
                stop_service_on_hosts "SCM" "$service_hosts" "stop_scm"
                ;;
            "om"|"OM")
                stop_service_on_hosts "OM" "$service_hosts" "stop_om"
                ;;
            "datanode"|"DataNode"|"DATANODE")
                stop_service_on_hosts "DataNode" "$service_hosts" "stop_datanode"
                ;;
            "recon"|"Recon"|"RECON")
                stop_service_on_hosts "Recon" "$service_hosts" "stop_recon"
                ;;
            "s3gateway"|"S3Gateway"|"S3GATEWAY")
                stop_service_on_hosts "S3Gateway" "$service_hosts" "stop_s3gateway"
                ;;
            "httpfs"|"HttpFS"|"HTTPFS")
                stop_service_on_hosts "HttpFS" "$service_hosts" "stop_httpfs"
                ;;
        esac
        
    elif [[ -n "$service_arg" && -n "$host_arg" ]]; then
        # Both service and host specified
        if ! is_valid_host "$host_arg"; then
            error "Host $host_arg is not configured in the cluster"
            exit 1
        fi
        
        if [[ "$service_arg" == "all" || "$service_arg" == "ALL" ]]; then
            # Stop all services on specific host
            log "Stopping all services on $host_arg"
            stop_all_services_on_host "$host_arg"
        else
            # Stop specific service on specific host
            case "$service_arg" in
                "scm"|"SCM")
                    log "Stopping SCM on $host_arg"
                    stop_scm "$host_arg"
                    ;;
                "om"|"OM")
                    log "Stopping OM on $host_arg"
                    stop_om "$host_arg"
                    ;;
                "datanode"|"DataNode"|"DATANODE")
                    log "Stopping DataNode on $host_arg"
                    stop_datanode "$host_arg"
                    ;;
                "recon"|"Recon"|"RECON")
                    log "Stopping Recon on $host_arg"
                    stop_recon "$host_arg"
                    ;;
                "s3gateway"|"S3Gateway"|"S3GATEWAY")
                    log "Stopping S3Gateway on $host_arg"
                    stop_s3gateway "$host_arg"
                    ;;
                "httpfs"|"HttpFS"|"HTTPFS")
                    log "Stopping HttpFS on $host_arg"
                    stop_httpfs "$host_arg"
                    ;;
                *)
                    error "Invalid service: $service_arg"
                    error "Valid services: scm, om, datanode, recon, s3gateway, httpfs, all"
                    exit 1
                    ;;
            esac
        fi
    fi

    log "Ozone services stop operation completed!"
    log ""
    log "To check if services are stopped, you can run:"
    log "  ssh <host> 'ps aux | grep -v grep | grep ozone'"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi