#!/bin/bash

# Ozone Installer Script
# Compatible with Linux and macOS

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

# Function to check host OS
check_host_os() {
    local os_type=$(uname -s)
    local os_version=""
    
    case "$os_type" in
        "Linux")
            if [[ -f /etc/os-release ]]; then
                os_version=$(grep '^VERSION=' /etc/os-release | cut -d'"' -f2)
            elif [[ -f /etc/redhat-release ]]; then
                os_version=$(cat /etc/redhat-release)
            else
                os_version="Unknown"
            fi
            log "Host OS: Linux - $os_version"
            ;;
        "Darwin")
            os_version=$(sw_vers -productVersion)
            log "Host OS: macOS - $os_version"
            ;;
        *)
            warn "Host OS not supported: $os_type, proceeding anyway"
            ;;
    esac
}

# Function to validate SSH connection
validate_ssh_connection() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Testing SSH connection to $host"
    
    if [[ ! -f "$ssh_key_expanded" ]]; then
        error "SSH private key file not found: $ssh_key_expanded"
        return 1
    fi
    
    # Test SSH connection
    if ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$host" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log "SSH connection to $host successful"
        return 0
    else
        error "SSH connection to $host failed"
        return 1
    fi
}

# Function to get host information
get_host_info() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Gathering information for host: $host"
    
    # Execute remote commands to get host information
    local host_info=$(ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        hostname=$(hostname)
        ip_address=$(hostname -I | awk "{print \$1}")
        cpu_arch=$(uname -m)
        os_type=$(uname -s)
        
        # Get OS distribution and version
        if [[ "$os_type" == "Linux" ]]; then
            if [[ -f /etc/os-release ]]; then
                os_dist=$(grep "^ID=" /etc/os-release | cut -d"=" -f2 | tr -d "\"")
                os_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d"=" -f2 | tr -d "\"")
            elif [[ -f /etc/redhat-release ]]; then
                os_dist="redhat"
                os_version=$(cat /etc/redhat-release | grep -oE "[0-9]+" | head -1)
            else
                os_dist="unknown"
                os_version="unknown"
            fi
        else
            os_dist="non-linux"
            os_version="unknown"
        fi
        
        echo "$hostname|$ip_address|$cpu_arch|$os_type|$os_dist|$os_version"
    ')
    
    # Parse the information
    IFS='|' read -r hostname ip_address cpu_arch os_type os_dist os_version <<< "$host_info"
    
    echo "  Hostname: $hostname"
    echo "  IP Address: $ip_address"
    echo "  CPU Architecture: $cpu_arch"
    echo "  OS Type: $os_type"
    echo "  Distribution: $os_dist"
    echo "  Version: $os_version"
    
    # Validate OS and CPU architecture
    if [[ "$os_type" != "Linux" ]]; then
        error "Host $host is not running Linux. Only Linux is supported."
        return 1
    fi
    
    if [[ "$cpu_arch" != "x86_64" && "$cpu_arch" != "aarch64" && "$cpu_arch" != "arm64" ]]; then
        error "Host $host has unsupported CPU architecture: $cpu_arch. Only x86_64 and ARM64 are supported."
        return 1
    fi
    
    return 0
}

# Function to configure CPU frequency governor
configure_cpu_governor() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Configuring CPU frequency governor on $host"
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Check if CPU frequency scaling is available
        if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
            # Check current governor
            current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
            echo "Current CPU governor: $current_governor"
            
            if [[ "$current_governor" != "performance" ]]; then
                echo "Setting CPU governor to performance..."
                for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq/; do
                    if [[ -d "$cpu_dir" ]]; then
                        echo "performance" > "${cpu_dir}scaling_governor"
                    fi
                done
                echo "CPU governor set to performance"
            else
                echo "CPU governor already set to performance"
            fi
        else
            echo "CPU frequency scaling not available on this system"
        fi
    '
}

# Function to disable Transparent Huge Pages (THP)
disable_thp() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Disabling Transparent Huge Pages on $host"
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Check if THP is enabled
        if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
            thp_status=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
            echo "Current THP status: $thp_status"
            
            if [[ "$thp_status" != *"[never]"* ]]; then
                echo "Disabling THP..."
                echo never > /sys/kernel/mm/transparent_hugepage/enabled
                echo never > /sys/kernel/mm/transparent_hugepage/defrag
                echo "THP disabled"
                
                # Make it persistent
                if ! grep -q "transparent_hugepage=never" /etc/default/grub 2>/dev/null; then
                    if [[ -f /etc/default/grub ]]; then
                        sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"transparent_hugepage=never /" /etc/default/grub
                        echo "Added THP disable to GRUB configuration"
                    fi
                fi
            else
                echo "THP already disabled"
            fi
        else
            echo "THP not available on this system"
        fi
    '
}

