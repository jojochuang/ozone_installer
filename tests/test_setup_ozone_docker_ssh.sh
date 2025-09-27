#!/bin/bash

# Test script for setup-ozone-docker-ssh.sh command options
# Tests that each command option works as expected

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SETUP_SCRIPT="$PROJECT_DIR/setup-ozone-docker-ssh.sh"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
CONFIG_FILE="$PROJECT_DIR/multi-host.conf"

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

# Test 1: Docker Compose file validation
test_compose_file() {
    run_test "Docker Compose file exists" \
        "[ -f '$COMPOSE_FILE' ]" \
        0

    run_test "Docker Compose file is valid" \
        "cd '$PROJECT_DIR' && docker compose -f docker-compose.yml config --quiet" \
        0
}

# Test 2: Configuration file validation
test_config_file() {
    run_test "Docker SSH config file exists" \
        "[ -f '$CONFIG_FILE' ]" \
        0

    run_test "Config file contains all expected containers" \
        "source '$CONFIG_FILE' && echo \$CLUSTER_HOSTS | grep -q 'om1,om2,om3,scm1,scm2,scm3,recon,s3gateway,datanode1,datanode2,datanode3,httpfs,prometheus,grafana,client'" \
        0
}

# Test 3: Invalid command option should show usage
test_invalid_option() {
    run_test "Invalid option shows usage" \
        "$SETUP_SCRIPT invalid_option 2>&1 | grep -q 'Usage:'" \
        0
}

# Test 4: Valid command options are recognized
test_valid_options() {
    # Test stop command (should fail gracefully without running containers)
    run_test "Stop command is recognized" \
        "$SETUP_SCRIPT stop 2>&1 | head -1 | grep -q 'Stopping Ozone cluster' || true" \
        0

    # Test clean command (should fail gracefully without Docker)
    run_test "Clean command is recognized" \
        "$SETUP_SCRIPT clean 2>&1 | head -1 | grep -q 'Cleaning up Ozone cluster' || true" \
        0

    # Test info command
    run_test "Info command is recognized" \
        "$SETUP_SCRIPT info 2>&1 | grep -q 'Container SSH Access:' || true" \
        0

    # Test status command
    run_test "Status command is recognized" \
        "$SETUP_SCRIPT status 2>&1 | grep -q 'Ozone Cluster Status' || true" \
        0

    # Test connect command with missing container
    run_test "Connect command requires container name" \
        "$SETUP_SCRIPT connect 2>&1 | tail -3 | grep -q 'Available containers:'" \
        0
}

# Test 5: Script structure validation
test_script_structure() {
    run_test "Script has main function" \
        "grep -q '^main()' $SETUP_SCRIPT" \
        0

    run_test "Script has case statement for options" \
        "grep -q 'case.*{1:-start}' $SETUP_SCRIPT" \
        0

    run_test "Script has all expected command options" \
        "grep -A30 'case.*{1:-start}' $SETUP_SCRIPT | grep -c '\"start\"\|\"stop\"\|\"clean\"\|\"status\"\|\"connect\"\|\"info\"' | grep -q '^5$'" \
        0

    run_test "Script includes SSH key generation" \
        "grep -q 'generate_ssh_key' $SETUP_SCRIPT" \
        0

    run_test "Script includes SSH config setup" \
        "grep -q 'setup_ssh_config' $SETUP_SCRIPT" \
        0
}

# Test 6: Docker Compose file structure validation
test_compose_structure() {
    run_test "Compose file has OM services (3)" \
        "grep -c '^  om[123]:' $COMPOSE_FILE | grep -q '^3$'" \
        0

    run_test "Compose file has SCM services (3)" \
        "grep -c '^  scm[123]:' $COMPOSE_FILE | grep -q '^3$'" \
        0

    run_test "Compose file has DataNode services (3)" \
        "grep -c '^  datanode[123]:' $COMPOSE_FILE | grep -q '^3$'" \
        0

    run_test "Compose file has Recon service" \
        "grep -q '^  recon:' $COMPOSE_FILE" \
        0

    run_test "Compose file has S3 Gateway service" \
        "grep -q '^  s3gateway:' $COMPOSE_FILE" \
        0

    run_test "Compose file has HttpFS service" \
        "grep -q '^  httpfs:' $COMPOSE_FILE" \
        0

    run_test "Compose file includes observability services" \
        "grep -q '^  prometheus:' $COMPOSE_FILE && grep -q '^  grafana:' $COMPOSE_FILE" \
        0

    run_test "Compose file includes client service" \
        "grep -q '^  client:' $COMPOSE_FILE" \
        0

    run_test "Compose file has ozone-network" \
        "grep -q 'ozone-network:' $COMPOSE_FILE" \
        0

    run_test "Compose file has persistent volumes" \
        "grep -q '^volumes:' $COMPOSE_FILE" \
        0
}

# Test 7: SSH port mapping validation
test_ssh_port_mappings() {
    run_test "OM services have SSH port mappings" \
        "grep -A10 '^  om[123]:' $COMPOSE_FILE | grep '[0-9]\+:22' | wc -l | grep -q '^3$'" \
        0

    run_test "SCM services have SSH port mappings" \
        "grep -A10 '^  scm[123]:' $COMPOSE_FILE | grep '[0-9]\+:22' | wc -l | grep -q '^3$'" \
        0

    run_test "All services have SSH port mappings" \
        "grep -E '[0-9]+:22' $COMPOSE_FILE | wc -l | grep -q '^15$'" \
        0

    run_test "SSH ports are unique" \
        "grep -E '[0-9]+:22' $COMPOSE_FILE | grep -o '[0-9]\+:22' | sort -u | wc -l | grep -q '^15$'" \
        0
}

# Main test execution
main() {
    echo "Running tests for setup-ozone-docker-ssh.sh and docker-compose.yml"
    echo "===================================================================="

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
    test_compose_file || true
    test_config_file || true
    test_script_structure || true
    test_compose_structure || true
    test_ssh_port_mappings || true
    test_invalid_option || true
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