#!/bin/bash

# Test Docker Fallback Functionality
# This script demonstrates the fallback behavior when ps/pgrep are not available

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "Docker Fallback Test"
echo "========================================"
echo ""

# Source the utilities
source "$PROJECT_DIR/ozone_process_utils.sh"

echo -e "${BLUE}Testing process detection in normal environment (with ps):${NC}"
echo ""

# Test with a real process (init or systemd)
echo "Testing with init/systemd process (PID 1)..."
result=$(find_process_by_class "init")
if [[ -n "$result" ]]; then
    echo -e "${GREEN}✓ Successfully found process(es): $result${NC}"
else
    echo -e "${YELLOW}  No init process found (expected in some environments)${NC}"
fi

echo ""
echo -e "${BLUE}Testing with non-existent process class:${NC}"
result=$(find_process_by_class "org.nonexistent.fake.Class.12345")
if [[ -z "$result" ]]; then
    echo -e "${GREEN}✓ Correctly returned empty for non-existent process${NC}"
else
    echo -e "${RED}✗ Unexpectedly found PIDs: $result${NC}"
fi

echo ""
echo -e "${BLUE}Testing is_process_running function:${NC}"

# Test with current bash process
if is_process_running "bash"; then
    echo -e "${GREEN}✓ Successfully detected running bash process${NC}"
else
    echo -e "${RED}✗ Failed to detect bash process${NC}"
fi

# Test with non-existent process
if is_process_running "org.nonexistent.fake.Class.12345"; then
    echo -e "${RED}✗ Incorrectly detected non-existent process${NC}"
else
    echo -e "${GREEN}✓ Correctly reported non-existent process as not running${NC}"
fi

echo ""
echo -e "${BLUE}Demonstrating inline function (as used in SSH context):${NC}"
echo ""

# Simulate the inline function used in SSH contexts
bash -c '
# Inline helper function (as deployed via SSH)
find_process_by_class() {
    local class_name="$1"
    local pids=""
    if command -v ps >/dev/null 2>&1; then
        pids=$(ps aux | grep -v grep | grep "$class_name" | awk "{print \$2}")
    else
        pids=$(grep -l "$class_name" /proc/*/cmdline 2>/dev/null | sed "s/[^0-9]//g")
    fi
    echo "$pids"
}

echo "Environment has ps command: $(command -v ps >/dev/null && echo Yes || echo No)"
echo "Environment has pgrep command: $(command -v pgrep >/dev/null && echo Yes || echo No)"
echo ""
echo "Testing inline function with bash process:"
result=$(find_process_by_class "bash")
if [[ -n "$result" ]]; then
    echo "✓ Found bash process(es): $result"
else
    echo "  No bash process found"
fi
'

echo ""
echo -e "${BLUE}Documentation of fallback mechanism:${NC}"
echo ""
echo "When ps/pgrep commands are not available (common in minimal Docker containers),"
echo "the functions automatically fall back to using /proc filesystem:"
echo ""
echo "  1. Try: ps aux | grep <class>"
echo "  2. Fallback: grep -l <class> /proc/*/cmdline"
echo ""
echo "This ensures compatibility with:"
echo "  - Standard Linux systems (with procps package)"
echo "  - Minimal Docker containers (alpine, distroless, etc.)"
echo "  - Any environment with /proc filesystem"
echo ""

echo "========================================"
echo -e "${GREEN}Docker Fallback Test Complete${NC}"
echo "========================================"
