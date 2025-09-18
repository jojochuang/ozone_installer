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
- SSH credentials and key file location
- Ozone directory paths for different components

Example:
```bash
CLUSTER_HOSTS="node1.example.com,node2.example.com,node3.example.com"
SSH_USER="root"
SSH_PRIVATE_KEY_FILE="~/.ssh/ozone.private"
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
- Install selected JDK version
- Install and configure time synchronization

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

1. **CPU Governor**: Set to `performance` mode
2. **Transparent Huge Pages (THP)**: Disabled
3. **SELinux**: Disabled (if present)
4. **VM Swappiness**: Set to 1 to minimize swapping

## Web UIs

After successful startup, access these web interfaces:

- SCM Web UI: `http://<primary-host>:9876`
- OM Web UI: `http://<primary-host>:9874` 
- Recon Web UI: `http://<primary-host>:9888`

## Troubleshooting

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