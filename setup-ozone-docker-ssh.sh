#!/bin/bash

# Docker Compose Multi-Host Ozone Setup with SSH Access
# This script sets up Docker containers that can be accessed via SSH as if they were remote hosts

set -e

# Load configuration from multi-host.conf
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/multi-host.conf}"

# Source configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

SSH_KEY_NAME="${SSH_PRIVATE_KEY_FILE:-rocky9_key}"
COMPOSE_PROJECT_NAME="ozone-cluster"
SSH_CONFIG_FILE="$HOME/.ssh/config"
SSH_CONFIG_BACKUP="$HOME/.ssh/config.backup.$(date +%s)"

echo "=== Ozone Docker Compose Multi-Host Setup with SSH Access ==="
echo "SSH key: $SSH_KEY_NAME"
echo "Docker Compose project: $COMPOSE_PROJECT_NAME"
echo "Configuration: $CONFIG_FILE"
echo

# Logging functions
error() {
    echo -e "\033[0;31m[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1\033[0m" >&2
}

# Check if Docker and Docker Compose are available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not installed or not in PATH"
    exit 1
fi

# Use modern docker compose if available, fallback to docker-compose
DOCKER_COMPOSE_CMD="docker compose"
if ! docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    exit 1
fi

# Function to cleanup existing containers and images
cleanup() {
    echo "Cleaning up existing containers and images..."
    $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME down --remove-orphans --volumes 2>/dev/null || true
    docker system prune -f --volumes 2>/dev/null || true
    echo "Cleanup completed"
}

# Function to generate SSH key pair if it doesn't exist
generate_ssh_key() {
    if [ ! -f "$SSH_KEY_NAME" ]; then
        echo "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_NAME" -N "" -C "rocky9-container-access"
        echo "SSH key pair generated: $SSH_KEY_NAME and $SSH_KEY_NAME.pub"
    else
        echo "SSH key pair already exists: $SSH_KEY_NAME"
    fi
}

# Function to start all containers
start_containers() {
    echo "Starting Ozone multi-container cluster..."
    $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME up -d --build
    echo "All containers started successfully"
}

# Function to setup SSH access for all containers
setup_ssh_access() {
    echo "Setting up SSH access for all containers..."

    # Wait for containers to be ready
    echo "Waiting for containers to be ready..."
    sleep 10

    # List of all containers
    containers=(
        "ozone-om1"
        "ozone-om2"
        "ozone-om3"
        "ozone-scm1"
        "ozone-scm2"
        "ozone-scm3"
        "ozone-recon"
        "ozone-s3gateway"
        "ozone-datanode1"
        "ozone-datanode2"
        "ozone-datanode3"
        "ozone-httpfs"
        "ozone-prometheus"
        "ozone-grafana"
        "ozone-client"
    )

    for container_name in "${containers[@]}"; do
        echo "Setting up SSH for $container_name..."
        
        # Copy the public key to the container
        docker cp "$SSH_KEY_NAME.pub" "$container_name:/tmp/authorized_keys"

        # Set up the authorized_keys file in the container
        docker exec "$container_name" bash -c "
            mkdir -p /home/rocky/.ssh
            cp /tmp/authorized_keys /home/rocky/.ssh/authorized_keys
            chown rocky:rocky /home/rocky/.ssh/authorized_keys
            chmod 600 /home/rocky/.ssh/authorized_keys
            rm /tmp/authorized_keys
        "
        
        # For the client container, also copy the private key so it can SSH to other containers
        if [[ "$container_name" == "ozone-client" ]]; then
            echo "Setting up client container with private key for outbound SSH..."
            docker cp "$SSH_KEY_NAME" "$container_name:/tmp/id_rsa"
            docker exec "$container_name" bash -c "
                cp /tmp/id_rsa /home/rocky/.ssh/id_rsa
                chown rocky:rocky /home/rocky/.ssh/id_rsa
                chmod 600 /home/rocky/.ssh/id_rsa
                rm /tmp/id_rsa
                
                # Create SSH config for easy access to other containers
                cat > /home/rocky/.ssh/config << 'EOF'
# SSH config for accessing other Ozone containers
Host om1
    HostName om1
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host om2
    HostName om2
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host om3
    HostName om3
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host scm1
    HostName scm1
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host scm2
    HostName scm2
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host scm3
    HostName scm3
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host recon
    HostName recon
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host s3gateway
    HostName s3gateway
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host datanode1
    HostName datanode1
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host datanode2
    HostName datanode2
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host datanode3
    HostName datanode3
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host httpfs
    HostName httpfs
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host prometheus
    HostName prometheus
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host grafana
    HostName grafana
    User rocky
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
                chown rocky:rocky /home/rocky/.ssh/config
                chmod 600 /home/rocky/.ssh/config
            "
        fi
    done

    echo "SSH access configured successfully for all containers"
}