# Function to disable SELinux
disable_selinux() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Disabling SELinux on $host"
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        if command -v getenforce >/dev/null 2>&1; then
            selinux_status=$(getenforce)
            echo "Current SELinux status: $selinux_status"
            
            if [[ "$selinux_status" != "Disabled" ]]; then
                echo "Disabling SELinux..."
                setenforce 0
                
                # Make it persistent
                if [[ -f /etc/selinux/config ]]; then
                    sed -i "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config
                    echo "SELinux disabled and made persistent"
                fi
            else
                echo "SELinux already disabled"
            fi
        else
            echo "SELinux not available on this system"
        fi
    '
}

# Function to configure vm.swappiness
configure_swappiness() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Configuring vm.swappiness on $host"
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        current_swappiness=$(sysctl -n vm.swappiness)
        echo "Current vm.swappiness: $current_swappiness"
        
        if [[ "$current_swappiness" != "1" ]]; then
            echo "Setting vm.swappiness to 1..."
            sysctl -w vm.swappiness=1
            
            # Make it persistent
            if ! grep -q "vm.swappiness = 1" /etc/sysctl.conf; then
                echo "vm.swappiness = 1" >> /etc/sysctl.conf
                echo "vm.swappiness made persistent"
            fi
        else
            echo "vm.swappiness already set to 1"
        fi
    '
}

