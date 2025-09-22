#!/bin/bash

# Rocky9 Docker Container Setup Script for Password-less SSH Access
# This script creates a Rocky9 container with SSH daemon configured for key-based authentication

set -e

CONTAINER_NAME="rocky9-ssh"
SSH_PORT="2222"
IMAGE_NAME="rocky9-ssh"
SSH_KEY_NAME="rocky9_key"

echo "=== Rocky9 Docker Container SSH Setup ==="
echo "Container name: $CONTAINER_NAME"
echo "SSH port: $SSH_PORT"
echo "SSH key: $SSH_KEY_NAME"
echo

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    exit 1
fi

# Function to cleanup existing container and image if they exist
cleanup() {
    echo "Cleaning up existing container and image..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    docker rmi $IMAGE_NAME 2>/dev/null || true
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

# Function to build the Docker image
build_image() {
    echo "Building Rocky9 Docker image..."
    docker build -t $IMAGE_NAME -f Dockerfile.rocky9 .
    echo "Docker image built successfully: $IMAGE_NAME"
}

# Function to run the container
run_container() {
    echo "Starting Rocky9 container..."
    docker run -d \
        --name $CONTAINER_NAME \
        -p $SSH_PORT:22 \
        -p 9863:9863 \
        -p 9874:9874 \
        -p 9876:9876 \
        -p 9888:9888 \
        -p 9878:9878 \
        -p 14000:14000 \
        -p 9882:9882 \
        $IMAGE_NAME

    echo "Container started successfully: $CONTAINER_NAME"
    echo "SSH port mapped to: $SSH_PORT"
    echo "Ozone service ports exposed: 9863, 9874, 9876, 9888, 9878, 14000, 9882"
}

# Function to copy SSH public key to container
setup_ssh_access() {
    echo "Setting up SSH access..."

    # Wait for container to be ready
    echo "Waiting for container to be ready..."
    sleep 5

    # Copy the public key to the container
    docker cp "$SSH_KEY_NAME.pub" $CONTAINER_NAME:/tmp/authorized_keys

    # Set up the authorized_keys file in the container
    docker exec $CONTAINER_NAME bash -c "
        mkdir -p /home/rocky/.ssh
        cp /tmp/authorized_keys /home/rocky/.ssh/authorized_keys
        chown rocky:rocky /home/rocky/.ssh/authorized_keys
        chmod 600 /home/rocky/.ssh/authorized_keys
        rm /tmp/authorized_keys
    "

    echo "SSH access configured successfully"
}

# Function to clean up old host keys from known_hosts
cleanup_known_hosts() {
    echo "Cleaning up old SSH host keys..."

    # Remove any existing entries for localhost:2222 from known_hosts
    if [ -f ~/.ssh/known_hosts ]; then
        ssh-keygen -R "[localhost]:$SSH_PORT" 2>/dev/null || true
        echo "Old host keys removed from known_hosts"
    fi
}

# Function to test SSH connection
test_ssh_connection() {
    echo "Testing SSH connection..."

    # Wait a bit more for SSH daemon to be fully ready
    sleep 2

    # Test SSH connection with proper host key handling
    if ssh -i "$SSH_KEY_NAME" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -p $SSH_PORT rocky@localhost "echo 'SSH connection successful!'" 2>/dev/null; then
        echo "✓ SSH connection test passed!"
    else
        echo "⚠ SSH connection test failed. You may need to wait a moment for the SSH daemon to fully start."
        echo "Try connecting manually with: ssh -i $SSH_KEY_NAME -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $SSH_PORT rocky@localhost"
    fi
}

# Function to display connection information
show_connection_info() {
    echo
    echo "=== Connection Information ==="
    echo "To connect to the Rocky9 container:"
    echo "  ssh -i $SSH_KEY_NAME -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $SSH_PORT rocky@localhost"
    echo
    echo "Note: For development containers, host key checking is disabled to avoid"
    echo "      connection issues when containers are rebuilt with new SSH host keys."
    echo
    echo "Container details:"
    echo "  Container name: $CONTAINER_NAME"
    echo "  SSH port: $SSH_PORT"
    echo "  Username: rocky"
    echo "  Private key: $SSH_KEY_NAME"
    echo "  Public key: $SSH_KEY_NAME.pub"
    echo
    echo "Ozone service ports exposed:"
    echo "  OM Web UI: http://localhost:9874"
    echo "  SCM Web UI: http://localhost:9876"
    echo "  Recon Web UI: http://localhost:9888"
    echo "  S3 Gateway: http://localhost:9878"
    echo "  HttpFS: http://localhost:14000"
    echo "  Datanode Web UI: http://localhost:9882"
    echo
    echo "To stop the container:"
    echo "  docker stop $CONTAINER_NAME"
    echo
    echo "To start the container again:"
    echo "  docker start $CONTAINER_NAME"
    echo
    echo "To remove the container:"
    echo "  docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
}

# Main execution
main() {
    case "${1:-start}" in
        "start")
            echo "Starting Rocky9 container setup..."
            cleanup
            cleanup_known_hosts
            generate_ssh_key
            build_image
            run_container
            setup_ssh_access
            test_ssh_connection
            show_connection_info
            ;;
        "stop")
            echo "Stopping Rocky9 container..."
            docker stop $CONTAINER_NAME
            echo "Container stopped: $CONTAINER_NAME"
            ;;
        "clean")
            echo "Cleaning up Rocky9 container and image..."
            cleanup
            echo "Cleanup completed"
            ;;
        "connect")
            echo "Connecting to Rocky9 container..."
            ssh -i "$SSH_KEY_NAME" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $SSH_PORT rocky@localhost
            ;;
        "info")
            show_connection_info
            ;;
        *)
            echo "Usage: $0 [start|stop|clean|connect|info]"
            echo "  start  - Build and start the Rocky9 container with SSH (default)"
            echo "  stop   - Stop the running container"
            echo "  clean  - Remove container and image"
            echo "  connect- Connect to the container via SSH"
            echo "  info   - Show connection information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"