# Function to setup SSH config for easy access
setup_ssh_config() {
    echo "Setting up SSH configuration..."
    
    # Backup existing SSH config
    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        cp "$SSH_CONFIG_FILE" "$SSH_CONFIG_BACKUP"
        echo "Backed up existing SSH config to $SSH_CONFIG_BACKUP"
    fi
    
    # Prepare SSH config directory
    mkdir -p "$HOME/.ssh"
    
    # Function to get port for container name (bash 3.x compatible)
    get_container_port() {
        case "$1" in
            "om1") echo "2222" ;;
            "om2") echo "2223" ;;
            "om3") echo "2224" ;;
            "scm1") echo "2225" ;;
            "scm2") echo "2226" ;;
            "scm3") echo "2227" ;;
            "recon") echo "2228" ;;
            "s3gateway") echo "2229" ;;
            "datanode1") echo "2230" ;;
            "datanode2") echo "2231" ;;
            "datanode3") echo "2232" ;;
            "httpfs") echo "2233" ;;
            "prometheus") echo "2234" ;;
            "grafana") echo "2235" ;;
            "client") echo "2236" ;;
            *) echo "" ;;
        esac
    }
    
    # Container list (space-separated string for iteration)
    container_list="om1 om2 om3 scm1 scm2 scm3 recon s3gateway datanode1 datanode2 datanode3 httpfs prometheus grafana client"
    
    # Create or update SSH config file with proper permissions
    if [[ ! -f "$SSH_CONFIG_FILE" ]]; then
        touch "$SSH_CONFIG_FILE"
        chmod 600 "$SSH_CONFIG_FILE"
    fi
    
    # Ensure SSH config file is writable
    if [[ ! -w "$SSH_CONFIG_FILE" ]]; then
        chmod 600 "$SSH_CONFIG_FILE"
        if [[ ! -w "$SSH_CONFIG_FILE" ]]; then
            echo "Error: Cannot write to SSH config file $SSH_CONFIG_FILE"
            echo "Please check file permissions or run with appropriate privileges"
            return 1
        fi
    fi
    
    # Remove existing ozone container entries from SSH config
    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        # Use a temporary file to avoid permission issues with sed -i
        temp_config=$(mktemp)
        if grep -q "# Ozone Docker Containers" "$SSH_CONFIG_FILE"; then
            sed '/# Ozone Docker Containers/,/# End Ozone Docker Containers/d' "$SSH_CONFIG_FILE" > "$temp_config"
            mv "$temp_config" "$SSH_CONFIG_FILE"
        fi
        rm -f "$temp_config" 2>/dev/null
    fi
    
    # Add SSH config entries for containers
    {
        echo ""
        echo "# Ozone Docker Containers"
        for container in $container_list; do
            port=$(get_container_port "$container")
            if [[ -n "$port" ]]; then
                echo "Host $container"
                echo "    HostName localhost"
                echo "    Port $port"
                echo "    User rocky"
                echo "    IdentityFile $(pwd)/$SSH_KEY_NAME"
                echo "    StrictHostKeyChecking no"
                echo "    UserKnownHostsFile /dev/null"
                echo ""
            fi
        done
        echo "# End Ozone Docker Containers"
    } >> "$SSH_CONFIG_FILE"
    
    # Ensure proper permissions on SSH config file
    chmod 600 "$SSH_CONFIG_FILE"
    
    echo "SSH configuration updated"
    echo "You can now SSH to containers using: ssh <container_name>"
    echo "Example: ssh om1, ssh scm1, ssh datanode1"
}

