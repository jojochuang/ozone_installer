#!/bin/bash

# Directory Permission Verification Script
# This script checks if Ozone directories have the correct permissions
# to prevent "Operation not permitted" errors during OM startup

CONFIG_FILE="$(dirname "$0")/ozone_installer.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

if [[ -z "$CLUSTER_HOSTS" ]]; then
    error "CLUSTER_HOSTS is empty in configuration file"
    exit 1
fi

echo "=== Ozone Directory Permission Verification ==="
echo "This script verifies that Ozone directories have correct permissions"
echo "to prevent 'Operation not permitted' errors during startup."
echo

# Check each host
IFS=',' read -ra HOSTS <<< "$CLUSTER_HOSTS"
for host in "${HOSTS[@]}"; do
    host=$(echo "$host" | xargs)
    
    info "Checking directory permissions on $host"
    
    # Define directories to check
    om_dirs="$OZONE_OM_DB_DIR $OZONE_METADATA_DIRS $OZONE_OM_RATIS_STORAGE_DIR"
    scm_dirs="$OZONE_SCM_DB_DIRS $OZONE_SCM_HA_RATIS_STORAGE_DIR $OZONE_SCM_METADATA_DIRS"
    recon_dirs="$OZONE_RECON_DB_DIR $OZONE_RECON_SCM_DB_DIRS $OZONE_RECON_OM_DB_DIR $OZONE_RECON_METADATA_DIRS"
    datanode_dirs="$OZONE_SCM_DATANODE_ID_DIR $DFS_CONTAINER_RATIS_DATANODE_STORAGE_DIR $HDDS_DATANODE_DIR $OZONE_DATANODE_METADATA_DIRS"
    
    all_dirs="$om_dirs $scm_dirs $recon_dirs $datanode_dirs"
    
    ssh_key_expanded="${SSH_PRIVATE_KEY_FILE/#\~/$HOME}"
    
    ssh -i "$ssh_key_expanded" -p "$SSH_PORT" -o StrictHostKeyChecking=no "$SSH_USER@$host" "
        echo \"Checking directories: $all_dirs\"
        echo
        
        issues_found=false
        
        for dir in $all_dirs; do
            if [[ -n \"\$dir\" ]]; then
                if [[ -d \"\$dir\" ]]; then
                    owner=\$(stat -c '%U:%G' \"\$dir\")
                    perms=\$(stat -c '%a' \"\$dir\")
                    
                    echo \"Directory: \$dir\"
                    echo \"  Owner: \$owner\"
                    echo \"  Permissions: \$perms\"
                    
                    # Check if owned by current user
                    if [[ \"\$owner\" != \"\$(whoami):\$(id -gn)\" ]]; then
                        echo \"  ❌ WARNING: Directory not owned by \$(whoami):\$(id -gn)\"
                        issues_found=true
                    else
                        echo \"  ✅ Ownership is correct\"
                    fi
                    
                    # Check permissions (should be 750 or 755)
                    if [[ \"\$perms\" == \"750\" || \"\$perms\" == \"755\" ]]; then
                        echo \"  ✅ Permissions are appropriate\"
                    else
                        echo \"  ❌ WARNING: Permissions may be too restrictive or too open\"
                        echo \"      Recommended: 750 for data directories\"
                        issues_found=true
                    fi
                    
                    # Test write access
                    if touch \"\$dir/.write_test\" 2>/dev/null; then
                        rm -f \"\$dir/.write_test\"
                        echo \"  ✅ Write access confirmed\"
                    else
                        echo \"  ❌ ERROR: No write access to directory\"
                        issues_found=true
                    fi
                    
                    echo
                else
                    echo \"Directory: \$dir\"
                    echo \"  ❌ ERROR: Directory does not exist\"
                    issues_found=true
                    echo
                fi
            fi
        done
        
        # Check configuration directories
        echo \"Checking configuration directories...\"
        config_dirs=\"/opt/ozone/conf/om /opt/ozone/conf/scm /opt/ozone/conf/datanode /etc/hadoop\"
        
        for dir in \$config_dirs; do
            if [[ -d \"\$dir\" ]]; then
                owner=\$(stat -c '%U:%G' \"\$dir\")
                perms=\$(stat -c '%a' \"\$dir\")
                
                echo \"Config Directory: \$dir\"
                echo \"  Owner: \$owner\"
                echo \"  Permissions: \$perms\"
                
                if [[ \"\$owner\" == \"\$(whoami):\$(id -gn)\" ]]; then
                    echo \"  ✅ Ownership is correct\"
                else
                    echo \"  ❌ WARNING: Directory not owned by \$(whoami):\$(id -gn)\"
                    issues_found=true
                fi
                echo
            fi
        done
        
        if [[ \"\$issues_found\" == \"false\" ]]; then
            echo \"✅ All directory permissions appear to be correct on $host\"
        else
            echo \"❌ Some issues found on $host - see warnings above\"
        fi
    "
    
    echo "----------------------------------------"
done

echo
log "Directory permission verification completed"
log "If issues were found, consider re-running the ozone_installer.sh script"
log "or manually fixing permissions with: sudo chown -R \$(whoami):\$(id -gn) <directory> && sudo chmod -R 750 <directory>"