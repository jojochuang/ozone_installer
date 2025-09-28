#!/bin/bash

# Test script for HA configuration generation
# Tests that OM HA and SCM HA configurations are generated correctly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GENERATE_SCRIPT="$PROJECT_DIR/generate_configurations.sh"
CONFIG_FILE_MULTI="$PROJECT_DIR/multi-host.conf"
CONFIG_FILE_SINGLE="$PROJECT_DIR/single-host.conf"

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
    
    eval "$test_command"
    local actual_exit_code=$?
    
    if [[ $actual_exit_code -eq $expected_exit_code ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name (exit code: expected $expected_exit_code, got $actual_exit_code)"
    fi
}

# Test 1: Multi-host HA configuration
test_multi_host_ha() {
    # Clean up any existing ozone-config
    rm -rf "$PROJECT_DIR/ozone-config"
    
    run_test "Multi-host config generates ozone-site.xml with OM HA service IDs" \
        "cd '$PROJECT_DIR' && CONFIG_FILE='$CONFIG_FILE_MULTI' bash -c './generate_configurations.sh >/dev/null 2>&1; grep -q \"<name>ozone.om.service.ids</name>\" ozone-config/ozone-site.xml'"
        
    run_test "Multi-host config has correct OM service ID value" \
        "cd '$PROJECT_DIR' && grep -A1 \"<name>ozone.om.service.ids</name>\" ozone-config/ozone-site.xml | grep -q \"<value>ozone1</value>\""
        
    run_test "Multi-host config generates SCM HA service IDs" \
        "cd '$PROJECT_DIR' && grep -q \"<name>ozone.scm.service.ids</name>\" ozone-config/ozone-site.xml"
        
    run_test "Multi-host config has correct SCM service ID value" \
        "cd '$PROJECT_DIR' && grep -A1 \"<name>ozone.scm.service.ids</name>\" ozone-config/ozone-site.xml | grep -q \"<value>cluster1</value>\""
        
    run_test "Multi-host config generates OM nodes configuration" \
        "cd '$PROJECT_DIR' && grep -q \"<name>ozone.om.nodes.ozone1</name>\" ozone-config/ozone-site.xml"
        
    run_test "Multi-host config has correct OM nodes list" \
        "cd '$PROJECT_DIR' && grep -A1 \"<name>ozone.om.nodes.ozone1</name>\" ozone-config/ozone-site.xml | grep -q \"<value>om1,om2,om3</value>\""
        
    run_test "Multi-host config generates SCM nodes configuration" \
        "cd '$PROJECT_DIR' && grep -q \"<name>ozone.scm.nodes.cluster1</name>\" ozone-config/ozone-site.xml"
        
    run_test "Multi-host config has correct SCM nodes list" \
        "cd '$PROJECT_DIR' && grep -A1 \"<name>ozone.scm.nodes.cluster1</name>\" ozone-config/ozone-site.xml | grep -q \"<value>scm1,scm2,scm3</value>\""
        
    run_test "Multi-host config generates individual OM addresses" \
        "cd '$PROJECT_DIR' && grep -q \"<name>ozone.om.address.ozone1.om1</name>\" ozone-config/ozone-site.xml && grep -q \"<name>ozone.om.address.ozone1.om2</name>\" ozone-config/ozone-site.xml && grep -q \"<name>ozone.om.address.ozone1.om3</name>\" ozone-config/ozone-site.xml"
        
    run_test "Multi-host config generates individual SCM addresses" \
        "cd '$PROJECT_DIR' && grep -q \"<name>ozone.scm.address.cluster1.scm1</name>\" ozone-config/ozone-site.xml && grep -q \"<name>ozone.scm.address.cluster1.scm2</name>\" ozone-config/ozone-site.xml && grep -q \"<name>ozone.scm.address.cluster1.scm3</name>\" ozone-config/ozone-site.xml"
        
    run_test "Multi-host config does not generate legacy ozone.om.address" \
        "cd '$PROJECT_DIR' && ! grep -q \"<name>ozone.om.address</name>\" ozone-config/ozone-site.xml"
        
    run_test "Multi-host config does not generate legacy ozone.scm.names" \
        "cd '$PROJECT_DIR' && ! grep -q \"<name>ozone.scm.names</name>\" ozone-config/ozone-site.xml"
}

# Test 2: Single-host non-HA configuration  
test_single_host_non_ha() {
    # Clean up any existing ozone-config
    rm -rf "$PROJECT_DIR/ozone-config"
    
    run_test "Single-host config generates ozone-site.xml without OM HA service IDs" \
        "cd '$PROJECT_DIR' && CONFIG_FILE='$CONFIG_FILE_SINGLE' bash -c './generate_configurations.sh >/dev/null 2>&1; ! grep -q \"<name>ozone.om.service.ids</name>\" ozone-config/ozone-site.xml'"
        
    run_test "Single-host config does not generate SCM HA service IDs" \
        "cd '$PROJECT_DIR' && ! grep -q \"<name>ozone.scm.service.ids</name>\" ozone-config/ozone-site.xml"
        
    run_test "Single-host config generates legacy ozone.om.address" \
        "cd '$PROJECT_DIR' && grep -q \"<name>ozone.om.address</name>\" ozone-config/ozone-site.xml"
        
    run_test "Single-host config has correct OM address value" \
        "cd '$PROJECT_DIR' && grep -A1 \"<name>ozone.om.address</name>\" ozone-config/ozone-site.xml | grep -q \"<value>ozone</value>\""
        
    run_test "Single-host config generates legacy ozone.scm.names" \
        "cd '$PROJECT_DIR' && grep -q \"<name>ozone.scm.names</name>\" ozone-config/ozone-site.xml"
        
    run_test "Single-host config has correct SCM names value" \
        "cd '$PROJECT_DIR' && grep -A1 \"<name>ozone.scm.names</name>\" ozone-config/ozone-site.xml | grep -q \"<value>ozone</value>\""
        
    run_test "Single-host config does not generate OM nodes" \
        "cd '$PROJECT_DIR' && ! grep -q \"<name>ozone.om.nodes\" ozone-config/ozone-site.xml"
        
    run_test "Single-host config does not generate SCM nodes" \
        "cd '$PROJECT_DIR' && ! grep -q \"<name>ozone.scm.nodes\" ozone-config/ozone-site.xml"
}

# Test 3: Configuration files have service IDs
test_config_files_service_ids() {
    run_test "Multi-host config file has OM service ID definition" \
        "grep -q 'OZONE_OM_SERVICE_ID=' '$CONFIG_FILE_MULTI'"
        
    run_test "Multi-host config file has SCM service ID definition" \
        "grep -q 'OZONE_SCM_SERVICE_ID=' '$CONFIG_FILE_MULTI'"
        
    run_test "Multi-host config file has correct OM service ID value" \
        "grep 'OZONE_OM_SERVICE_ID=' '$CONFIG_FILE_MULTI' | grep -q '\"ozone1\"'"
        
    run_test "Multi-host config file has correct SCM service ID value" \
        "grep 'OZONE_SCM_SERVICE_ID=' '$CONFIG_FILE_MULTI' | grep -q '\"cluster1\"'"
        
    run_test "Single-host config file has OM service ID definition" \
        "grep -q 'OZONE_OM_SERVICE_ID=' '$CONFIG_FILE_SINGLE'"
        
    run_test "Single-host config file has SCM service ID definition" \
        "grep -q 'OZONE_SCM_SERVICE_ID=' '$CONFIG_FILE_SINGLE'"
}

# Main function
main() {
    echo "Running HA configuration tests"
    echo "=============================="
    
    test_config_files_service_ids
    test_multi_host_ha
    test_single_host_non_ha
    
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