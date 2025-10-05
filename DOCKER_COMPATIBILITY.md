# Docker Compatibility

This document describes how the Ozone Installer handles process management in Docker and other minimal environments where standard process management tools may not be available.

## Problem

In minimal Docker containers (such as Alpine, distroless, or custom images), the following commands may not be available:
- `ps` (from procps package)
- `pgrep` (from procps package)
- `pkill` (from procps package)

These tools are commonly used to:
1. Find running processes by name or class
2. Check if a service is already running
3. Stop running services

## Solution

The Ozone Installer implements a **fallback mechanism** that uses the Linux `/proc` filesystem when standard tools are unavailable. This approach works in any Linux environment with the `/proc` filesystem mounted.

### How It Works

#### 1. Process Detection

**Primary Method (when ps is available):**
```bash
ps aux | grep -v grep | grep "org.apache.hadoop.hdds.scm.server.StorageContainerManager" | awk '{print $2}'
```

**Fallback Method (when ps is not available):**
```bash
grep -l "org.apache.hadoop.hdds.scm.server.StorageContainerManager" /proc/*/cmdline 2>/dev/null | sed 's/[^0-9]//g'
```

The fallback works because:
- Every process in Linux has a directory in `/proc/<PID>/`
- The `cmdline` file contains the full command line
- For Java processes, this includes the main class name
- We can search for the class name and extract the PID from the path

#### 2. Process Termination

The solution uses the standard `kill` command which is a shell builtin and always available:
```bash
kill -TERM "$pid" || kill -KILL "$pid"
```

## Implementation

### Utility Library

The core functionality is in `ozone_process_utils.sh`:

```bash
# Find process by Java main class
find_process_by_class "org.apache.hadoop.hdds.scm.server.StorageContainerManager"

# Check if process is running
is_process_running "org.apache.hadoop.ozone.om.OzoneManager"

# Stop process by class name
stop_process_by_class "org.apache.hadoop.ozone.HddsDatanodeService" "DataNode"
```

### Remote Execution

For SSH remote execution (used in all service management scripts), the fallback logic is embedded inline:

```bash
ssh user@host 'bash -s' <<'ENDSSH'
    find_process_by_class() {
        local class_name="$1"
        local pids=""
        if command -v ps >/dev/null 2>&1; then
            pids=$(ps aux | grep -v grep | grep "$class_name" | awk '{print $2}')
        else
            pids=$(grep -l "$class_name" /proc/*/cmdline 2>/dev/null | sed 's/[^0-9]//g')
        fi
        echo "$pids"
    }
    
    # Use the function
    pids=$(find_process_by_class "org.apache.hadoop.hdds.scm.server.StorageContainerManager")
ENDSSH
```

## Affected Scripts

The following scripts have been updated with Docker compatibility:

1. **`stop_ozone_services.sh`** - Stops Ozone services
   - All stop functions (SCM, OM, DataNode, Recon, S3Gateway, HttpFS)
   
2. **`start_ozone_services.sh`** - Starts Ozone services
   - Process detection before starting services
   - Service status checking
   
3. **`first_time_start_ozone_services.sh`** - First-time initialization
   - Process detection before starting services
   - Service status checking

## Testing

### Automated Tests

Run the comprehensive test suite:
```bash
./tests/test_process_utils.sh
```

This validates:
- ✅ Utility functions are defined correctly
- ✅ Process detection works with real and non-existent processes
- ✅ All scripts properly integrate the utility
- ✅ Fallback mechanism is implemented correctly

### Interactive Demonstration

See the fallback in action:
```bash
./tests/test_docker_fallback.sh
```

This demonstrates:
- Normal environment operation
- Process detection behavior
- Fallback mechanism documentation

### Manual Testing in Docker

To test in a minimal Docker container:

```bash
# Create a minimal container without procps
docker run -it --rm alpine:latest sh

# Install only bash (not procps)
apk add bash

# Verify ps/pgrep are not available
command -v ps    # Should return nothing
command -v pgrep # Should return nothing

# The scripts will automatically use /proc fallback
```

## Supported Environments

| Environment | Standard Tools | Fallback | Status |
|------------|---------------|----------|---------|
| Ubuntu/Debian/RHEL (full) | ✅ | N/A | ✅ Supported |
| Alpine Linux (base) | ❌ | ✅ | ✅ Supported |
| Distroless containers | ❌ | ✅ | ✅ Supported |
| Minimal custom images | ❌ | ✅ | ✅ Supported |
| Any Linux with /proc | Varies | ✅ | ✅ Supported |

## Performance Considerations

- **Primary method** (`ps aux | grep`): Fast, optimized for interactive use
- **Fallback method** (`grep /proc/*/cmdline`): Slightly slower for many processes
- Both methods are suitable for service management (not high-frequency operations)

## Limitations

The fallback method requires:
1. `/proc` filesystem must be mounted
2. Read access to `/proc/*/cmdline` files
3. Sufficient permissions to read process information

These are standard in all Linux environments where process management is needed.

## Maintenance

When adding new services:
1. Use the `find_process_by_class()` pattern for consistency
2. Include fallback logic in remote SSH blocks
3. Test with both standard and minimal environments
4. Update tests to cover the new service

## References

- Issue: "Apply alternatives to kill process if ps is not found"
- Implementation: `ozone_process_utils.sh`
- Tests: `tests/test_process_utils.sh`, `tests/test_docker_fallback.sh`
- Linux `/proc` documentation: https://man7.org/linux/man-pages/man5/proc.5.html
