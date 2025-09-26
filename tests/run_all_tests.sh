#!/bin/bash

# Main test runner for all precommit tests
# This script runs all command option tests and unit tests

# set -e # Let individual test scripts handle their own exit codes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

echo -e "${BLUE}=== Ozone Installer Precommit Tests ===${NC}"
echo "Running all command option and unit tests..."
echo ""

# Function to run a test script
run_test_script() {
    local test_script="$1"
    local test_name="$2"

    echo -e "${YELLOW}Running $test_name...${NC}"
    if "$test_script"; then
        echo -e "${GREEN}✅ $test_name passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name failed${NC}"
        return 1
    fi
}

# Run command option tests
echo "1. Testing shell script command options"
echo "========================================"
if run_test_script "$SCRIPT_DIR/test_setup_rocky9_ssh.sh" "setup-rocky9-ssh.sh command options"; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
fi
((TOTAL_TESTS++))

echo ""

# Run Docker Compose setup tests
echo "2. Testing Docker Compose setup"
echo "================================"
if run_test_script "$SCRIPT_DIR/test_setup_ozone_compose.sh" "setup-ozone-compose.sh and docker-compose.yml"; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
fi
((TOTAL_TESTS++))

echo ""

# Run Docker SSH setup tests
echo "3. Testing Docker Compose SSH setup"
echo "===================================="
if run_test_script "$SCRIPT_DIR/test_setup_ozone_docker_ssh.sh" "setup-ozone-docker-ssh.sh and SSH configuration"; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
fi
((TOTAL_TESTS++))

echo ""

# Run unit tests for functions
echo "4. Testing shell script functions"
echo "=================================="
if run_test_script "$SCRIPT_DIR/test_script_functions.sh" "shell script function tests"; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
fi
((TOTAL_TESTS++))

echo ""

# Run service distribution tests
echo "5. Testing service distribution configuration"
echo "=============================================="
if run_test_script "$SCRIPT_DIR/test_service_distribution.sh" "service distribution configuration"; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
fi
((TOTAL_TESTS++))

echo ""

# Summary
echo "Overall Test Summary"
echo "===================="
echo "Test suites run: $TOTAL_TESTS"
echo "Test suites passed: $TOTAL_PASSED"
echo "Test suites failed: $TOTAL_FAILED"

if [ "$TOTAL_FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎉 All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}💥 Some test suites failed!${NC}"
    exit 1
fi