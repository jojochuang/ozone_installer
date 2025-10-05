#!/bin/bash

# Test Ozone Process Utilities
# This script tests the process management utilities for Docker compatibility

# Note: Do not use set -e as we handle failures explicitly

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Source the utilities
source "$PROJECT_DIR/ozone_process_utils.sh"

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        actual_exit_code=0
    else
        actual_exit_code=$?
    fi
    
    if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Expected exit code: $expected_exit_code"
        echo "  Actual exit code: $actual_exit_code"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Utility script exists and is executable
test_utility_exists() {
    echo "Testing utility script existence..."
    
    run_test "Utility script exists" \
        "test -f '$PROJECT_DIR/ozone_process_utils.sh'" \
        0
    
    run_test "Utility script is executable" \
        "test -x '$PROJECT_DIR/ozone_process_utils.sh'" \
        0
}

# Test 2: Functions are defined
test_functions_defined() {
    echo "Testing function definitions..."
    
    run_test "find_process_by_class function is defined" \
        "declare -f find_process_by_class >/dev/null" \
        0
    
    run_test "is_process_running function is defined" \
        "declare -f is_process_running >/dev/null" \
        0
    
    run_test "kill_process_by_pid function is defined" \
        "declare -f kill_process_by_pid >/dev/null" \
        0
    
    run_test "stop_process_by_class function is defined" \
        "declare -f stop_process_by_class >/dev/null" \
        0
}

# Test 3: find_process_by_class handles non-existent processes
test_find_nonexistent_process() {
    echo "Testing find_process_by_class with non-existent class..."
    
    # Try to find a process that definitely doesn't exist
    result=$(find_process_by_class "org.nonexistent.fake.Class.That.Does.Not.Exist.12345")
    
    run_test "find_process_by_class returns empty for non-existent class" \
        "test -z '$result'" \
        0
}

# Test 4: Scripts source the utility file
test_scripts_source_utility() {
    echo "Testing that main scripts source the utility..."
    
    run_test "stop_ozone_services.sh sources utility" \
        "grep -q 'source.*ozone_process_utils.sh' '$PROJECT_DIR/stop_ozone_services.sh'" \
        0
    
    run_test "start_ozone_services.sh sources utility" \
        "grep -q 'source.*ozone_process_utils.sh' '$PROJECT_DIR/start_ozone_services.sh'" \
        0
    
    run_test "first_time_start_ozone_services.sh sources utility" \
        "grep -q 'source.*ozone_process_utils.sh' '$PROJECT_DIR/first_time_start_ozone_services.sh'" \
        0
}

# Test 5: Inline functions use /proc fallback
test_inline_proc_fallback() {
    echo "Testing inline functions have /proc fallback..."
    
    run_test "stop_ozone_services.sh has /proc fallback for SCM" \
        "grep -q '/proc/\*/cmdline' '$PROJECT_DIR/stop_ozone_services.sh'" \
        0
    
    run_test "start_ozone_services.sh has /proc fallback" \
        "grep -q '/proc/\*/cmdline' '$PROJECT_DIR/start_ozone_services.sh'" \
        0
    
    run_test "first_time_start_ozone_services.sh has /proc fallback" \
        "grep -q '/proc/\*/cmdline' '$PROJECT_DIR/first_time_start_ozone_services.sh'" \
        0
}

# Test 6: Fallback logic checks for command availability
test_command_checks() {
    echo "Testing command availability checks..."
    
    run_test "Utility has ps command check" \
        "grep -q 'command -v ps' '$PROJECT_DIR/ozone_process_utils.sh'" \
        0
    
    run_test "Utility has pgrep command check" \
        "grep -q 'command -v pgrep' '$PROJECT_DIR/ozone_process_utils.sh'" \
        0
    
    run_test "stop_ozone_services.sh has command checks in inline functions" \
        "grep -q 'command -v ps' '$PROJECT_DIR/stop_ozone_services.sh'" \
        0
}

# Test 7: Process detection uses multiple fallback methods
test_fallback_methods() {
    echo "Testing fallback method implementation..."
    
    # Check that find_process_by_class tries ps first, then /proc
    run_test "find_process_by_class tries ps first" \
        "grep -A8 'find_process_by_class()' '$PROJECT_DIR/ozone_process_utils.sh' | grep -q 'ps aux'" \
        0
    
    run_test "find_process_by_class has /proc fallback" \
        "grep -A10 'find_process_by_class()' '$PROJECT_DIR/ozone_process_utils.sh' | grep -q 'grep -l.*proc'" \
        0
}

# Main test runner
main() {
    echo "========================================"
    echo "Ozone Process Utils Test Suite"
    echo "========================================"
    echo ""
    
    test_utility_exists
    test_functions_defined
    test_find_nonexistent_process
    test_scripts_source_utility
    test_inline_proc_fallback
    test_command_checks
    test_fallback_methods
    
    echo ""
    echo "========================================"
    echo "Test Results"
    echo "========================================"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