# Function to validate filesystem for ozone directories
validate_filesystem() {
    local host=$1
    local directories=$2
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Validating filesystem for directories on $host: $directories"
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        for dir in $directories; do
            if [[ -n \"\$dir\" ]]; then
                echo \"Checking directory: \$dir\"
                
                # Create directory if it doesn't exist
                mkdir -p \"\$dir\"
                
                # Get mount point and filesystem type
                mount_point=\$(df \"\$dir\" | tail -1 | awk '{print \$1}')
                fs_type=\$(df -T \"\$dir\" | tail -1 | awk '{print \$2}')
                mount_options=\$(mount | grep \"\$mount_point\" | awk '{print \$6}' | tr -d '()')
                
                echo \"  Mount point: \$mount_point\"
                echo \"  Filesystem type: \$fs_type\"
                echo \"  Mount options: \$mount_options\"
                
                # Check filesystem type
                if [[ \"\$fs_type\" != \"ext4\" && \"\$fs_type\" != \"xfs\" ]]; then
                    echo \"  WARNING: Filesystem type \$fs_type is not optimal (ext4 or xfs recommended)\"
                fi
                
                # Check for noatime option
                if [[ \"\$mount_options\" != *\"noatime\"* ]]; then
                    echo \"  WARNING: Mount does not have noatime option\"
                fi
                
                echo \"\"
            fi
        done
    "
}

# Function to ask for JDK version
ask_jdk_version() {
    echo ""
    echo "Select JDK version to install:"
    echo "1) OpenJDK 8 (default)"
    echo "2) OpenJDK 11"
    echo "3) OpenJDK 17"
    echo "4) OpenJDK 21"
    
    read -p "Enter choice [1-4] (default: 1): " jdk_choice
    
    case $jdk_choice in
        2) echo "11" ;;
        3) echo "17" ;;
        4) echo "21" ;;
        *) echo "8" ;;
    esac
}

# Function to install JDK
install_jdk() {
    local host=$1
    local jdk_version=$2
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Installing OpenJDK $jdk_version on $host"
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        # Detect package manager
        if command -v yum >/dev/null 2>&1; then
            PKG_MGR=\"yum\"
        elif command -v dnf >/dev/null 2>&1; then
            PKG_MGR=\"dnf\"
        elif command -v apt-get >/dev/null 2>&1; then
            PKG_MGR=\"apt-get\"
        elif command -v zypper >/dev/null 2>&1; then
            PKG_MGR=\"zypper\"
        else
            echo \"No supported package manager found\"
            exit 1
        fi
        
        echo \"Using package manager: \$PKG_MGR\"
        
        # Install JDK based on package manager
        case \$PKG_MGR in
            \"yum\"|\"dnf\")
                \$PKG_MGR update -y
                \$PKG_MGR install -y java-$jdk_version-openjdk java-$jdk_version-openjdk-devel
                ;;
            \"apt-get\")
                \$PKG_MGR update -y
                \$PKG_MGR install -y openjdk-$jdk_version-jdk
                ;;
            \"zypper\")
                zypper refresh
                zypper install -y java-$jdk_version-openjdk java-$jdk_version-openjdk-devel
                ;;
        esac
        
        # Verify installation
        java -version
    "
}

# Function to install and configure chrony/ntpd
install_time_sync() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    info "Installing and configuring time synchronization on $host"
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" '
        # Detect package manager
        if command -v yum >/dev/null 2>&1; then
            PKG_MGR="yum"
        elif command -v dnf >/dev/null 2>&1; then
            PKG_MGR="dnf"
        elif command -v apt-get >/dev/null 2>&1; then
            PKG_MGR="apt-get"
        elif command -v zypper >/dev/null 2>&1; then
            PKG_MGR="zypper"
        else
            echo "No supported package manager found"
            exit 1
        fi
        
        # Try to install chrony first, fall back to ntp
        case $PKG_MGR in
            "yum"|"dnf")
                if $PKG_MGR install -y chrony; then
                    systemctl enable chronyd
                    systemctl start chronyd
                    echo "Chrony installed and started"
                elif $PKG_MGR install -y ntp; then
                    systemctl enable ntpd
                    systemctl start ntpd
                    echo "NTP installed and started"
                fi
                ;;
            "apt-get")
                if $PKG_MGR install -y chrony; then
                    systemctl enable chrony
                    systemctl start chrony
                    echo "Chrony installed and started"
                elif $PKG_MGR install -y ntp; then
                    systemctl enable ntp
                    systemctl start ntp
                    echo "NTP installed and started"
                fi
                ;;
            "zypper")
                if zypper install -y chrony; then
                    systemctl enable chronyd
                    systemctl start chronyd
                    echo "Chrony installed and started"
                elif zypper install -y ntp; then
                    systemctl enable ntpd
                    systemctl start ntpd
                    echo "NTP installed and started"
                fi
                ;;
        esac
    '
}

# Main function
main() {
    log "Starting Ozone Installer"
    
    # Check host OS
    check_host_os
    
    # Load configuration
    log "Loading configuration from $CONFIG_FILE"
    load_config
    
    # Convert CLUSTER_HOSTS to array
    IFS=',' read -ra HOSTS <<< "$CLUSTER_HOSTS"
    
    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        error "No hosts specified in CLUSTER_HOSTS"
        exit 1
    fi
    
    log "Found ${#HOSTS[@]} hosts to configure"
    
    # Validate SSH connections and gather host information
    log "Validating SSH connections and gathering host information..."
    for host in "${HOSTS[@]}"; do
        # Trim whitespace
        host=$(echo "$host" | xargs)
        
        if ! validate_ssh_connection "$host"; then
            exit 1
        fi
        
        if ! get_host_info "$host"; then
            exit 1
        fi
    done
    
    # Ask for JDK version
    jdk_version=$(ask_jdk_version)
    log "Selected JDK version: $jdk_version"
    
    # Configure each host
    for host in "${HOSTS[@]}"; do
        host=$(echo "$host" | xargs)
        
        log "Configuring host: $host"
        
        # Configure CPU governor
        configure_cpu_governor "$host"
        
        # Disable THP
        disable_thp "$host"
        
        # Disable SELinux
        disable_selinux "$host"
        
        # Configure swappiness
        configure_swappiness "$host"
        
        # Validate filesystems for ozone directories
        om_dirs="$OZONE_OM_DB_DIR $OZONE_METADATA_DIRS $OZONE_OM_RATIS_STORAGE_DIR"
        scm_dirs="$OZONE_SCM_DB_DIRS $OZONE_SCM_HA_RATIS_STORAGE_DIR $OZONE_SCM_METADATA_DIRS"
        recon_dirs="$OZONE_RECON_DB_DIR $OZONE_RECON_SCM_DB_DIRS $OZONE_RECON_OM_DB_DIR $OZONE_RECON_METADATA_DIRS"
        datanode_dirs="$OZONE_SCM_DATANODE_ID_DIR $DFS_CONTAINER_RATIS_DATANODE_STORAGE_DIR $HDDS_DATANODE_DIR $OZONE_DATANODE_METADATA_DIRS"
        
        # Combine all directories for validation
        all_dirs="$om_dirs $scm_dirs $recon_dirs $datanode_dirs"
        validate_filesystem "$host" "$all_dirs"
        
        # Install JDK
        install_jdk "$host" "$jdk_version"
        
        # Install time synchronization
        install_time_sync "$host"
        
        log "Host $host configuration completed"
    done
    
    log "Ozone Installer completed successfully"
    log "Next steps:"
    log "1. Run ./generate_configurations.sh to create Ozone configuration files"
    log "2. Run the startup script to start Ozone services"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi