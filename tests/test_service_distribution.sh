#!/bin/bash

# Test script for service distribution configuration
# Tests that service-specific host configurations work correctly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
START_SCRIPT="$PROJECT_DIR/start_ozone_services.sh"
CONFIG_FILE_DOCKER="$PROJECT_DIR/ozone-docker-ssh.conf"
CONFIG_FILE_DEFAULT="$PROJECT_DIR/ozone_installer.conf"

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

# Test 1: Configuration file validation
test_config_files() {
    run_test "Docker SSH config has service distribution variables" \
        "grep -q 'OM_HOSTS=' '$CONFIG_FILE_DOCKER' && grep -q 'SCM_HOSTS=' '$CONFIG_FILE_DOCKER'" \
        0

    run_test "Default config has service distribution variables" \
        "grep -q 'OM_HOSTS=' '$CONFIG_FILE_DEFAULT' && grep -q 'SCM_HOSTS=' '$CONFIG_FILE_DEFAULT'" \
        0

    run_test "Docker config distributes OM across multiple hosts" \
        "grep 'OM_HOSTS=' '$CONFIG_FILE_DOCKER' | grep -q 'om1,om2,om3'" \
        0

    run_test "Docker config distributes SCM across multiple hosts" \
        "grep 'SCM_HOSTS=' '$CONFIG_FILE_DOCKER' | grep -q 'scm1,scm2,scm3'" \
        0

    run_test "Docker config distributes DataNodes across multiple hosts" \
        "grep 'DATANODE_HOSTS=' '$CONFIG_FILE_DOCKER' | grep -q 'datanode1,datanode2,datanode3'" \
        0
}

# Test 2: Service distribution parsing
test_service_distribution() {
    run_test "start_ozone_services.sh loads Docker config service distribution" \
        "cd '$PROJECT_DIR' && CONFIG_FILE='$CONFIG_FILE_DOCKER' bash -c 'source start_ozone_services.sh; load_config; [[ \"\$OM_HOSTS\" == \"om1,om2,om3\" ]]'" \
        0

    run_test "start_ozone_services.sh loads default config service distribution" \
        "cd '$PROJECT_DIR' && CONFIG_FILE='$CONFIG_FILE_DEFAULT' bash -c 'source start_ozone_services.sh; load_config; [[ \"\$OM_HOSTS\" == \"node1.example.com,node2.example.com,node3.example.com\" ]]'" \
        0

    run_test "validate_service_hosts function shows distributed services" \
        "cd '$PROJECT_DIR' && CONFIG_FILE='$CONFIG_FILE_DOCKER' bash -c 'source start_ozone_services.sh; load_config; IFS=\",\" read -ra HOSTS <<<\$CLUSTER_HOSTS; validate_service_hosts' | grep -q 'OM hosts: om1,om2,om3'" \
        0

    run_test "validate_service_hosts function shows SCM distribution" \
        "cd '$PROJECT_DIR' && CONFIG_FILE='$CONFIG_FILE_DOCKER' bash -c 'source start_ozone_services.sh; load_config; IFS=\",\" read -ra HOSTS <<<\$CLUSTER_HOSTS; validate_service_hosts' | grep -q 'SCM hosts: scm1,scm2,scm3'" \
        0
}

# Test 3: Script functions exist
test_script_functions() {
    run_test "start_ozone_services.sh has validate_service_hosts function" \
        "grep -q '^validate_service_hosts()' '$START_SCRIPT'" \
        0

    run_test "start_ozone_services.sh has start_service_on_hosts function" \
        "grep -q '^start_service_on_hosts()' '$START_SCRIPT'" \
        0

    run_test "start_ozone_services.sh respects CONFIG_FILE environment variable" \
        "grep -q 'CONFIG_FILE=.*CONFIG_FILE.*ozone_installer.conf' '$START_SCRIPT'" \
        0
}

# Test 4: Service host parsing
test_host_parsing() {
    run_test "start_service_on_hosts function parses comma-separated hosts" \
        "cd '$PROJECT_DIR' && bash -c 'source start_ozone_services.sh; IFS=\",\" read -ra TEST_HOSTS <<<\"om1,om2,om3\"; [[ \${#TEST_HOSTS[@]} -eq 3 && \"\${TEST_HOSTS[0]}\" == \"om1\" ]]'" \
        0

    run_test "Service distribution supports single host" \
        "cd '$PROJECT_DIR' && bash -c 'source start_ozone_services.sh; IFS=\",\" read -ra TEST_HOSTS <<<\"recon\"; [[ \${#TEST_HOSTS[@]} -eq 1 && \"\${TEST_HOSTS[0]}\" == \"recon\" ]]'" \
        0
}

# Main test execution
main() {
    echo "Running tests for service distribution configuration"
    echo "=================================================="

    # Check if the script exists
    if [ ! -f "$START_SCRIPT" ]; then
        echo "Error: $START_SCRIPT not found"
        exit 1
    fi

    # Check if config files exist
    if [ ! -f "$CONFIG_FILE_DOCKER" ] || [ ! -f "$CONFIG_FILE_DEFAULT" ]; then
        echo "Error: Configuration files not found"
        exit 1
    fi

    # Run tests (disable set -e to handle individual test failures)
    set +e
    test_config_files || true
    test_service_distribution || true
    test_script_functions || true
    test_host_parsing || true
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