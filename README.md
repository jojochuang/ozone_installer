# Ozone Installer

A comprehensive installer script for Apache Ozone that works on both Linux and macOS.

## Overview

This installer provides automated setup and configuration for Apache Ozone clusters, including:

- System validation and optimization
- SSH connectivity verification
- Host information gathering
- JDK installation
- Time synchronization setup
- Ozone configuration generation
- Service startup and management
- Optional Prometheus and Grafana installation for observability

## Files

- `ozone_installer.conf` - Configuration file with cluster and path settings
- `ozone_installer.sh` - Main installer script
- `generate_configurations.sh` - Standalone script for generating Ozone configuration files
- `start_ozone_services.sh` - Script to start Ozone services and wait for safe mode exit

## Prerequisites

1. SSH access to all cluster hosts with private key authentication
2. Root or sudo access on all hosts
3. Apache Ozone binaries installed on all hosts

## Configuration

Edit `ozone_installer.conf` to specify:

- `CLUSTER_HOSTS` - Comma-separated list of hostnames/IPs
- SSH credentials, port, and key file location
- Ozone installation settings (version, installation directory)
- Ozone directory paths for different components
- Observability tools settings (Prometheus and Grafana)

Example:
```bash
CLUSTER_HOSTS="node1.example.com,node2.example.com,node3.example.com"
SSH_USER="rocky"
SSH_PRIVATE_KEY_FILE="~/.ssh/ozone.private"
SSH_PORT="2222"

# Ozone Installation Settings
OZONE_VERSION="2.0.0"
OZONE_INSTALL_DIR="/opt/ozone"

# Observability Configuration (optional, enabled by default)
INSTALL_PROMETHEUS="true"  # Set to "false" to disable
INSTALL_GRAFANA="true"     # Set to "false" to disable
PROMETHEUS_VERSION="2.54.1"
PROMETHEUS_PORT="9090"
GRAFANA_PORT="3000"

# Optional: Use local tarball to skip download (for better scalability)
# LOCAL_TARBALL_PATH="/path/to/ozone-2.0.0.tar.gz"

# Optional: Configure parallel transfers (default: 10)
MAX_CONCURRENT_TRANSFERS=10
```

## Usage

### 1. Run the main installer:
```bash
./ozone_installer.sh
```

This will:
- Check OS compatibility (Linux/macOS)
- Validate SSH connections to all hosts
- Gather host information (hostname, IP, CPU, OS)
- Configure system settings (CPU governor, THP, SELinux, swappiness)
- Validate filesystem requirements
- Install basic utilities (including tput, required by Ozone)
- Install selected JDK version
- Install and configure time synchronization
- Download and install Apache Ozone binary
- Install Prometheus and Grafana (if enabled in configuration)

- **Download Ozone binary once and distribute to all hosts** (scalable for large clusters)

### Scalability Features

The installer automatically optimizes for large clusters by:
- **Centralized Download**: Downloads the Ozone tarball once on the installer machine
- **Parallel SCP Distribution**: Transfers the tarball to multiple hosts simultaneously (up to 10 concurrent transfers)
- **Configurable Concurrency**: Control parallel transfers via `MAX_CONCURRENT_TRANSFERS` setting
- **Fallback Mechanism**: Falls back to direct download if SCP transfer fails
- **Local Tarball Support**: Can use a pre-downloaded tarball via `LOCAL_TARBALL_PATH` configuration

This approach scales efficiently to 100+ hosts without overwhelming Apache's download servers, and the parallel transfers significantly reduce installation time.

### Testing the Scalability Improvements

Run the included test script to see the scalability improvements in action:

```bash
./test_scalability.sh
```

This demonstrates how the new approach reduces external downloads from N (number of hosts) to 1.

### 2. Generate configuration files:
```bash
./generate_configurations.sh
```

Creates and distributes:
- `core-site.xml`
- `ozone-site.xml`
- `log4j.properties`

### 3. Start Ozone services:
```bash
./start_ozone_services.sh
```

This will:
- Format SCM and OM (if needed)
- Start all Ozone services in detached mode
- Wait for the cluster to exit safe mode
- Display service status and web UI URLs

## System Requirements

### Operating Systems
- Linux distributions (RHEL, CentOS, Ubuntu, SUSE)
- macOS (host validation only)

### CPU Architecture
- x86_64 (Intel/AMD)
- aarch64/arm64 (ARM)

### Filesystem
- ext4 or xfs recommended
- noatime mount option recommended

## System Optimizations

The installer automatically configures:

1. **Basic Utilities**: Installs essential packages including `tput` (required by Ozone)
2. **CPU Governor**: Set to `performance` mode
3. **Transparent Huge Pages (THP)**: Disabled
4. **SELinux**: Disabled (if present)
5. **VM Swappiness**: Set to 1 to minimize swapping

## Web UIs

After successful startup, access these web interfaces:

### Ozone Web UIs
- SCM Web UI: `http://<primary-host>:9876`
- OM Web UI: `http://<primary-host>:9874`
- Recon Web UI: `http://<primary-host>:9888`

