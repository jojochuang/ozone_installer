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
    done

    echo "SSH access configured successfully for all containers"
}

# Function to clean up old host keys from known_hosts
cleanup_known_hosts() {
    echo "Docker containers will be accessed via docker exec, no SSH cleanup needed."
}

# Function to test SSH connections
test_ssh_connections() {
    echo "Testing container connectivity..."

    # Test a few key containers using docker exec
    test_containers=(
        "ozone-om1"
        "ozone-scm1"
        "ozone-recon"
        "ozone-datanode1"
    )

    for container_name in "${test_containers[@]}"; do
        if docker exec "$container_name" echo "Container $container_name is accessible!" 2>/dev/null; then
            echo "✓ Container access test passed for $container_name!"
        else
            echo "⚠ Container access test failed for $container_name. Container may still be starting."
        fi
    done
}

# Function to display connection information
show_connection_info() {
    echo
    echo "=== Ozone Multi-Container Cluster Information ==="
    echo
    echo "Container Access:"
    echo "To connect to any container, use docker exec:"
    echo "  docker exec -it <container_name> bash"
    echo
    echo "Container Details:"
    echo "  OM Containers:"
    echo "    ozone-om1    - Web UI: http://om1:9874"
    echo "    ozone-om2    - Web UI: http://om2:9874"
    echo "    ozone-om3    - Web UI: http://om3:9874"
    echo
    echo "  SCM Containers:"
    echo "    ozone-scm1   - Web UI: http://scm1:9876"
    echo "    ozone-scm2   - Web UI: http://scm2:9876"
    echo "    ozone-scm3   - Web UI: http://scm3:9876"
    echo
    echo "  Service Containers:"
    echo "    ozone-recon      - Web UI: http://recon:9888"
    echo "    ozone-s3gateway  - S3 API: http://s3gateway:9878"
    echo "    ozone-httpfs     - HttpFS: http://httpfs:14000"
    echo
    echo "  DataNode Containers:"
    echo "    ozone-datanode1  - Web UI: http://datanode1:9882"
    echo "    ozone-datanode2  - Web UI: http://datanode2:9882"
    echo "    ozone-datanode3  - Web UI: http://datanode3:9882"
    echo
    echo "  Observability Containers:"
    echo "    ozone-prometheus - Web UI: http://prometheus:9090"
    echo "    ozone-grafana    - Web UI: http://grafana:3000"
    echo
    echo "Cluster Management:"
    echo "  View container status: docker ps"
    echo "  View logs: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME logs <service>"
    echo "  Stop cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME stop"
    echo "  Start cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME start"
    echo "  Remove cluster: $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME down --volumes"
    echo
    echo "Note: Services are accessible within the Docker network."
    echo "      Use docker exec to access containers directly."
}

# Function to show cluster status
show_status() {
    echo "=== Ozone Cluster Status ==="
    $DOCKER_COMPOSE_CMD -p $COMPOSE_PROJECT_NAME ps
}

# Function to connect to a specific container
connect_to_container() {
    local container_name="$1"
    local container_map=(
        ["om1"]="ozone-om1"
        ["om2"]="ozone-om2"
        ["om3"]="ozone-om3"
        ["scm1"]="ozone-scm1"
        ["scm2"]="ozone-scm2"
        ["scm3"]="ozone-scm3"
        ["recon"]="ozone-recon"
        ["s3gateway"]="ozone-s3gateway"
        ["datanode1"]="ozone-datanode1"
        ["datanode2"]="ozone-datanode2"
        ["datanode3"]="ozone-datanode3"
        ["httpfs"]="ozone-httpfs"
        ["prometheus"]="ozone-prometheus"
        ["grafana"]="ozone-grafana"
    )

    if [[ -z "${container_map[$container_name]}" ]]; then
        echo "Error: Unknown container '$container_name'"
        echo "Available containers: $(printf '%s ' "${!container_map[@]}")"
        exit 1
    fi

    local full_container_name="${container_map[$container_name]}"
    echo "Connecting to $container_name ($full_container_name)..."
    docker exec -it "$full_container_name" bash
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