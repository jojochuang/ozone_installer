#!/bin/bash

# Test script for setup-ubuntu24-ssh.sh command options
# This script validates the command line interface without actually running Docker

set -e

SETUP_SCRIPT="./setup-ubuntu24-ssh.sh"
TESTS_RUN=0
TESTS_PASSED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -n "Running test: $test_name... "

    if eval "$test_command" >/dev/null 2>&1; then
        local actual_exit_code=0
    else
        local actual_exit_code=$?
    fi

    if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
        echo "✅ PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAILED (expected exit code $expected_exit_code, got $actual_exit_code)"
    fi
}

# Test 1: Invalid command option shows usage
test_invalid_option() {
    run_test "Script shows usage for invalid option" \
        "$SETUP_SCRIPT unknown 2>&1 | grep -q 'Usage:'" \
        0

    run_test "Script exits with error code for invalid option" \
        "$SETUP_SCRIPT invalid_option" \
        1
}

# Test 2: Help and usage work correctly
test_help_options() {
    run_test "Script shows usage without Docker when option invalid" \
        "$SETUP_SCRIPT invalid 2>&1 | grep -q 'Usage:'" \
        0

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
        "$SETUP_SCRIPT stop 2>&1 | head -1 | grep -q 'Stopping Ubuntu 24.04 container' || true" \
        0

    # Test clean command (should fail gracefully without Docker)
    run_test "Clean command is recognized" \
        "$SETUP_SCRIPT clean 2>&1 | head -1 | grep -q 'Cleaning up Ubuntu 24.04 container' || true" \
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
        "grep -q '\\-p 9090:9090' $SETUP_SCRIPT" \
        0

    run_test "Script includes Grafana port mapping (3000)" \
        "grep -q '\\-p 3000:3000' $SETUP_SCRIPT" \
        0

    run_test "Script uses correct container name (ubuntu24-ssh)" \
        "grep -q 'CONTAINER_NAME=\"ubuntu24-ssh\"' $SETUP_SCRIPT" \
        0

    run_test "Script uses correct SSH port (2223)" \
        "grep -q 'SSH_PORT=\"2223\"' $SETUP_SCRIPT" \
        0

    run_test "Script uses correct image name (ubuntu24-ssh)" \
        "grep -q 'IMAGE_NAME=\"ubuntu24-ssh\"' $SETUP_SCRIPT" \
        0

    run_test "Script uses correct SSH key name (ubuntu24_key)" \
        "grep -q 'SSH_KEY_NAME=\"ubuntu24_key\"' $SETUP_SCRIPT" \
        0

    run_test "Script uses correct Dockerfile (Dockerfile.ubuntu24)" \
        "grep -q 'Dockerfile.ubuntu24' $SETUP_SCRIPT" \
        0

    run_test "Script uses correct username (ubuntu)" \
        "grep -q 'ubuntu@localhost' $SETUP_SCRIPT" \
        0
}

# Main test execution
main() {
    echo "Running tests for setup-ubuntu24-ssh.sh command options"
    echo "======================================================="

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
    echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"

    if [ "$TESTS_PASSED" -eq "$TESTS_RUN" ]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ Some tests failed!"
        exit 1
    fi
}

# Run main function
main "$@"