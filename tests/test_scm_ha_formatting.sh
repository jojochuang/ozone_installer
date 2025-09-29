#!/bin/bash

# Test script for SCM HA formatting
# Tests that the correct initialization commands are used for SCM nodes in HA setups

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
START_SCRIPT="$PROJECT_DIR/start_ozone_services.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST] $1${NC}"
}

log_pass() {
    echo -e "${GREEN}[PASS] $1${NC}"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL] $1${NC}\n$2"
    ((TESTS_FAILED++))
}

run_test() {
    ((TESTS_RUN++))
    local test_name="$1"
    local test_command="$2"
    
    log_test "$test_name"
    
    if eval "$test_command"; then
        log_pass "$test_name"
    else
        log_fail "$test_name" "Command failed: $test_command"
    fi
}

# Test function to verify SCM HA formatting logic
test_scm_ha_formatting_logic() {
    log_test "SCM formatting function uses correct logic for HA"
    
    # Source the start script to get the format_scm function
    source "$START_SCRIPT"
    
    # Test with single SCM host (should use --init)
    export SCM_HOSTS="scm1"
    export SSH_PRIVATE_KEY_FILE="test_key"
    export SSH_PORT="22"
    export SSH_USER="test"
    
    # Mock ssh command to capture what would be executed
    ssh() {
        local cmd_args="$*"
        # Also capture the full command for debugging
        echo "$cmd_args" > /tmp/full_ssh_command.txt
        return 0
    }
    export -f ssh
    
    # Clear previous results
    rm -f /tmp/full_ssh_command.txt
    
    # Test single SCM (should use --init)
    format_scm "scm1" >/dev/null 2>&1
    
    if grep -q "\-\-init" /tmp/full_ssh_command.txt 2>/dev/null; then
        log_pass "Single SCM uses --init command"
    else
        log_fail "Single SCM should use --init command" "Full command: $(cat /tmp/full_ssh_command.txt 2>/dev/null || echo 'none found')"
        return 1
    fi
    
    # Test multiple SCM hosts (first should use --init, others --bootstrap)
    export SCM_HOSTS="scm1,scm2,scm3"
    rm -f /tmp/full_ssh_command.txt
    
    # Test first SCM node
    format_scm "scm1" >/dev/null 2>&1
    
    if grep -q "\-\-init" /tmp/full_ssh_command.txt 2>/dev/null; then
        log_pass "First SCM in HA uses --init command"
    else
        log_fail "First SCM in HA should use --init command" "Full command: $(cat /tmp/full_ssh_command.txt 2>/dev/null || echo 'none found')"
        return 1
    fi
    
    # Test second SCM node
    rm -f /tmp/full_ssh_command.txt
    format_scm "scm2" >/dev/null 2>&1
    
    if grep -q "\-\-bootstrap" /tmp/full_ssh_command.txt 2>/dev/null; then
        log_pass "Second SCM in HA uses --bootstrap command"
    else
        log_fail "Second SCM in HA should use --bootstrap command" "Full command: $(cat /tmp/full_ssh_command.txt 2>/dev/null || echo 'none found')"
        return 1
    fi
    
    # Test third SCM node
    rm -f /tmp/full_ssh_command.txt
    format_scm "scm3" >/dev/null 2>&1
    
    if grep -q "\-\-bootstrap" /tmp/full_ssh_command.txt 2>/dev/null; then
        log_pass "Third SCM in HA uses --bootstrap command"
    else
        log_fail "Third SCM in HA should use --bootstrap command" "Full command: $(cat /tmp/full_ssh_command.txt 2>/dev/null || echo 'none found')"
        return 1
    fi
    
    # Clean up
    rm -f /tmp/full_ssh_command.txt
    unset -f ssh
}

# Test that the format_scm function exists and has been modified
test_format_scm_function_exists() {
    run_test "format_scm function exists in start script" \
        "grep -q 'format_scm()' '$START_SCRIPT'"
        
    run_test "format_scm function includes SCM HA logic" \
        "grep -q 'SCM HA detected' '$START_SCRIPT'"
        
    run_test "format_scm function uses --bootstrap for non-first nodes" \
        "grep -q 'scm_command=\"--bootstrap\"' '$START_SCRIPT'"
        
    run_test "format_scm function uses variable scm_command in ozone call" \
        "grep -q '\$OZONE_CMD scm \$scm_command' '$START_SCRIPT'"
}

# Main function
main() {
    echo "Testing SCM HA formatting functionality"
    echo "======================================="
    
    test_format_scm_function_exists
    test_scm_ha_formatting_logic
    
    echo
    echo "Test Summary:"
    echo "============="
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "All tests passed!"
        exit 0
    else
        echo "Some tests failed!"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi