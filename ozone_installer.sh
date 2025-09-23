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

# Function to check sudo privileges on remote host
check_sudo_privileges() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Checking sudo privileges on $host"

    # Test if user can run sudo
    if ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "sudo -n true" >/dev/null 2>&1; then
        log "Sudo privileges confirmed on $host"
        return 0
    else
        warn "User $SSH_USER does not have passwordless sudo on $host"
        info "Attempting to verify sudo access with password prompt..."

        # Try with password prompt (this will fail in automated environments)
        if ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "sudo -v" >/dev/null 2>&1; then
            log "Sudo access available (may require password) on $host"
            return 0
        else
            error "User $SSH_USER cannot access sudo on $host. Please ensure the user has sudo privileges."
            return 1
        fi
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
                        sudo bash -c "echo performance > \"${cpu_dir}scaling_governor\""
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
                sudo bash -c "echo never > /sys/kernel/mm/transparent_hugepage/enabled"
                sudo bash -c "echo never > /sys/kernel/mm/transparent_hugepage/defrag"
                echo "THP disabled"

                # Make it persistent
                if ! grep -q "transparent_hugepage=never" /etc/default/grub 2>/dev/null; then
                    if [[ -f /etc/default/grub ]]; then
                        sudo sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"transparent_hugepage=never /" /etc/default/grub
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
                sudo setenforce 0

                # Make it persistent
                if [[ -f /etc/selinux/config ]]; then
                    sudo sed -i "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config
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
            sudo sysctl -w vm.swappiness=1

            # Make it persistent
            if ! grep -q "vm.swappiness = 1" /etc/sysctl.conf; then
                sudo bash -c "echo \"vm.swappiness = 1\" >> /etc/sysctl.conf"
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
                sudo mkdir -p \"\$dir\"

                # Change ownership to the SSH user so Ozone services can access it
                sudo chown -R \$(whoami):\$(id -gn) \"\$dir\"

                # Set proper permissions for Ozone directories (rwxr-x--- for security)
                sudo chmod -R 750 \"\$dir\"

                # Get mount point and filesystem type
                mount_point=\$(df \"\$dir\" | tail -1 | awk '{print \$1}')
                fs_type=\$(df -T \"\$dir\" | tail -1 | awk '{print \$2}')
                mount_options=\$(mount | grep \"\$mount_point\" | awk '{print \$6}' | tr -d '()')

                echo \"  Mount point: \$mount_point\"
                echo \"  Filesystem type: \$fs_type\"
                echo \"  Mount options: \$mount_options\"
                echo \"  Owner: \$(stat -c '%U:%G' \"\$dir\")\"
                echo \"  Permissions: \$(stat -c '%a' \"\$dir\")\"

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
    echo "" >&2
    echo "Select JDK version to install:" >&2
    echo "1) OpenJDK 8 (default, may fall back to JDK 11 on newer distributions)" >&2
    echo "2) OpenJDK 11" >&2
    echo "3) OpenJDK 17" >&2
    echo "4) OpenJDK 21" >&2

    read -p "Enter choice [1-4] (default: 1): " jdk_choice >&2

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
        # Detect package manager and distribution
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

        # Function to check if a package exists
        package_exists() {
            case \$PKG_MGR in
                \"yum\"|\"dnf\")
                    \$PKG_MGR list available \"\$1\" >/dev/null 2>&1
                    ;;
                \"apt-get\")
                    apt-cache show \"\$1\" >/dev/null 2>&1
                    ;;
                \"zypper\")
                    zypper info \"\$1\" >/dev/null 2>&1
                    ;;
            esac
        }

        # Determine the correct package names and check availability
        case \$PKG_MGR in
            \"yum\"|\"dnf\")
                # RHEL/Rocky/CentOS package names
                if [[ \"$jdk_version\" == \"8\" ]]; then
                    # Check if JDK 8 is available (not available on RHEL 9+ / Rocky 9+)
                    if package_exists \"java-1.8.0-openjdk\"; then
                        JDK_PACKAGES=\"java-1.8.0-openjdk java-1.8.0-openjdk-devel\"
                    else
                        echo \"OpenJDK 8 is not available on this distribution. Falling back to OpenJDK 11.\"
                        JDK_PACKAGES=\"java-11-openjdk java-11-openjdk-devel\"
                    fi
                else
                    JDK_PACKAGES=\"java-$jdk_version-openjdk java-$jdk_version-openjdk-devel\"
                fi

                # Verify packages exist
                valid_packages=\"\"
                for pkg in \$JDK_PACKAGES; do
                    if package_exists \"\$pkg\"; then
                        valid_packages=\"\$valid_packages \$pkg\"
                    else
                        echo \"Package \$pkg not found\"
                    fi
                done

                if [[ -n \"\$valid_packages\" ]]; then
                    sudo \$PKG_MGR update -y
                    sudo \$PKG_MGR install -y \$valid_packages
                else
                    echo \"No valid OpenJDK packages found for version $jdk_version\"
                    exit 1
                fi
                ;;

            \"apt-get\")
                # Ubuntu/Debian package names
                JDK_PACKAGES=\"openjdk-$jdk_version-jdk\"

                if package_exists \"\$JDK_PACKAGES\"; then
                    sudo \$PKG_MGR update -y
                    sudo \$PKG_MGR install -y \$JDK_PACKAGES
                else
                    echo \"OpenJDK $jdk_version not available. Checking for alternatives...\"
                    # Try alternative versions
                    for alt_version in 11 17 21 8; do
                        if [[ \"\$alt_version\" != \"$jdk_version\" ]] && package_exists \"openjdk-\$alt_version-jdk\"; then
                            echo \"Installing OpenJDK \$alt_version instead\"
                            sudo \$PKG_MGR update -y
                            sudo \$PKG_MGR install -y \"openjdk-\$alt_version-jdk\"
                            break
                        fi
                    done
                fi
                ;;

            \"zypper\")
                # SUSE package names
                if [[ \"$jdk_version\" == \"8\" ]]; then
                    JDK_PACKAGES=\"java-1_8_0-openjdk java-1_8_0-openjdk-devel\"
                else
                    JDK_PACKAGES=\"java-$jdk_version-openjdk java-$jdk_version-openjdk-devel\"
                fi

                # Verify packages exist
                valid_packages=\"\"
                for pkg in \$JDK_PACKAGES; do
                    if package_exists \"\$pkg\"; then
                        valid_packages=\"\$valid_packages \$pkg\"
                    fi
                done

                if [[ -n \"\$valid_packages\" ]]; then
                    sudo zypper refresh
                    sudo zypper install -y \$valid_packages
                else
                    echo \"No valid OpenJDK packages found for version $jdk_version\"
                    exit 1
                fi
                ;;
        esac

        # Verify installation
        if command -v java >/dev/null 2>&1; then
            echo \"Java installation successful:\"
            java -version
        else
            echo \"Java installation verification failed\"
            exit 1
        fi
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
                if sudo $PKG_MGR install -y chrony; then
                    sudo systemctl enable chronyd
                    sudo systemctl start chronyd
                    echo "Chrony installed and started"
                elif sudo $PKG_MGR install -y ntp; then
                    sudo systemctl enable ntpd
                    sudo systemctl start ntpd
                    echo "NTP installed and started"
                fi
                ;;
            "apt-get")
                if sudo $PKG_MGR install -y chrony; then
                    sudo systemctl enable chrony
                    sudo systemctl start chrony
                    echo "Chrony installed and started"
                elif sudo $PKG_MGR install -y ntp; then
                    sudo systemctl enable ntp
                    sudo systemctl start ntp
                    echo "NTP installed and started"
                fi
                ;;
            "zypper")
                if sudo zypper install -y chrony; then
                    sudo systemctl enable chronyd
                    sudo systemctl start chronyd
                    echo "Chrony installed and started"
                elif sudo zypper install -y ntp; then
                    sudo systemctl enable ntpd
                    sudo systemctl start ntpd
                    echo "NTP installed and started"
                fi
                ;;
        esac
    '
}

# Function to download Ozone tarball locally for distribution
download_ozone_centrally() {
    local download_url=$(echo "$OZONE_DOWNLOAD_URL" | sed "s/\${OZONE_VERSION}/$OZONE_VERSION/g")
    local local_tarball_path="/tmp/ozone-${OZONE_VERSION}.tar.gz"

    # Check if we already have a local tarball or if LOCAL_TARBALL_PATH is specified
    if [[ -n "${LOCAL_TARBALL_PATH:-}" ]] && [[ -f "$LOCAL_TARBALL_PATH" ]]; then
        info "Using existing local tarball: $LOCAL_TARBALL_PATH" >&2
        echo "$LOCAL_TARBALL_PATH"
        return 0
    fi

    if [[ -f "$local_tarball_path" ]]; then
        info "Using existing downloaded tarball: $local_tarball_path" >&2
        echo "$local_tarball_path"
        return 0
    fi

    info "Downloading Apache Ozone $OZONE_VERSION locally for distribution..." >&2

    # Download Ozone locally
    if command -v wget >/dev/null 2>&1; then
        if wget "$download_url" -O "$local_tarball_path"; then
            info "Successfully downloaded Ozone tarball to $local_tarball_path" >&2
            echo "$local_tarball_path"
            return 0
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -L "$download_url" -o "$local_tarball_path"; then
            info "Successfully downloaded Ozone tarball to $local_tarball_path" >&2
            echo "$local_tarball_path"
            return 0
        fi
    else
        error "Neither wget nor curl found. Cannot download Ozone." >&2
        return 1
    fi

    error "Failed to download Ozone from $download_url" >&2
    return 1
}

# Function to transfer tarball to multiple hosts in parallel
transfer_tarball_parallel() {
    local local_tarball_path=$1
    shift
    local hosts=("$@")
    local max_concurrent=${MAX_CONCURRENT_TRANSFERS:-10}
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    if [[ -z "$local_tarball_path" ]] || [[ ! -f "$local_tarball_path" ]]; then
        info "No local tarball available, skipping parallel transfer"
        return 1
    fi

    info "Transferring Ozone tarball to ${#hosts[@]} hosts (max $max_concurrent concurrent transfers)..."

    local pids=()
    local active_transfers=0
    local failed_hosts=()

    for host in "${hosts[@]}"; do
        host=$(echo "$host" | xargs)

        # Wait if we've reached the maximum concurrent transfers
        while [[ $active_transfers -ge $max_concurrent ]]; do
            # Check for completed transfers
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    wait "${pids[$i]}"
                    if [[ $? -eq 0 ]]; then
                        info "Tarball transfer completed successfully"
                    else
                        warn "Tarball transfer failed for one host"
                    fi
                    unset pids[$i]
                    ((active_transfers--))
                fi
            done
            sleep 1
        done

        # Start transfer for this host in background
        (
            # Create temporary directory on remote host first
            # Use a consistent directory name that install_ozone() will also use
            if ! ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
                temp_dir=\"/tmp/ozone_install_${OZONE_VERSION}_parallel\"
                mkdir -p \"\$temp_dir\"
            " 2>/dev/null; then
                echo "FAILED:$host:mkdir"
                exit 1
            fi

            # Transfer the tarball
            if scp -i "$ssh_key_expanded" -P "$SSH_PORT" -o StrictHostKeyChecking=no "$local_tarball_path" "$SSH_USER@$host:/tmp/ozone_install_${OZONE_VERSION}_parallel/ozone.tar.gz" 2>/dev/null; then
                # Verify the transfer was successful by checking file size
                local_size=$(stat -c%s "$local_tarball_path" 2>/dev/null || echo "0")
                remote_size=$(ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "stat -c%s /tmp/ozone_install_${OZONE_VERSION}_parallel/ozone.tar.gz 2>/dev/null || echo 0" 2>/dev/null)

                if [[ "$local_size" == "$remote_size" ]] && [[ "$local_size" -gt 0 ]]; then
                    echo "SUCCESS:$host"
                else
                    echo "FAILED:$host:size_mismatch"
                    exit 1
                fi
            else
                echo "FAILED:$host:scp"
                exit 1
            fi
        ) &

        pids+=($!)
        ((active_transfers++))
        info "Started tarball transfer to $host (PID: $!)"
    done

    # Wait for all remaining transfers to complete
    local failed_hosts=()
    local success_count=0

    for pid in "${pids[@]}"; do
        if [[ -n "$pid" ]]; then
            wait "$pid"
            # The background process output should contain SUCCESS:host or FAILED:host
        fi
    done

    # Count successful transfers by checking if tarballs actually exist on remote hosts
    for host in "${hosts[@]}"; do
        host=$(echo "$host" | xargs)
        if ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "test -f /tmp/ozone_install_${OZONE_VERSION}_parallel/ozone.tar.gz" 2>/dev/null; then
            ((success_count++))
            info "Verified tarball on $host"
        else
            failed_hosts+=("$host")
            warn "Tarball verification failed on $host"
        fi
    done

    info "Parallel tarball transfers completed: $success_count/${#hosts[@]} successful"

    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        warn "Failed transfers to: ${failed_hosts[*]}"
        return 1
    fi

    return 0
}

# Function to download and install Ozone
install_ozone() {
    local host=$1
    local local_tarball_path=$2
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Installing Apache Ozone on $host"

    # Expand the download URL with the actual version
    local download_url=$(echo "$OZONE_DOWNLOAD_URL" | sed "s/\${OZONE_VERSION}/$OZONE_VERSION/g")

    # Check if Ozone is already installed on the remote host
    if ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "test -f \"$OZONE_INSTALL_DIR/bin/ozone\"" 2>/dev/null; then
        info "Ozone already installed on $host, running version check..."
        ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
            echo \"Ozone already installed at $OZONE_INSTALL_DIR\"
            # Set up environment variables for version check
            export JAVA_HOME=/usr/lib/jvm/java
            export OZONE_HOME=\"$OZONE_INSTALL_DIR\"
            # Find and use the actual JAVA_HOME if java is installed
            if command -v java >/dev/null 2>&1; then
                java_bin=\$(which java)
                if [[ -L \"\$java_bin\" ]]; then
                    java_bin=\$(readlink -f \"\$java_bin\")
                fi
                export JAVA_HOME=\$(dirname \"\$(dirname \"\$java_bin\")\")
            fi
            \"$OZONE_INSTALL_DIR/bin/ozone\" version
        "
        info "Skipping installation on $host - Ozone already present"
        return 0
    fi

    # Proceed with installation - check if tarball was already transferred via parallel SCP
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        # Create temporary directory for installation (same as used in parallel transfer)
        temp_dir=\"/tmp/ozone_install_${OZONE_VERSION}_parallel\"
        mkdir -p \"\$temp_dir\"
        cd \"\$temp_dir\"

        # Check if tarball was already transferred via parallel SCP
        if [[ -f \"ozone.tar.gz\" ]]; then
            echo \"Using tarball transferred via parallel SCP\"
        else
            echo \"Tarball not found in parallel transfer directory, falling back to direct download...\"

            if command -v wget >/dev/null 2>&1; then
                wget \"$download_url\" -O ozone.tar.gz
            elif command -v curl >/dev/null 2>&1; then
                curl -L \"$download_url\" -o ozone.tar.gz
            else
                echo \"ERROR: Neither wget nor curl found. Cannot download Ozone.\"
                exit 1
            fi

            # Verify download
            if [[ ! -f ozone.tar.gz ]]; then
                echo \"ERROR: Failed to download Ozone from $download_url\"
                exit 1
            fi
        fi

        echo \"Extracting Ozone...\"
        tar -xzf ozone.tar.gz

        # Find the extracted directory (should be ozone-X.Y.Z)
        ozone_dir=\$(find . -maxdepth 1 -type d -name \"ozone-*\" | head -1)
        if [[ -z \"\$ozone_dir\" ]]; then
            echo \"ERROR: Could not find extracted Ozone directory\"
            exit 1
        fi

        echo \"Installing Ozone to $OZONE_INSTALL_DIR...\"

        # Create install directory and move files
        sudo mkdir -p \"$OZONE_INSTALL_DIR\"
        sudo mv \"\$ozone_dir\"/* \"$OZONE_INSTALL_DIR/\"

        # Set proper ownership and permissions
        sudo chown -R \$(whoami):\$(id -gn) \"$OZONE_INSTALL_DIR\"
        sudo chmod -R 755 \"$OZONE_INSTALL_DIR\"
        sudo chmod +x \"$OZONE_INSTALL_DIR/bin/ozone\"
        sudo chmod +x \"$OZONE_INSTALL_DIR/bin\"/*

        # Create symlink in /usr/local/bin for global access
        if [[ ! -f /usr/local/bin/ozone ]]; then
            sudo ln -sf \"$OZONE_INSTALL_DIR/bin/ozone\" /usr/local/bin/ozone
        fi

        # Add to PATH in profile
        if ! grep -q \"$OZONE_INSTALL_DIR/bin\" /etc/environment 2>/dev/null; then
            if [[ -f /etc/environment ]]; then
                sudo sed -i 's|PATH=\"\\([^\"]*\\)\"|PATH=\"\\1:$OZONE_INSTALL_DIR/bin\"|' /etc/environment
            else
                echo \"PATH=\\\$PATH:$OZONE_INSTALL_DIR/bin\" | sudo tee /etc/environment > /dev/null
            fi
        fi

        # Clean up
        cd /
        rm -rf \"\$temp_dir\"

        # Verify installation
        if [[ -f \"$OZONE_INSTALL_DIR/bin/ozone\" ]]; then
            echo \"Ozone installation successful:\"
            # Set up environment variables for version check
            export JAVA_HOME=/usr/lib/jvm/java
            export OZONE_HOME=\"$OZONE_INSTALL_DIR\"
            # Find and use the actual JAVA_HOME if java is installed
            if command -v java >/dev/null 2>&1; then
                java_bin=\$(which java)
                if [[ -L \"\$java_bin\" ]]; then
                    java_bin=\$(readlink -f \"\$java_bin\")
                fi
                export JAVA_HOME=\$(dirname \"\$(dirname \"\$java_bin\")\")
            fi
            \"$OZONE_INSTALL_DIR/bin/ozone\" version
            echo \"Ozone installed at: $OZONE_INSTALL_DIR\"
            echo \"Ozone binary symlinked to: /usr/local/bin/ozone\"
        else
            echo \"ERROR: Ozone installation verification failed\"
            exit 1
        fi
    "
}

# Function to install Prometheus
install_prometheus() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Installing Prometheus on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        # Check if Prometheus is already installed
        if [[ -f \"$PROMETHEUS_INSTALL_DIR/prometheus\" ]]; then
            echo \"Prometheus already installed at $PROMETHEUS_INSTALL_DIR\"
            \"$PROMETHEUS_INSTALL_DIR/prometheus\" --version 2>/dev/null || echo \"Prometheus version check failed\"
            return 0
        fi

        echo \"Downloading Prometheus $PROMETHEUS_VERSION...\"

        # Create temporary directory for download
        temp_dir=\"/tmp/prometheus_install_\$\$\"
        mkdir -p \"\$temp_dir\"
        cd \"\$temp_dir\"

        # Detect architecture
        arch=\$(uname -m)
        case \"\$arch\" in
            x86_64)
                arch_name=\"amd64\"
                ;;
            aarch64|arm64)
                arch_name=\"arm64\"
                ;;
            *)
                echo \"ERROR: Unsupported architecture: \$arch\"
                exit 1
                ;;
        esac

        # Download Prometheus
        prometheus_url=\"https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-\${arch_name}.tar.gz\"

        if command -v wget >/dev/null 2>&1; then
            wget \"\$prometheus_url\" -O prometheus.tar.gz
        elif command -v curl >/dev/null 2>&1; then
            curl -L \"\$prometheus_url\" -o prometheus.tar.gz
        else
            echo \"ERROR: Neither wget nor curl found. Cannot download Prometheus.\"
            exit 1
        fi

        # Verify download
        if [[ ! -f prometheus.tar.gz ]]; then
            echo \"ERROR: Failed to download Prometheus from \$prometheus_url\"
            exit 1
        fi

        echo \"Extracting Prometheus...\"
        tar -xzf prometheus.tar.gz

        # Find the extracted directory
        prometheus_dir=\$(find . -maxdepth 1 -type d -name \"prometheus-*\" | head -1)
        if [[ -z \"\$prometheus_dir\" ]]; then
            echo \"ERROR: Could not find extracted Prometheus directory\"
            exit 1
        fi

        echo \"Installing Prometheus to $PROMETHEUS_INSTALL_DIR...\"

        # Create install and data directories
        sudo mkdir -p \"$PROMETHEUS_INSTALL_DIR\"
        sudo mkdir -p \"$PROMETHEUS_DATA_DIR\"

        # Move binaries and configuration files
        sudo mv \"\$prometheus_dir\"/prometheus \"$PROMETHEUS_INSTALL_DIR/\"
        sudo mv \"\$prometheus_dir\"/promtool \"$PROMETHEUS_INSTALL_DIR/\"
        sudo mv \"\$prometheus_dir\"/prometheus.yml \"$PROMETHEUS_INSTALL_DIR/\"
        sudo mv \"\$prometheus_dir\"/console_libraries \"$PROMETHEUS_INSTALL_DIR/\"
        sudo mv \"\$prometheus_dir\"/consoles \"$PROMETHEUS_INSTALL_DIR/\"

        # Set proper ownership and permissions
        sudo chown -R \$(whoami):\$(id -gn) \"$PROMETHEUS_INSTALL_DIR\"
        sudo chown -R \$(whoami):\$(id -gn) \"$PROMETHEUS_DATA_DIR\"
        sudo chmod +x \"$PROMETHEUS_INSTALL_DIR/prometheus\"
        sudo chmod +x \"$PROMETHEUS_INSTALL_DIR/promtool\"

        # Create symlink in /usr/local/bin for global access
        if [[ ! -f /usr/local/bin/prometheus ]]; then
            sudo ln -sf \"$PROMETHEUS_INSTALL_DIR/prometheus\" /usr/local/bin/prometheus
        fi
        if [[ ! -f /usr/local/bin/promtool ]]; then
            sudo ln -sf \"$PROMETHEUS_INSTALL_DIR/promtool\" /usr/local/bin/promtool
        fi

        # Clean up
        cd /
        rm -rf \"\$temp_dir\"

        # Verify installation
        if [[ -f \"$PROMETHEUS_INSTALL_DIR/prometheus\" ]]; then
            echo \"Prometheus installation successful:\"
            \"$PROMETHEUS_INSTALL_DIR/prometheus\" --version
            echo \"Prometheus installed at: $PROMETHEUS_INSTALL_DIR\"
            echo \"Prometheus data directory: $PROMETHEUS_DATA_DIR\"
            echo \"Prometheus binaries symlinked to: /usr/local/bin/\"
        else
            echo \"ERROR: Prometheus installation failed\"
            exit 1
        fi
    "
}

# Function to install Grafana
install_grafana() {
    local host=$1
    local ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

    info "Installing Grafana on $host"

    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        # Check if Grafana is already installed
        if command -v grafana-server >/dev/null 2>&1; then
            echo \"Grafana already installed\"
            grafana-server --version 2>/dev/null || echo \"Grafana version check failed\"
            return 0
        fi

        # Detect package manager and distribution
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

        # Install Grafana based on package manager
        case \$PKG_MGR in
            \"yum\"|\"dnf\")
                # Add Grafana repository
                sudo tee /etc/yum.repos.d/grafana.repo << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
                # Install Grafana
                sudo \$PKG_MGR install -y grafana
                ;;

            \"apt-get\")
                # Install prerequisites
                sudo apt-get update
                sudo apt-get install -y apt-transport-https software-properties-common wget

                # Add Grafana GPG key
                sudo mkdir -p /etc/apt/keyrings/
                wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

                # Add Grafana repository
                echo \"deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main\" | sudo tee -a /etc/apt/sources.list.d/grafana.list

                # Update package list and install Grafana
                sudo apt-get update
                sudo apt-get install -y grafana
                ;;

            \"zypper\")
                # Add Grafana repository
                sudo zypper addrepo https://rpm.grafana.com grafana
                sudo zypper --gpg-auto-import-keys refresh

                # Install Grafana
                sudo zypper install -y grafana
                ;;
        esac

        # Create data and logs directories
        sudo mkdir -p \"$GRAFANA_DATA_DIR\"
        sudo mkdir -p \"$GRAFANA_LOGS_DIR\"

        # Set proper ownership
        sudo chown -R grafana:grafana \"$GRAFANA_DATA_DIR\"
        sudo chown -R grafana:grafana \"$GRAFANA_LOGS_DIR\"

        # Verify installation
        if command -v grafana-server >/dev/null 2>&1; then
            echo \"Grafana installation successful:\"
            grafana-server --version
            echo \"Grafana data directory: $GRAFANA_DATA_DIR\"
            echo \"Grafana logs directory: $GRAFANA_LOGS_DIR\"
            echo \"Note: Use 'sudo systemctl start grafana-server' to start Grafana\"
            echo \"Note: Use 'sudo systemctl enable grafana-server' to enable auto-start\"
        else
            echo \"ERROR: Grafana installation failed\"
            exit 1
        fi
    "
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

        # Check sudo privileges
        if ! check_sudo_privileges "$host"; then
            exit 1
        fi
    done

    # Ask for JDK version
    jdk_version=$(ask_jdk_version)
    log "Selected JDK version: $jdk_version"

    # Download Ozone tarball centrally for distribution
    log "Downloading Ozone tarball centrally for efficient distribution..."
    local_tarball_path=$(download_ozone_centrally)
    download_exit_code=$?

    if [[ $download_exit_code -ne 0 ]] || [[ -z "$local_tarball_path" ]]; then
        warn "Failed to download Ozone centrally (exit code: $download_exit_code, path: '$local_tarball_path')"
        warn "Will attempt to use existing local files or fall back to individual downloads"

        # Try to find existing tarball for parallel transfer even if central download failed
        if [[ -n "${LOCAL_TARBALL_PATH:-}" ]] && [[ -f "$LOCAL_TARBALL_PATH" ]]; then
            local_tarball_path="$LOCAL_TARBALL_PATH"
            info "Found existing custom tarball: $LOCAL_TARBALL_PATH"
        elif [[ -f "/tmp/ozone-${OZONE_VERSION}.tar.gz" ]]; then
            local_tarball_path="/tmp/ozone-${OZONE_VERSION}.tar.gz"
            info "Found existing downloaded tarball: $local_tarball_path"
        else
            local_tarball_path=""
            info "No existing tarball found for parallel transfer"
        fi
    else
        info "Successfully obtained tarball for distribution: $local_tarball_path"
    fi

    # Perform parallel tarball transfer to all hosts (if tarball available)
    parallel_transfer_success=false
    if [[ -n "$local_tarball_path" ]] && [[ -f "$local_tarball_path" ]]; then
        log "Starting parallel tarball transfer using: $local_tarball_path"
        if transfer_tarball_parallel "$local_tarball_path" "${HOSTS[@]}"; then
            parallel_transfer_success=true
            log "Parallel tarball transfers completed successfully"
        else
            warn "Some parallel tarball transfers failed - affected hosts will fall back to direct download"
        fi
    else
        log "No local tarball available - hosts will download directly from Apache"
        log "Reasons: local_tarball_path='$local_tarball_path', file_exists=$(test -f "$local_tarball_path" && echo "yes" || echo "no")"
    fi

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

        # Install Apache Ozone (tarball already transferred in parallel)
        install_ozone "$host" "$local_tarball_path"

        # Install Prometheus if enabled
        if [[ "${INSTALL_PROMETHEUS,,}" == "true" ]]; then
            install_prometheus "$host"
        else
            log "Skipping Prometheus installation (INSTALL_PROMETHEUS=$INSTALL_PROMETHEUS)"
        fi

        # Install Grafana if enabled
        if [[ "${INSTALL_GRAFANA,,}" == "true" ]]; then
            install_grafana "$host"
        else
            log "Skipping Grafana installation (INSTALL_GRAFANA=$INSTALL_GRAFANA)"
        fi

        log "Host $host configuration completed"
    done

    # Preserve centrally downloaded tarball for future reuse
    if [[ -n "$local_tarball_path" ]] && [[ "$local_tarball_path" == "/tmp/ozone-"* ]] && [[ -f "$local_tarball_path" ]]; then
        log "Preserving centrally downloaded tarball for reuse: $local_tarball_path"
    fi

    log "Ozone Installer completed successfully"
    log "Next steps:"
    log "1. Run ./generate_configurations.sh to create Ozone configuration files"
    log "2. Run ./start_ozone_services.sh to start Ozone services"

    if [[ "${INSTALL_PROMETHEUS,,}" == "true" ]] || [[ "${INSTALL_GRAFANA,,}" == "true" ]]; then
        log ""
        log "Observability tools installed:"
        if [[ "${INSTALL_PROMETHEUS,,}" == "true" ]]; then
            log "- Prometheus: $PROMETHEUS_INSTALL_DIR (port $PROMETHEUS_PORT)"
        fi
        if [[ "${INSTALL_GRAFANA,,}" == "true" ]]; then
            log "- Grafana: installed via package manager (port $GRAFANA_PORT)"
        fi
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
