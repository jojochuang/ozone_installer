# ozone_installer

This repository contains scripts and configurations for setting up various development environments.

## Rocky9 Docker Container with SSH Access

The `setup-rocky9-ssh.sh` script creates a Rocky Linux 9 Docker container with SSH daemon configured for password-less authentication using SSH keys.

### Prerequisites

- Docker installed and running
- SSH client available (usually pre-installed on Linux/macOS)

### Quick Start

1. Make the script executable (if not already):
   ```bash
   chmod +x setup-rocky9-ssh.sh
   ```

2. Run the setup script:
   ```bash
   ./setup-rocky9-ssh.sh
   ```

3. Connect to the container:
   ```bash
   ssh -i rocky9_key -p 2222 rocky@localhost
   ```

### Script Options

- `./setup-rocky9-ssh.sh start` - Build and start the container (default)
- `./setup-rocky9-ssh.sh stop` - Stop the running container
- `./setup-rocky9-ssh.sh clean` - Remove container and image
- `./setup-rocky9-ssh.sh connect` - Connect to the container via SSH
- `./setup-rocky9-ssh.sh info` - Show connection information

### What the Script Does

1. **Builds a Rocky9 Docker Image**: Creates a custom image based on Rocky Linux 9 with:
   - SSH server installed and configured
   - A user `rocky` with sudo privileges
   - SSH daemon configured for key-based authentication

2. **Generates SSH Key Pair**: Creates RSA key pair (`rocky9_key` and `rocky9_key.pub`) for secure access

3. **Starts the Container**: Runs the container with SSH port mapped to local port 2222

4. **Configures SSH Access**: Copies the public key to the container for password-less authentication

5. **Tests Connection**: Verifies that SSH access is working correctly

### Container Details

- **Base Image**: Rocky Linux 9
- **Container Name**: rocky9-ssh
- **SSH Port**: 2222 (mapped from container port 22)
- **Username**: rocky
- **User Privileges**: sudo access without password
- **SSH Keys**: `rocky9_key` (private) and `rocky9_key.pub` (public)

### Security Notes

- The container is configured with a user `rocky` that has sudo privileges
- Password authentication is enabled as a fallback, but key-based authentication is the primary method
- Root login via SSH is disabled
- The SSH keys are generated locally and should be kept secure

### Troubleshooting

1. **Docker not running**: Ensure Docker daemon is started
2. **Port conflict**: If port 2222 is in use, modify the `SSH_PORT` variable in the script
3. **SSH connection fails**: Wait a few seconds for the SSH daemon to fully start, then try again
4. **Permission denied**: Ensure the SSH key files have correct permissions (600 for private key)

### Files

- `Dockerfile.rocky9` - Docker configuration for Rocky9 image
- `setup-rocky9-ssh.sh` - Main setup script
- `rocky9_key` - SSH private key (generated)
- `rocky9_key.pub` - SSH public key (generated)