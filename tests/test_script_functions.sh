#!/bin/bash

# Unit tests for functions in shell scripts
# Tests basic functionality of key functions in each script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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

# Test configuration loading function
test_config_loading() {
    echo "Testing configuration loading functions..."

    # Create a temporary config file for testing
    local temp_config="/tmp/test_ozone_installer.conf"
    cat > "$temp_config" << EOF
SSH_USER="testuser"
SSH_PRIVATE_KEY_FILE="/tmp/testkey"
SSH_PORT="2222"
CLUSTER_HOSTS="testhost1 testhost2"
OZONE_VERSION="1.0.0"
EOF

    # Test that config loading works
    run_test "Config file can be parsed" \
        "source $temp_config && test \"\$SSH_USER\" = 'testuser' && test \"\$OZONE_VERSION\" = '1.0.0'" \
        0

    run_test "Config file contains required variables" \
        "source $temp_config && [ -n '\$SSH_USER' ] && [ -n '\$CLUSTER_HOSTS' ]" \
        0

    # Clean up
    rm -f "$temp_config"
}

# Test logging functions by sourcing them
test_logging_functions() {
    echo "Testing logging functions..."

    # Source the generate_configurations.sh to get logging functions
    local config_script="$PROJECT_DIR/generate_configurations.sh"

    run_test "Logging functions exist in generate_configurations.sh" \
        "grep -q '^log()' $config_script && grep -q '^error()' $config_script && grep -q '^info()' $config_script" \
        0

    run_test "Logging functions exist in ozone_installer.sh" \
        "grep -q '^log()' $PROJECT_DIR/ozone_installer.sh && grep -q '^error()' $PROJECT_DIR/ozone_installer.sh" \
        0

    run_test "Logging functions exist in start_ozone_services.sh" \
        "grep -q '^log()' $PROJECT_DIR/start_ozone_services.sh && grep -q '^error()' $PROJECT_DIR/start_ozone_services.sh" \
        0
}

# Test configuration file validation
test_config_validation() {
    echo "Testing configuration validation..."

    # Test that load_config function exists
    run_test "load_config function exists in generate_configurations.sh" \
        "grep -q '^load_config()' $PROJECT_DIR/generate_configurations.sh" \
        0

    run_test "load_config function exists in ozone_installer.sh" \
        "grep -q '^load_config()' $PROJECT_DIR/ozone_installer.sh" \
        0

    run_test "load_config function exists in start_ozone_services.sh" \
        "grep -q '^load_config()' $PROJECT_DIR/start_ozone_services.sh" \
        0
}

# Test SSH validation functions
test_ssh_validation() {
    echo "Testing SSH validation functions..."

    run_test "SSH validation function exists in ozone_installer.sh" \
        "grep -q 'validate_ssh_connection()' $PROJECT_DIR/ozone_installer.sh" \
        0

    run_test "SSH validation checks private key file" \
        "grep -A10 'validate_ssh_connection()' $PROJECT_DIR/ozone_installer.sh | grep -q 'SSH private key file not found'" \
        0
}

# Test parallel configuration functions
test_parallel_configuration() {
    echo "Testing parallel configuration functions..."

    run_test "Parallel host configuration function exists" \
        "grep -q 'configure_hosts_parallel()' $PROJECT_DIR/ozone_installer.sh" \
        0

    run_test "Parallel configuration uses MAX_CONCURRENT_TRANSFERS" \
        "grep -A10 'configure_hosts_parallel()' $PROJECT_DIR/ozone_installer.sh | grep -q 'MAX_CONCURRENT_TRANSFERS'" \
        0

    run_test "Parallel configuration follows same pattern as transfer function" \
        "grep -A5 'configure_hosts_parallel()' $PROJECT_DIR/ozone_installer.sh | grep -q 'max_concurrent.*MAX_CONCURRENT_TRANSFERS'" \
        0

    run_test "Sequential loop was replaced with parallel call" \
        "grep -q 'configure_hosts_parallel.*jdk_version.*local_tarball_path.*HOSTS' $PROJECT_DIR/ozone_installer.sh" \
        0

    run_test "Failed hosts are properly identified and reported" \
        "grep -A10 'Configuration verification failed' $PROJECT_DIR/ozone_installer.sh | grep -q 'failed_hosts.*host'" \
        0

    run_test "Error message includes specific failed hosts" \
        "grep -q 'Host configuration failed on.*failed_hosts' $PROJECT_DIR/ozone_installer.sh" \
        0
}

