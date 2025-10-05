#!/bin/bash

# Ozone Process Management Utilities
# This script provides utility functions for finding and managing Ozone processes
# in environments where ps/pkill commands may not be available (e.g., Docker)

# Function to find process ID by Java main class
# Usage: find_process_by_class "org.apache.hadoop.hdds.scm.server.StorageContainerManager"
# Returns: PID(s) found, one per line, or empty string if not found
find_process_by_class() {
    local class_name="$1"
    local pids=""

    # Try using ps first (standard approach)
    if command -v ps >/dev/null 2>&1; then
        pids=$(ps aux | grep -v grep | grep "$class_name" | awk '{print $2}')
    else
        # Fallback: use /proc filesystem when ps is not available
        # This works in minimal Docker containers
        pids=$(grep -l "$class_name" /proc/*/cmdline 2>/dev/null | sed 's/[^0-9]//g')
    fi

    echo "$pids"
}

# Function to check if a process with given class is running
# Usage: is_process_running "org.apache.hadoop.hdds.scm.server.StorageContainerManager"
# Returns: 0 (true) if running, 1 (false) if not running
is_process_running() {
    local class_name="$1"
    
    # Try using pgrep first (most efficient)
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "$class_name" >/dev/null 2>&1
        return $?
    fi
    
    # Try using ps
    if command -v ps >/dev/null 2>&1; then
        ps aux | grep -v grep | grep "$class_name" >/dev/null 2>&1
        return $?
    fi
    
    # Fallback: use /proc filesystem
    grep -l "$class_name" /proc/*/cmdline 2>/dev/null | head -1 >/dev/null 2>&1
    return $?
}

# Function to kill process by PID with fallback
# Usage: kill_process_by_pid 12345
# Returns: 0 on success, 1 on failure
kill_process_by_pid() {
    local pid="$1"
    
    if [[ -z "$pid" ]]; then
        return 1
    fi
    
    # Try SIGTERM first, then SIGKILL if needed
    if kill -TERM "$pid" 2>/dev/null; then
        return 0
    elif kill -KILL "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to stop processes by class name
# Usage: stop_process_by_class "org.apache.hadoop.hdds.scm.server.StorageContainerManager" "SCM"
# Returns: 0 on success (or if not running), 1 on failure
stop_process_by_class() {
    local class_name="$1"
    local service_name="${2:-Service}"
    
    local pids=$(find_process_by_class "$class_name")
    
    if [[ -n "$pids" ]]; then
        echo "Found $service_name processes: $pids"
        for pid in $pids; do
            echo "Stopping $service_name process $pid..."
            if kill_process_by_pid "$pid"; then
                echo "$service_name process $pid stopped"
            else
                echo "Warning: Failed to stop $service_name process $pid"
            fi
        done
        echo "$service_name stopped successfully"
        return 0
    else
        echo "$service_name is not running"
        return 0
    fi
}

# Export functions for use in other scripts
export -f find_process_by_class
export -f is_process_running
export -f kill_process_by_pid
export -f stop_process_by_class
