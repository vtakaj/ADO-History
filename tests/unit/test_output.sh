#!/bin/bash
# API Function Unit Tests for ado-tracker.sh
set -euo pipefail

SCRIPT_PATH="./ado-tracker.sh"
TEST_COUNT=0
PASS_COUNT=0

# Load the script functions for testing
source "$SCRIPT_PATH"

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"
    
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ✗ FAIL (expected '$expected', got '$actual')"
    fi
    echo
}

assert_exit_code() {
    local expected_code="$1"
    local test_name="$2"
    shift 2
    local command=("$@")
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"
    
    set +e
    "${command[@]}" >/dev/null 2>&1
    local actual_code=$?
    set -e
    
    if [[ $expected_code -eq $actual_code ]]; then
        echo "  ✓ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ✗ FAIL (expected exit code $expected_code, got $actual_code)"
    fi
    echo
}

assert_contains() {
    local expected_substring="$1"
    local actual_output="$2"
    local test_name="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"
    
    if [[ "$actual_output" == *"$expected_substring"* ]]; then
        echo "  ✓ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ✗ FAIL (expected output to contain '$expected_substring')"
        echo "  Actual output: $actual_output"
    fi
    echo
}

echo "Running API Function Unit Tests"
echo "==============================="
echo

# Test mask_pat function
assert_equals "abcd****wxyz" "$(mask_pat "abcdefghijklmnopqrstuvwxyz")" "mask_pat with long PAT"
assert_equals "****" "$(mask_pat "short")" "mask_pat with short PAT"
assert_equals "****" "$(mask_pat "")" "mask_pat with empty PAT"

# Test call_ado_api parameter validation
export AZURE_DEVOPS_PAT=""
export AZURE_DEVOPS_ORG=""

# Mock functions to avoid network calls during testing
curl() {
    echo "200"
}

mktemp() {
    echo "/tmp/test_response"
}

# Test call_ado_api with missing parameters
set +e
call_ado_api "" 2>/dev/null
assert_equals "1" "$?" "call_ado_api with empty endpoint"

AZURE_DEVOPS_PAT=""
AZURE_DEVOPS_ORG="test-org"
call_ado_api "_apis/projects" 2>/dev/null
assert_equals "1" "$?" "call_ado_api with missing PAT"

AZURE_DEVOPS_PAT="test-pat"
AZURE_DEVOPS_ORG=""
call_ado_api "_apis/projects" 2>/dev/null
assert_equals "1" "$?" "call_ado_api with missing organization"
set -e

# Test validate_config function
export AZURE_DEVOPS_PAT="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
export AZURE_DEVOPS_ORG="valid-org-name"
export API_VERSION="7.2"
export RETRY_COUNT="3"

set +e
validate_config >/dev/null 2>&1
assert_equals "0" "$?" "validate_config with valid configuration"

export AZURE_DEVOPS_PAT=""
validate_config >/dev/null 2>&1
assert_equals "1" "$?" "validate_config with missing PAT"

export AZURE_DEVOPS_PAT="short"
validate_config >/dev/null 2>&1
assert_equals "1" "$?" "validate_config with short PAT"

export AZURE_DEVOPS_PAT="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
export AZURE_DEVOPS_ORG=""
validate_config >/dev/null 2>&1
assert_equals "1" "$?" "validate_config with missing organization"

export AZURE_DEVOPS_ORG="invalid@org"
validate_config >/dev/null 2>&1
assert_equals "1" "$?" "validate_config with invalid organization format"

export AZURE_DEVOPS_ORG="valid-org-name"
export API_VERSION="invalid"
validate_config >/dev/null 2>&1
assert_equals "1" "$?" "validate_config with invalid API version"

export API_VERSION="7.2"
export RETRY_COUNT="invalid"
validate_config >/dev/null 2>&1
assert_equals "1" "$?" "validate_config with invalid retry count"

export RETRY_COUNT="15"
validate_config >/dev/null 2>&1
assert_equals "1" "$?" "validate_config with retry count too high"
set -e

echo "==============================="
echo "Test Summary:"
echo "Total tests: $TEST_COUNT"
echo "Passed: $PASS_COUNT"
echo "Failed: $((TEST_COUNT - PASS_COUNT))"

if [[ $PASS_COUNT -eq $TEST_COUNT ]]; then
    echo "✓ All API function tests passed!"
    exit 0
else
    echo "✗ Some API function tests failed!"
    exit 1
fi