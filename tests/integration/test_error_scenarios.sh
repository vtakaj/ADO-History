#!/bin/bash

# Test script for US-001-BE-005: Error Handling and Logging Features
# This script tests the enhanced error handling, retry mechanisms, and checkpoint functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADO_TRACKER_SCRIPT="$REPO_ROOT/ado-tracker.sh"
TEST_WORKDIR="$(mktemp -d)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_failure() {
    echo -e "${RED}✗ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

cleanup() {
    rm -rf "$TEST_WORKDIR"
}
trap cleanup EXIT

# Test 1: Verify enhanced logging functions exist
test_logging_functions() {
    print_test_header "Testing Enhanced Logging Functions"
    
    # Source the script to test functions
    if source "$ADO_TRACKER_SCRIPT" 2>/dev/null; then
        print_success "Successfully sourced ado-tracker.sh"
    else
        print_failure "Failed to source ado-tracker.sh"
        return 1
    fi
    
    # Test log_message function
    if declare -f log_message >/dev/null; then
        print_success "log_message function exists"
    else
        print_failure "log_message function not found"
    fi
    
    # Test enhanced log functions
    if declare -f log_error >/dev/null; then
        print_success "log_error function exists"
    else
        print_failure "log_error function not found"
    fi
    
    # Test error handling function
    if declare -f handle_api_error >/dev/null; then
        print_success "handle_api_error function exists"
    else
        print_failure "handle_api_error function not found"
    fi
    
    # Test retry function
    if declare -f retry_with_backoff >/dev/null; then
        print_success "retry_with_backoff function exists"
    else
        print_failure "retry_with_backoff function not found"
    fi
}

# Test 2: Test checkpoint functions
test_checkpoint_functions() {
    print_test_header "Testing Checkpoint Functions"
    
    # Test checkpoint functions exist
    if declare -f save_checkpoint >/dev/null; then
        print_success "save_checkpoint function exists"
    else
        print_failure "save_checkpoint function not found"
    fi
    
    if declare -f load_checkpoint >/dev/null; then
        print_success "load_checkpoint function exists"
    else
        print_failure "load_checkpoint function not found"
    fi
    
    if declare -f clear_checkpoint >/dev/null; then
        print_success "clear_checkpoint function exists"
    else
        print_failure "clear_checkpoint function not found"
    fi
}

# Test 3: Test logging with timestamps
test_timestamp_logging() {
    print_test_header "Testing Timestamp Logging"
    
    # Create a temporary log file
    local temp_log=$(mktemp)
    
    # Test if log messages include timestamps
    log_info "Test message" 2>&1 | tee "$temp_log"
    
    if grep -q "\[20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\] \[INFO\]" "$temp_log"; then
        print_success "Timestamp format in log messages is correct"
    else
        print_failure "Timestamp format in log messages is incorrect"
    fi
    
    rm -f "$temp_log"
}

# Test 4: Test error handling function
test_error_handling() {
    print_test_header "Testing Error Handling Function"
    
    # Create a temporary log file
    local temp_log=$(mktemp)
    
    # Test different HTTP error codes
    local test_codes=("401" "403" "404" "429" "500" "000")
    
    for code in "${test_codes[@]}"; do
        handle_api_error "$code" "" "test-endpoint" 2>&1 | tee "$temp_log" || true
        
        case "$code" in
            401)
                if grep -q "認証エラー: PATを確認してください" "$temp_log"; then
                    print_success "HTTP $code error handling works correctly"
                else
                    print_failure "HTTP $code error handling failed"
                fi
                ;;
            403)
                if grep -q "権限エラー: プロジェクトへのアクセス権限がありません" "$temp_log"; then
                    print_success "HTTP $code error handling works correctly"
                else
                    print_failure "HTTP $code error handling failed"
                fi
                ;;
            404)
                if grep -q "リソースが見つかりません" "$temp_log"; then
                    print_success "HTTP $code error handling works correctly"
                else
                    print_failure "HTTP $code error handling failed"
                fi
                ;;
            429)
                if grep -q "レート制限" "$temp_log"; then
                    print_success "HTTP $code error handling works correctly"
                else
                    print_failure "HTTP $code error handling failed"
                fi
                ;;
            500)
                if grep -q "サーバーエラー" "$temp_log"; then
                    print_success "HTTP $code error handling works correctly"
                else
                    print_failure "HTTP $code error handling failed"
                fi
                ;;
            000)
                if grep -q "ネットワークエラーまたはタイムアウト" "$temp_log"; then
                    print_success "HTTP $code error handling works correctly"
                else
                    print_failure "HTTP $code error handling failed"
                fi
                ;;
        esac
    done
    
    rm -f "$temp_log"
}

# Test 5: Test checkpoint creation and loading
test_checkpoint_operations() {
    print_test_header "Testing Checkpoint Operations"
    
    # Clean up any existing checkpoint
    rm -f "./data/checkpoint.json"
    
    # Create test checkpoint data
    local test_data='{"project": "TestProject", "stage": "test"}'
    
    # Test saving checkpoint
    if save_checkpoint "$test_data" "test_operation" 2>/dev/null; then
        print_success "Checkpoint save operation works"
    else
        print_failure "Checkpoint save operation failed"
    fi
    
    # Test loading checkpoint
    local loaded_data
    if loaded_data=$(load_checkpoint 2>/dev/null); then
        print_success "Checkpoint load operation works"
        
        # Verify data integrity
        local operation
        local checkpoint_json
        checkpoint_json=$(echo "$loaded_data" | sed -n '/^{/,$p')
        operation=$(echo "$checkpoint_json" | jq -r '.operation' 2>/dev/null || true)
        if [[ "$operation" == "test_operation" ]]; then
            print_success "Checkpoint data integrity verified"
        else
            print_failure "Checkpoint data integrity check failed"
        fi
    else
        print_failure "Checkpoint load operation failed"
    fi
    
    # Test clearing checkpoint
    if clear_checkpoint 2>/dev/null; then
        print_success "Checkpoint clear operation works"
    else
        print_failure "Checkpoint clear operation failed"
    fi
    
    # Verify checkpoint is cleared
    if [[ ! -f "./data/checkpoint.json" ]]; then
        print_success "Checkpoint file successfully removed"
    else
        print_failure "Checkpoint file was not removed"
    fi
}

# Test 6: Test script syntax and basic functionality
test_script_syntax() {
    print_test_header "Testing Script Syntax and Basic Functions"
    
    # Test script syntax
    if bash -n "$ADO_TRACKER_SCRIPT"; then
        print_success "Script syntax is valid"
    else
        print_failure "Script syntax errors found"
    fi
    
    # Test help command
    if timeout 10s bash "$ADO_TRACKER_SCRIPT" help >/dev/null 2>&1; then
        print_success "Help command works"
    else
        print_failure "Help command failed"
    fi
    
    # Test config show command
    if timeout 10s bash "$ADO_TRACKER_SCRIPT" config show >/dev/null 2>&1; then
        print_success "Config show command works"
    else
        print_failure "Config show command failed"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}Starting US-001-BE-005 Error Handling and Logging Tests${NC}"
    echo "=========================================================="
    cd "$TEST_WORKDIR"
    
    # Run tests
    test_script_syntax
    test_logging_functions  
    test_checkpoint_functions
    test_timestamp_logging
    test_error_handling
    test_checkpoint_operations
    
    # Print summary
    echo
    echo "=========================================================="
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All tests passed! US-001-BE-005 implementation is working correctly.${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some tests failed. Please review the implementation.${NC}"
        exit 1
    fi
}

# Run tests
main "$@"
