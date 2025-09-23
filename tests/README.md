# Ozone Installer Tests

This directory contains tests for the Ozone Installer shell scripts.

## Test Structure

### Command Option Tests (`test_setup_rocky9_ssh.sh`)
Tests that shell script command options work as expected according to the README:
- Validates that `setup-rocky9-ssh.sh` recognizes all documented command options
- Tests usage message display for invalid options
- Verifies script structure and function definitions

### Function Unit Tests (`test_script_functions.sh`)
Basic unit tests for key functions in all shell scripts:
- Configuration loading and validation functions
- Logging and error handling functions
- SSH connection validation functions
- File generation functions (XML, properties)
- Host information gathering functions
- Service management functions
- Script structure and best practices

### Test Runner (`run_all_tests.sh`)
Comprehensive test runner that executes all test suites and provides summary results.

## Running Tests

### Individual Test Suites
```bash
# Test command options
./tests/test_setup_rocky9_ssh.sh

# Test script functions
./tests/test_script_functions.sh

# Run all tests
./tests/run_all_tests.sh
```

### Using Make Targets
```bash
# Test command options
make test-commands

# Test script functions
make test-functions

# Run comprehensive precommit tests
make test-precommit
```

## Test Framework

The tests use a simple bash-based testing framework with:
- Color-coded output (PASS/FAIL/TEST)
- Test counters and summary reporting
- Proper exit code handling
- Individual test isolation

## Coverage

The tests cover:

### Command Options (as per README)
- `setup-rocky9-ssh.sh`: start, stop, clean, connect, info

### Key Functions
- Configuration file parsing and validation
- SSH connection validation
- Logging and error handling
- File generation (core-site.xml, ozone-site.xml, log4j.properties)
- Host information gathering
- Service management operations
- Script structure validation

## Integration with CI/CD

These tests are integrated into the GitHub Actions workflow in `.github/workflows/precommit.yml` and run automatically on:
- Push to `main` or `develop` branches
- Pull requests targeting `main` or `develop` branches

The tests ensure that:
1. Shell script command options work as documented in the README
2. Key functions exist and have proper structure
3. Configuration handling is robust
4. Scripts follow best practices