# Function to test container accessibility
test_container_access() {
    echo "Testing container SSH access..."

    # Test a few key containers
    test_containers=(
        "om1"
        "scm1"
        "datanode1"
        "recon"
        "client"
    )

    for container_name in "${test_containers[@]}"; do
        if ssh -o ConnectTimeout=10 "$container_name" "echo 'SSH access successful to $container_name!'" 2>/dev/null; then
            echo "✓ SSH access test passed for $container_name!"
        else
            echo "⚠ SSH access test failed for $container_name. Container may still be starting."
        fi
    done
}

# Function to install Ozone on all containers
install_ozone() {
    echo "Installing Ozone on all containers..."
    
    # Wait a bit more for containers to be fully ready
    echo "Waiting for containers to be fully ready..."
    sleep 5
    
    # Run the ozone installer with the appropriate config
    CONFIG_FILE="$CONFIG_FILE" ./ozone_installer.sh
    
    if [[ $? -eq 0 ]]; then
        echo "Ozone installation completed successfully"
    else
        error "Ozone installation failed"
        return 1
    fi
}

# Function to start Ozone services
start_ozone_services() {
    echo "Starting Ozone services..."
    
    # Run the start services script with the appropriate config
    CONFIG_FILE="$CONFIG_FILE" ./first_time_start_ozone_services.sh
    
    if [[ $? -eq 0 ]]; then
        echo "Ozone services started successfully"
    else
        error "Failed to start Ozone services"
        return 1
    fi
}

# Function to display connection information
show_connection_info() {
    echo
    echo "=== Ozone Docker Compose Cluster with SSH Access ==="
    echo
    echo "Container SSH Access:"
    echo "You can now SSH to containers as if they were remote hosts:"
    echo "  ssh om1, ssh om2, ssh om3"
    echo "  ssh scm1, ssh scm2, ssh scm3"
    echo "  ssh recon, ssh s3gateway, ssh httpfs"
    echo "  ssh datanode1, ssh datanode2, ssh datanode3"
    echo "  ssh prometheus, ssh grafana"
    echo "  ssh client"
    echo
    echo "Using ozone_installer.sh with containers:"
    echo "  If AUTO_INSTALL_OZONE=true, Ozone services should be running (default: false)"
    echo "  Check service status: ssh <container> 'ps aux | grep -i ozone | grep -v grep'"
    echo "  Check logs: ssh <container> 'ls -la /var/log/hadoop/'"
    echo
    echo "Manual Installation (if needed):"
    echo "  CONFIG_FILE=multi-host.conf ./ozone_installer.sh"
    echo "  CONFIG_FILE=multi-host.conf ./first_time_start_ozone_services.sh"
    echo
    echo "Container Details:"
    echo "  OM Containers: om1 (port 2222), om2 (port 2223), om3 (port 2224)"
    echo "  SCM Containers: scm1 (port 2225), scm2 (port 2226), scm3 (port 2227)"
    echo "  Service Containers: recon (port 2228), s3gateway (port 2229), httpfs (port 2233)"
    echo "  DataNode Containers: datanode1 (port 2230), datanode2 (port 2231), datanode3 (port 2232)"
    echo "  Observability: prometheus (port 2234), grafana (port 2235)"
    echo "  Client: client (port 2236)"
    echo
    echo "Cluster Management:"
    echo "  View container status: docker ps"
    echo "  View logs: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME logs <service>"
    echo "  Stop cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME stop"
    echo "  Start cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME start"
    echo "  Remove cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME down --volumes"
    echo
    echo "SSH Config: $SSH_CONFIG_FILE (backed up to $SSH_CONFIG_BACKUP)"
}

# Function to show cluster status
show_status() {
    echo "=== Ozone Cluster Status ==="
    $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME ps
}

# Function to cleanup SSH config
cleanup_ssh_config() {
    echo "Cleaning up SSH configuration..."
    if [[ -f "$SSH_CONFIG_BACKUP" ]]; then
        cp "$SSH_CONFIG_BACKUP" "$SSH_CONFIG_FILE"
        rm "$SSH_CONFIG_BACKUP"
        echo "SSH config restored from backup"
    elif [[ -f "$SSH_CONFIG_FILE" ]]; then
        sed -i.tmp '/# Ozone Docker Containers/,/# End Ozone Docker Containers/d' "$SSH_CONFIG_FILE"
        echo "Ozone container entries removed from SSH config"
    fi
}