### Observability Web UIs (if installed)
- Prometheus Web UI: `http://<primary-host>:9090`
- Grafana Web UI: `http://<primary-host>:3000` (default credentials: admin/admin)

## Troubleshooting

### Common Issues

#### OM Fails to Start with "Operation not permitted"
If you see an error like:
```
OM start failed with exception
java.lang.RuntimeException: Failed to set directory permissions for /var/lib/hadoop-ozone/om/data: /var/lib/hadoop-ozone/om/data: Operation not permitted
```

This is a directory permission issue. To fix:

1. **Run the verification script** to check current permissions:
   ```bash
   ./verify_permissions.sh
   ```

2. **Re-run the installer** to fix permissions automatically:
   ```bash
   ./ozone_installer.sh
   ```

3. **Manual fix** (if needed):
   ```bash
   # For each problematic directory:
   sudo chown -R $(whoami):$(id -gn) /var/lib/hadoop-ozone/om/data
   sudo chmod -R 750 /var/lib/hadoop-ozone/om/data
   ```

#### Check Service Logs
Check service logs:
- SCM: `/tmp/scm.log`
- OM: `/tmp/om.log`
- DataNode: `/tmp/datanode.log`
- Recon: `/tmp/recon.log`

Check cluster status:
```bash
ozone admin safemode status
ozone admin cluster info
```

## License

Licensed under the Apache License, Version 2.0.

## Development

This project includes a precommit framework using GitHub Actions to ensure code quality and consistency.

### Precommit Checks

The repository includes automated checks for:

- **Shell Script Linting**: Uses `shellcheck` to detect common shell scripting issues
- **Shell Script Formatting**: Uses `shfmt` to check code formatting consistency
- **Syntax Validation**: Validates shell script syntax using `bash -n`
- **File Permissions**: Ensures shell scripts are executable
- **Markdown Linting**: Validates markdown documentation
- **General File Checks**: Detects trailing whitespace, line endings, and large files
- **Command Option Tests**: Validates that shell script command options work as documented
- **Function Unit Tests**: Basic unit tests for key functions in shell scripts

### Running Checks Locally

Use the provided Makefile to run precommit checks locally:

```bash
# Show available commands
make help

# Run essential precommit checks
make test-all

# Run only shellcheck (errors only)
make shellcheck-errors-only

# Check shell script formatting
make format

# Fix shell script formatting
make format-fix

# Test shell script command options (as per README)
make test-commands

# Test shell script functions (basic unit tests)
make test-functions

# Run comprehensive precommit tests (command options + unit tests)
make test-precommit

# Install precommit tools
make install-tools
```

### GitHub Actions

The precommit checks run automatically on:
- Push to `main` or `develop` branches
- Pull requests targeting `main` or `develop` branches

The workflow includes four jobs:
1. **Shell Script Checks**: Linting, formatting, syntax, permissions, and precommit tests
2. **Markdown Checks**: Documentation validation
3. **File Checks**: General repository hygiene

### Configuration Files

- `.shellcheckrc`: Configuration for shellcheck to ignore acceptable warnings
- `.markdownlint.json`: Configuration for markdown linting
- `.editorconfig`: Editor configuration for consistent formatting
- `Makefile`: Local development commands for precommit checks


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
   ssh -i rocky9_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 rocky@localhost
   ```

   **Note**: Host key checking is disabled for development containers to avoid connection issues when containers are rebuilt with new SSH host keys.

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
- **Ozone Service Ports**: 9874 (OM), 9876 (SCM), 9888 (Recon), 9878 (S3 Gateway), 14000 (HttpFS), 9882 (Datanode)
- **Observability Ports**: 9090 (Prometheus), 3000 (Grafana)
- **Username**: rocky
- **User Privileges**: sudo access without password
- **Container Mode**: standard (privileged mode removed to fix SSH connectivity)
- **SSH Keys**: `rocky9_key` (private) and `rocky9_key.pub` (public)

### Security Notes

- The container is configured with a user `rocky` that has sudo privileges
- The container runs in standard mode for better SSH compatibility
- If you need privileged mode for system-level commands (like sysctl), you can manually add `--privileged` to the docker run command in the script
- Password authentication is enabled as a fallback, but key-based authentication is the primary method
- Root login via SSH is disabled
- The SSH keys are generated locally and should be kept secure

### Troubleshooting

1. **Docker not running**: Ensure Docker daemon is started
2. **Port conflict**: If port 2222 is in use, modify the `SSH_PORT` variable in the script
3. **SSH connection fails**: Wait a few seconds for the SSH daemon to fully start, then try again
4. **Permission denied**: Ensure the SSH key files have correct permissions (600 for private key)
5. **SSH host key verification failed**: If you see "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!" error, this is normal when containers are rebuilt. The script automatically handles this by cleaning up old host keys and using appropriate SSH options.
6. **SSH connection issues with privileged mode**: The container runs in standard mode by default. If you manually add `--privileged` flag, it may interfere with SSH daemon operation.

### Files

- `Dockerfile.rocky9` - Docker configuration for Rocky9 image
- `setup-rocky9-ssh.sh` - Main setup script
- `rocky9_key` - SSH private key (generated)
- `rocky9_key.pub` - SSH public key (generated)