# Test file generation functions
test_file_generation() {
    echo "Testing file generation functions..."

    run_test "Core site XML generation function exists" \
        "grep -q 'create_core_site_xml()' $PROJECT_DIR/generate_configurations.sh" \
        0

    run_test "Ozone site XML generation function exists" \
        "grep -q 'create_ozone_site_xml()' $PROJECT_DIR/generate_configurations.sh" \
        0

    run_test "Log4j properties generation function exists" \
        "grep -q 'create_log4j_properties()' $PROJECT_DIR/generate_configurations.sh" \
        0
}

# Test host information gathering
test_host_info() {
    echo "Testing host information functions..."

    run_test "Host info gathering function exists" \
        "grep -q 'get_host_info()' $PROJECT_DIR/ozone_installer.sh" \
        0

    run_test "Host OS check function exists" \
        "grep -q 'check_host_os()' $PROJECT_DIR/ozone_installer.sh" \
        0
}

# Test service management functions
test_service_management() {
    echo "Testing service management functions..."

    run_test "SCM format function exists" \
        "grep -q 'format_scm()' $PROJECT_DIR/start_ozone_services.sh" \
        0

    run_test "OM format function exists" \
        "grep -q 'format_om()' $PROJECT_DIR/start_ozone_services.sh" \
        0

    run_test "Service start functions exist" \
        "grep -q 'start.*ozone\|format.*scm\|format.*om' $PROJECT_DIR/start_ozone_services.sh" \
        0
}

# Test script structure and best practices
test_script_structure() {
    echo "Testing script structure and best practices..."

    # Test that all scripts have proper shebangs
    run_test "All scripts have bash shebang" \
        "for script in $PROJECT_DIR/*.sh; do head -1 \"\$script\" | grep -q '^#!/bin/bash' || exit 1; done" \
        0

    # Test that all scripts check if they're being sourced
    run_test "Scripts check if being sourced or executed" \
        "for script in $PROJECT_DIR/{generate_configurations,start_ozone_services,ozone_installer}.sh; do grep -q 'BASH_SOURCE.*0.*0' \"\$script\" || exit 1; done" \
        0
}

# Test JDK configuration functionality
test_jdk_configuration() {
    echo "Testing JDK configuration functions..."

    # Test that ask_jdk_version function exists
    run_test "JDK version function exists" \
        "grep -q 'ask_jdk_version()' $PROJECT_DIR/ozone_installer.sh" \
        0

    # Test that function checks for configured JDK_VERSION
    run_test "JDK version function checks configuration" \
        "grep -q 'if.*JDK_VERSION.*then' $PROJECT_DIR/ozone_installer.sh" \
        0

    # Test that configuration files contain JDK_VERSION comments
    run_test "Multi-host config has JDK_VERSION documentation" \
        "grep -q '# JDK Configuration' $PROJECT_DIR/multi-host.conf && grep -q '# Specify JDK version' $PROJECT_DIR/multi-host.conf" \
        0

    run_test "Single-host config has JDK_VERSION documentation" \
        "grep -q '# JDK Configuration' $PROJECT_DIR/single-host.conf && grep -q '# Specify JDK version' $PROJECT_DIR/single-host.conf" \
        0

    # Test that function validates JDK versions
    run_test "JDK version function validates versions" \
        "grep -q '8|11|17|21' $PROJECT_DIR/ozone_installer.sh" \
        0
}

# Main test execution
main() {
    echo "Running unit tests for shell script functions"
    echo "============================================="

    # Run tests (disable set -e to handle individual test failures)
    set +e
    test_config_loading || true
    test_logging_functions || true
    test_config_validation || true
    test_ssh_validation || true
    test_parallel_configuration || true
    test_file_generation || true
    test_host_info || true
    test_service_management || true
    test_script_structure || true
    test_jdk_configuration || true
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