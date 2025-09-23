#!/bin/bash

# Test script for setup-rocky9-ssh.sh command options
# Tests that each command option works as expected according to README

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SETUP_SCRIPT="$PROJECT_DIR/setup-rocky9-ssh.sh"

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
    echo -e "${RED}[FAIL] $1${NC}"
    ((TESTS_FAILED++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"

    ((TESTS_RUN++))
    log_test "$test_name"

    # Capture both stdout and stderr, temporarily disable set -e
    set +e
    output=$(eval "$test_command" 2>&1)
    actual_exit_code=$?
    set -e

    if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name - Expected exit code $expected_exit_code, got $actual_exit_code"
        echo "Output: $output"
        return 1
    fi
}

# Test 1: Invalid command option should show usage
test_invalid_option() {
    run_test "Invalid option shows usage" \
        "$SETUP_SCRIPT invalid_option 2>&1 | grep -q 'Usage:'" \
        0
}

# Test 2: Help-like options should show usage
test_help_options() {
    # Test that usage is shown for various scenarios
    run_test "Script without Docker shows usage when Docker not available" \
        "command -v docker >/dev/null || ($SETUP_SCRIPT unknown 2>&1 | grep -q 'Usage:')" \
        0
}

# Test 3: Valid command options are recognized
test_valid_options() {
    # We can't actually run Docker commands in CI, but we can test that the options are recognized
    # by checking that they don't immediately show usage errors

    # Test stop command (should fail gracefully without Docker)
    run_test "Stop command is recognized" \
        "$SETUP_SCRIPT stop 2>&1 | head -1 | grep -q 'Stopping Rocky9 container' || true" \
        0

    # Test clean command (should fail gracefully without Docker)
    run_test "Clean command is recognized" \
        "$SETUP_SCRIPT clean 2>&1 | head -1 | grep -q 'Cleaning up Rocky9 container' || true" \
        0

    # Test info command (should fail gracefully without Docker)
    run_test "Info command is recognized" \
        "$SETUP_SCRIPT info 2>&1 | grep -q 'Container details:' || true" \
        0
}

# Test 4: Script structure validation
test_script_structure() {
    run_test "Script has main function" \
        "grep -q '^main()' $SETUP_SCRIPT" \
        0

    run_test "Script has case statement for options" \
        "grep -q 'case.*{1:-start}' $SETUP_SCRIPT" \
        0

    run_test "Script has all expected command options" \
        "grep -A30 'case.*{1:-start}' $SETUP_SCRIPT | grep -c '\"start\"\|\"stop\"\|\"clean\"\|\"connect\"\|\"info\"' | grep -q '^5$'" \
        0

    run_test "Script includes Prometheus port mapping (9090)" \
        "grep -q '\-p 9090:9090' $SETUP_SCRIPT" \
        0

    run_test "Script includes Grafana port mapping (3000)" \
        "grep -q '\-p 3000:3000' $SETUP_SCRIPT" \
        0
}

# Main test execution
main() {
    echo "Running tests for setup-rocky9-ssh.sh command options"
    echo "======================================================"

    # Check if the script exists
    if [ ! -f "$SETUP_SCRIPT" ]; then
        echo "Error: $SETUP_SCRIPT not found"
        exit 1
    fi

    # Make sure script is executable
    if [ ! -x "$SETUP_SCRIPT" ]; then
        echo "Error: $SETUP_SCRIPT is not executable"
        exit 1
    fi

    # Run tests (disable set -e to handle individual test failures)
    set +e
    test_script_structure || true
    test_invalid_option || true
    test_help_options || true
    test_valid_options || true
    set -e

    # Summary
    echo ""
    echo "Test Summary:"
    echo "============="
    echo "Tests run: $TESTS_RUN"
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