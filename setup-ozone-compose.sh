#!/bin/bash

# Rocky9 Docker Compose Multi-Container Setup Script for Ozone
# This script creates multiple Rocky9 containers with SSH daemon configured for key-based authentication
# Services: 3 OM, 3 SCM, 1 Recon, 1 S3Gateway, 3 DataNode, 1 HttpFS containers

set -e

SSH_KEY_NAME="rocky9_key"
COMPOSE_PROJECT_NAME="ozone-cluster"

echo "=== Ozone Multi-Container Docker Compose Setup ==="
echo "SSH key: $SSH_KEY_NAME"
echo "Docker Compose project: $COMPOSE_PROJECT_NAME"
echo

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

    # List of all containers and their SSH ports
    containers=(
        "ozone-om1:2222"
        "ozone-om2:2223"
        "ozone-om3:2224"
        "ozone-scm1:2225"
        "ozone-scm2:2226"
        "ozone-scm3:2227"
        "ozone-recon:2228"
        "ozone-s3gateway:2229"
        "ozone-datanode1:2230"
        "ozone-datanode2:2231"
        "ozone-datanode3:2232"
        "ozone-httpfs:2233"
        "ozone-prometheus:2234"
        "ozone-grafana:2235"
    )

    for container_info in "${containers[@]}"; do
        container_name=$(echo "$container_info" | cut -d: -f1)
        port=$(echo "$container_info" | cut -d: -f2)
        
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
    done

    echo "SSH access configured successfully for all containers"
}

# Function to clean up old host keys from known_hosts
cleanup_known_hosts() {
    echo "Cleaning up old SSH host keys..."

    # Remove any existing entries for all SSH ports from known_hosts
    if [ -f ~/.ssh/known_hosts ]; then
        for port in {2222..2235}; do
            ssh-keygen -R "[localhost]:$port" 2>/dev/null || true
        done
        echo "Old host keys removed from known_hosts"
    fi
}

# Function to test SSH connections
test_ssh_connections() {
    echo "Testing SSH connections..."

    # Test a few key containers
    test_containers=(
        "ozone-om1:2222"
        "ozone-scm1:2225"
        "ozone-recon:2228"
        "ozone-datanode1:2230"
    )

    for container_info in "${test_containers[@]}"; do
        container_name=$(echo "$container_info" | cut -d: -f1)
        port=$(echo "$container_info" | cut -d: -f2)
        
        if ssh -i "$SSH_KEY_NAME" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -p "$port" rocky@localhost "echo 'SSH connection successful to $container_name!'" 2>/dev/null; then
            echo "✓ SSH connection test passed for $container_name!"
        else
            echo "⚠ SSH connection test failed for $container_name. Container may still be starting."
        fi
    done
}

# Function to display connection information
show_connection_info() {
    echo
    echo "=== Ozone Multi-Container Cluster Information ==="
    echo
    echo "Container SSH Access:"
    echo "To connect to any container, use the following pattern:"
    echo "  ssh -i $SSH_KEY_NAME -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p <PORT> rocky@localhost"
    echo
    echo "Container Details:"
    echo "  OM Containers:"
    echo "    ozone-om1    - SSH: 2222, Web UI: http://localhost:9874"
    echo "    ozone-om2    - SSH: 2223, Web UI: http://localhost:9875"
    echo "    ozone-om3    - SSH: 2224, Web UI: http://localhost:9873"
    echo
    echo "  SCM Containers:"
    echo "    ozone-scm1   - SSH: 2225, Web UI: http://localhost:9876"
    echo "    ozone-scm2   - SSH: 2226, Web UI: http://localhost:9877"
    echo "    ozone-scm3   - SSH: 2227, Web UI: http://localhost:9879"
    echo
    echo "  Service Containers:"
    echo "    ozone-recon      - SSH: 2228, Web UI: http://localhost:9888"
    echo "    ozone-s3gateway  - SSH: 2229, S3 API: http://localhost:9878"
    echo "    ozone-httpfs     - SSH: 2233, HttpFS: http://localhost:14000"
    echo
    echo "  DataNode Containers:"
    echo "    ozone-datanode1  - SSH: 2230, Web UI: http://localhost:9882"
    echo "    ozone-datanode2  - SSH: 2231, Web UI: http://localhost:9883"
    echo "    ozone-datanode3  - SSH: 2232, Web UI: http://localhost:9884"
    echo
    echo "  Observability Containers:"
    echo "    ozone-prometheus - SSH: 2234, Web UI: http://localhost:9090"
    echo "    ozone-grafana    - SSH: 2235, Web UI: http://localhost:3000"
    echo
    echo "Cluster Management:"
    echo "  View container status: docker ps"
    echo "  View logs: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME logs <service>"
    echo "  Stop cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME stop"
    echo "  Start cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME start"
    echo "  Remove cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME down --volumes"
    echo
    echo "Note: For development containers, host key checking is disabled to avoid"
    echo "      connection issues when containers are rebuilt with new SSH host keys."
}

# Function to show cluster status
show_status() {
    echo "=== Ozone Cluster Status ==="
    $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME ps
}

# Function to connect to a specific container
connect_to_container() {
    local container_name="$1"
    local port_map=(
        ["om1"]="2222"
        ["om2"]="2223"
        ["om3"]="2224"
        ["scm1"]="2225"
        ["scm2"]="2226"
        ["scm3"]="2227"
        ["recon"]="2228"
        ["s3gateway"]="2229"
        ["datanode1"]="2230"
        ["datanode2"]="2231"
        ["datanode3"]="2232"
        ["httpfs"]="2233"
        ["prometheus"]="2234"
        ["grafana"]="2235"
    )

    if [[ -z "${port_map[$container_name]}" ]]; then
        echo "Error: Unknown container '$container_name'"
        echo "Available containers: $(printf '%s ' "${!port_map[@]}")"
        exit 1
    fi

    local port="${port_map[$container_name]}"
    echo "Connecting to $container_name (port $port)..."
    ssh -i "$SSH_KEY_NAME" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$port" rocky@localhost
}

# Main execution
main() {
    case "${1:-start}" in
        "start")
            echo "Starting Ozone multi-container cluster setup..."
            cleanup
            cleanup_known_hosts
            generate_ssh_key
            start_containers
            setup_ssh_access
            test_ssh_connections
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
            echo "Cleanup completed"
            ;;
        "status")
            show_status
            ;;
        "connect")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 connect <container_name>"
                echo "Available containers: om1, om2, om3, scm1, scm2, scm3, recon, s3gateway, datanode1, datanode2, datanode3, httpfs, prometheus, grafana"
                exit 1
            fi
            connect_to_container "$2"
            ;;
        "info")
            show_connection_info
            ;;
        *)
            echo "Usage: $0 [start|stop|clean|status|connect <container>|info]"
            echo "  start               - Build and start the Ozone cluster (default)"
            echo "  stop                - Stop the running cluster"
            echo "  clean               - Remove all containers and volumes"
            echo "  status              - Show cluster status"
            echo "  connect <container> - Connect to a specific container via SSH"
            echo "  info                - Show connection information"
            echo ""
            echo "Available containers for connect command:"
            echo "  om1, om2, om3, scm1, scm2, scm3, recon, s3gateway"
            echo "  datanode1, datanode2, datanode3, httpfs, prometheus, grafana"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"