# Function to connect to a specific container
connect_to_container() {
    local container_name="$1"
    local valid_containers="om1 om2 om3 scm1 scm2 scm3 recon s3gateway datanode1 datanode2 datanode3 httpfs prometheus grafana client"
    
    # Check if container name is valid
    local found=false
    for container in $valid_containers; do
        if [[ "$container" == "$container_name" ]]; then
            found=true
            break
        fi
    done
    
    if [[ "$found" != "true" ]]; then
        echo "Error: Unknown container '$container_name'"
        echo "Available containers: $valid_containers"
        exit 1
    fi

    echo "Connecting to $container_name..."
    ssh "$container_name"
}

# Main execution
main() {
    case "${1:-start}" in
        "start")
            echo "Starting Ozone multi-container cluster setup with SSH access..."
            cleanup
            generate_ssh_key
            start_containers
            setup_ssh_access
            setup_ssh_config
            test_container_access
            
            # Check if we should automatically install and start Ozone
            if [[ "${AUTO_INSTALL_OZONE:-false}" == "true" ]]; then
                echo ""
                echo "Installing and starting Ozone services automatically..."
                echo "To disable this step in the future, set AUTO_INSTALL_OZONE=false (or omit the variable)"
                echo ""
                
                install_ozone
                if [[ $? -eq 0 ]]; then
                    start_ozone_services
                    if [[ $? -eq 0 ]]; then
                        echo ""
                        echo "✓ Ozone cluster is now running with processes active!"
                        echo "  Log files should be available in /var/log/hadoop/ on each container"
                        echo "  Check service status with: ssh <container> 'ps aux | grep -i ozone'"
                    fi
                fi
            else
                echo ""
                echo "Automatic Ozone installation skipped (default behavior)"
                echo "To enable automatic installation, set AUTO_INSTALL_OZONE=true"
                echo "To install Ozone manually, run:"
                echo "  CONFIG_FILE=multi-host.conf ./ozone_installer.sh"
                echo "  CONFIG_FILE=multi-host.conf ./first_time_start_ozone_services.sh"
            fi
            
            show_connection_info
            ;;
        "stop")
            echo "Stopping Ozone cluster..."
            $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME stop
            echo "Cluster stopped"
            ;;
        "clean")
            echo "Cleaning up Ozone cluster..."
            cleanup
            cleanup_ssh_config
            echo "Cleanup completed"
            ;;
        "status")
            show_status
            ;;
        "connect")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 connect <container_name>"
                echo "Available containers: om1, om2, om3, scm1, scm2, scm3, recon, s3gateway, datanode1, datanode2, datanode3, httpfs, prometheus, grafana, client"
                exit 1
            fi
            connect_to_container "$2"
            ;;
        "info")
            show_connection_info
            ;;
        *)
            echo "Usage: $0 [start|stop|clean|status|connect <container>|info]"
            echo "  start               - Build and start the Ozone cluster with SSH access (default)"
            echo "                        Automatically installs and starts Ozone services"
            echo "  stop                - Stop the running cluster"
            echo "  clean               - Remove all containers, volumes, and SSH config"
            echo "  status              - Show cluster status"
            echo "  connect <container> - Connect to a specific container via SSH"
            echo "  info                - Show connection information"
            echo ""
            echo "Environment Variables:"
            echo "  AUTO_INSTALL_OZONE  - Set to 'true' to enable automatic Ozone installation (default: false)"
            echo "  CONFIG_FILE         - Override config file (default: multi-host.conf)"
            echo ""
            echo "Available containers for connect command:"
            echo "  om1, om2, om3, scm1, scm2, scm3, recon, s3gateway"
            echo "  datanode1, datanode2, datanode3, httpfs, prometheus, grafana, client"
            echo ""
            echo "Manual installation (if AUTO_INSTALL_OZONE=false):"
            echo "  CONFIG_FILE=multi-host.conf ./ozone_installer.sh"
            echo "  CONFIG_FILE=multi-host.conf ./first_time_start_ozone_services.sh"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"