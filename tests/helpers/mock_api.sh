#!/bin/bash

# Test script for US-001-BE-002: Work Items fetching functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load script in a way that doesn't trigger the main execution
set +euo pipefail
source "$SCRIPT_DIR/ado-tracker.sh"
set -euo pipefail

# Test colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((TESTS_FAILED++))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  String '$needle' not found in: $haystack"
        ((TESTS_FAILED++))
    fi
}

assert_file_exists() {
    local filepath="$1"
    local test_name="$2"
    
    if [[ -f "$filepath" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  File does not exist: $filepath"
        ((TESTS_FAILED++))
    fi
}

assert_dir_exists() {
    local dirpath="$1"
    local test_name="$2"
    
    if [[ -d "$dirpath" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Directory does not exist: $dirpath"
        ((TESTS_FAILED++))
    fi
}

# Test data management functions
test_data_management() {
    echo -e "${YELLOW}Testing data management functions...${NC}"
    
    # Clean up any existing test data
    rm -rf "./test_data" 2>/dev/null || true
    
    # Override DATA_DIR for testing
    DATA_DIR="./test_data"
    BACKUP_DIR="./test_data/backup"
    
    # Test 1: Directory initialization
    init_data_directories
    assert_dir_exists "./test_data" "Data directory creation"
    assert_dir_exists "./test_data/backup" "Backup directory creation"
    
    # Test 2: JSON save functionality
    local test_json='{"test": "data", "count": 123}'
    save_json "test.json" "$test_json"
    assert_file_exists "./test_data/test.json" "JSON file save"
    
    # Test 3: JSON load functionality
    local loaded_json
    loaded_json=$(load_json "test.json")
    assert_contains "$loaded_json" "test" "JSON file load contains test key"
    assert_contains "$loaded_json" "123" "JSON file load contains count value"
    
    # Test 4: Backup creation
    save_json "test.json" '{"updated": "data"}'
    local backup_count
    backup_count=$(find "./test_data/backup" -name "test.json.*" | wc -l)
    if [[ $backup_count -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} Backup file creation"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Backup file creation"
        ((TESTS_FAILED++))
    fi
    
    # Test 5: Invalid JSON handling
    if save_json "invalid.json" "invalid json content" 2>/dev/null; then
        echo -e "${RED}✗${NC} Invalid JSON should fail"
        ((TESTS_FAILED++))
    else
        echo -e "${GREEN}✓${NC} Invalid JSON correctly rejected"
        ((TESTS_PASSED++))
    fi
    
    # Cleanup
    rm -rf "./test_data"
}

# Test workitem info extraction
test_workitem_extraction() {
    echo -e "${YELLOW}Testing work item extraction...${NC}"
    
    local sample_workitems='{
        "workitems": [
            {
                "id": 123,
                "title": "Sample Task",
                "assignedTo": "John Doe",
                "state": "Active",
                "lastModified": "2025-01-15T10:30:00Z"
            },
            {
                "id": 456,
                "title": "Another Task",
                "assignedTo": "Jane Smith",
                "state": "Closed",
                "lastModified": "2025-01-14T15:20:00Z"
            }
        ]
    }'
    
    local extracted_info
    extracted_info=$(extract_workitem_info "$sample_workitems")
    
    assert_contains "$extracted_info" "ID: 123" "Extract work item ID"
    assert_contains "$extracted_info" "Sample Task" "Extract work item title"
    assert_contains "$extracted_info" "John Doe" "Extract assignee"
    assert_contains "$extracted_info" "Active" "Extract state"
}

# Test validation functions
test_validation() {
    echo -e "${YELLOW}Testing validation functions...${NC}"
    
    # Test project name validation
    if validate_project_name "ValidProject" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Valid project name accepted"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Valid project name accepted"
        ((TESTS_FAILED++))
    fi
    
    if validate_project_name "Invalid Project!" 2>/dev/null; then
        echo -e "${RED}✗${NC} Invalid project name should be rejected"
        ((TESTS_FAILED++))
    else
        echo -e "${GREEN}✓${NC} Invalid project name correctly rejected"
        ((TESTS_PASSED++))
    fi
    
    # Test days validation
    if validate_days "30" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Valid days accepted"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Valid days accepted"
        ((TESTS_FAILED++))
    fi
    
    if validate_days "400" 2>/dev/null; then
        echo -e "${RED}✗${NC} Invalid days should be rejected"
        ((TESTS_FAILED++))
    else
        echo -e "${GREEN}✓${NC} Invalid days correctly rejected"
        ((TESTS_PASSED++))
    fi
}

# Mock test for fetch functionality (without actual API calls)
test_fetch_mock() {
    echo -e "${YELLOW}Testing fetch functionality (mock)...${NC}"
    
    # Test that the function exists and is callable
    if declare -f fetch_workitems > /dev/null; then
        echo -e "${GREEN}✓${NC} fetch_workitems function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} fetch_workitems function exists"
        ((TESTS_FAILED++))
    fi
    
    # Test that cmd_fetch function exists
    if declare -f cmd_fetch > /dev/null; then
        echo -e "${GREEN}✓${NC} cmd_fetch function exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} cmd_fetch function exists"
        ((TESTS_FAILED++))
    fi
}

# Run all tests
main() {
    echo "Starting US-001-BE-002 Work Items Fetch Tests"
    echo "=============================================="
    
    test_data_management
    echo
    
    test_workitem_extraction
    echo
    
    test_validation
    echo
    
    test_fetch_mock
    echo
    
    # Test summary
    echo "=============================================="
    echo "Test Results:"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "  Total: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi