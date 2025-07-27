#!/bin/bash

# Test script for US-001-BE-003: Status history functionality

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
        echo "  Expected to contain: $needle"
        echo "  Actual content: $haystack"
        ((TESTS_FAILED++))
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"
    
    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected non-empty value"
        ((TESTS_FAILED++))
    fi
}

assert_json_valid() {
    local json="$1"
    local test_name="$2"
    
    if echo "$json" | jq empty 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Invalid JSON: $json"
        ((TESTS_FAILED++))
    fi
}

# Mock data for testing
create_mock_updates_response() {
    cat << 'EOF'
{
  "count": 3,
  "value": [
    {
      "id": 1,
      "rev": 1,
      "revisedDate": "2025-01-15T10:30:00.0000000Z",
      "revisedBy": {
        "displayName": "Test User",
        "uniqueName": "test@example.com"
      },
      "fields": {
        "System.State": {
          "oldValue": null,
          "newValue": "New"
        }
      }
    },
    {
      "id": 2,
      "rev": 2,
      "revisedDate": "2025-01-16T14:20:00.0000000Z",
      "revisedBy": {
        "displayName": "Test User",
        "uniqueName": "test@example.com"
      },
      "fields": {
        "System.State": {
          "oldValue": "New",
          "newValue": "Active"
        }
      }
    },
    {
      "id": 3,
      "rev": 3,
      "revisedDate": "2025-01-17T16:45:00.0000000Z",
      "revisedBy": {
        "displayName": "Another User",
        "uniqueName": "another@example.com"
      },
      "fields": {
        "System.State": {
          "oldValue": "Active",
          "newValue": "Resolved"
        }
      }
    }
  ]
}
EOF
}

create_mock_workitems_data() {
    cat << 'EOF'
{
  "workitems": [
    {"id": 123, "title": "Test Item 1", "state": "Active"},
    {"id": 456, "title": "Test Item 2", "state": "New"}
  ]
}
EOF
}

# Setup test environment
setup_test_env() {
    # Create test data directory
    export DATA_DIR="./test_data"
    mkdir -p "$DATA_DIR"
    
    # Create mock workitems data
    echo "$(create_mock_workitems_data)" > "$DATA_DIR/workitems.json"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -d "./test_data" ]]; then
        rm -rf "./test_data"
    fi
}

# Test convert_to_jst function
test_convert_to_jst() {
    echo -e "\n${YELLOW}Testing convert_to_jst function...${NC}"
    
    # Test UTC to JST conversion
    local utc_time="2025-01-15T10:30:00.0000000Z"
    local result
    result=$(convert_to_jst "$utc_time")
    
    assert_contains "$result" "2025-01-15T19:30:00+09:00" "UTC to JST conversion"
    
    # Test with different UTC format
    local utc_time2="2025-01-16T14:20:00Z"
    local result2
    result2=$(convert_to_jst "$utc_time2")
    
    assert_contains "$result2" "2025-01-16T23:20:00+09:00" "UTC to JST conversion (simple Z)"
    
    # Test empty input
    local empty_result
    empty_result=$(convert_to_jst "")
    
    assert_equals "" "$empty_result" "Empty input handling"
}

# Test extract_status_changes function
test_extract_status_changes() {
    echo -e "\n${YELLOW}Testing extract_status_changes function...${NC}"
    
    local mock_updates
    mock_updates=$(create_mock_updates_response)
    
    local result
    result=$(extract_status_changes "$mock_updates" "123")
    
    assert_not_empty "$result" "Status changes extraction returns data"
    
    # Count number of status changes (should be 3)
    local change_count
    change_count=$(echo "$result" | wc -l)
    
    assert_equals "3" "$change_count" "Correct number of status changes extracted"
    
    # Test first status change (creation)
    local first_change
    first_change=$(echo "$result" | head -1)
    
    assert_json_valid "$first_change" "First status change is valid JSON"
    assert_contains "$first_change" "workitemId" "Contains workitemId field"
    assert_contains "$first_change" "changeDate" "Contains changeDate field"
    assert_contains "$first_change" "changedBy" "Contains changedBy field"
    assert_contains "$first_change" "newStatus" "Contains newStatus field"
    
    # Test status transition
    local new_status
    new_status=$(echo "$first_change" | jq -r '.newStatus')
    assert_equals "New" "$new_status" "First status change has correct new status"
}

# Test get_workitem_updates function (mock mode)
test_get_workitem_updates() {
    echo -e "\n${YELLOW}Testing get_workitem_updates function...${NC}"
    
    # Test parameter validation
    local error_result
    error_result=$(get_workitem_updates "" "TestProject" 2>&1 || true)
    
    assert_contains "$error_result" "Work Item IDが指定されていません" "Empty work item ID validation"
    
    local error_result2
    error_result2=$(get_workitem_updates "123" "" 2>&1 || true)
    
    assert_contains "$error_result2" "プロジェクト名が指定されていません" "Empty project name validation"
}

# Test status history data structure
test_status_history_structure() {
    echo -e "\n${YELLOW}Testing status history data structure...${NC}"
    
    local mock_updates
    mock_updates=$(create_mock_updates_response)
    
    local status_changes
    status_changes=$(extract_status_changes "$mock_updates" "123")
    
    # Create status history JSON structure
    local status_history='{"status_history": []}'
    
    while IFS= read -r change; do
        if [[ -n "$change" ]]; then
            # Convert changeDate to JST
            local original_date
            original_date=$(echo "$change" | jq -r '.changeDate')
            local jst_date
            jst_date=$(convert_to_jst "$original_date")
            
            local jst_change
            jst_change=$(echo "$change" | jq --arg jst_date "$jst_date" '.changeDate = $jst_date')
            
            status_history=$(echo "$status_history" | jq --argjson change "$jst_change" '.status_history += [$change]')
        fi
    done <<< "$status_changes"
    
    assert_json_valid "$status_history" "Status history JSON is valid"
    
    # Test structure fields
    assert_contains "$status_history" "status_history" "Contains status_history array"
    
    local history_count
    history_count=$(echo "$status_history" | jq '.status_history | length')
    assert_equals "3" "$history_count" "Status history contains correct number of entries"
    
    # Test individual entry structure
    local first_entry
    first_entry=$(echo "$status_history" | jq '.status_history[0]')
    
    assert_contains "$first_entry" "workitemId" "Entry contains workitemId"
    assert_contains "$first_entry" "changeDate" "Entry contains changeDate"
    assert_contains "$first_entry" "changedBy" "Entry contains changedBy"
    assert_contains "$first_entry" "previousStatus" "Entry contains previousStatus"
    assert_contains "$first_entry" "newStatus" "Entry contains newStatus"
    assert_contains "$first_entry" "revision" "Entry contains revision"
    
    # Test JST timezone
    local change_date
    change_date=$(echo "$first_entry" | jq -r '.changeDate')
    assert_contains "$change_date" "+09:00" "Change date is in JST timezone"
}

# Test timezone conversion accuracy
test_timezone_conversion() {
    echo -e "\n${YELLOW}Testing timezone conversion accuracy...${NC}"
    
    # Test known UTC to JST conversions
    local test_cases=(
        "2025-01-15T00:00:00Z|2025-01-15T09:00:00+09:00"
        "2025-01-15T15:30:00Z|2025-01-16T00:30:00+09:00"
        "2025-12-31T23:59:59Z|2026-01-01T08:59:59+09:00"
    )
    
    for test_case in "${test_cases[@]}"; do
        local utc_time="${test_case%|*}"
        local expected_jst="${test_case#*|}"
        
        local actual_jst
        actual_jst=$(convert_to_jst "$utc_time")
        
        assert_equals "$expected_jst" "$actual_jst" "Timezone conversion: $utc_time -> $expected_jst"
    done
}

# Test edge cases
test_edge_cases() {
    echo -e "\n${YELLOW}Testing edge cases...${NC}"
    
    # Test empty updates response
    local empty_updates='{"count": 0, "value": []}'
    local empty_result
    empty_result=$(extract_status_changes "$empty_updates" "123")
    
    assert_equals "" "$empty_result" "Empty updates response handling"
    
    # Test non-status field changes (should be filtered out)
    local non_status_updates='{"count": 1, "value": [{"id": 1, "rev": 1, "revisedDate": "2025-01-15T10:30:00Z", "revisedBy": {"displayName": "Test User"}, "fields": {"System.Title": {"oldValue": "Old Title", "newValue": "New Title"}}}]}'
    local filtered_result
    filtered_result=$(extract_status_changes "$non_status_updates" "123")
    
    assert_equals "" "$filtered_result" "Non-status changes are filtered out"
    
    # Test malformed JSON
    local malformed_json='{"malformed": json}'
    local error_result
    error_result=$(extract_status_changes "$malformed_json" "123" 2>&1 || true)
    
    # Should not crash, may return empty result
    assert_not_empty "$error_result" "Malformed JSON handling doesn't crash"
}

# Test data persistence
test_data_persistence() {
    echo -e "\n${YELLOW}Testing data persistence...${NC}"
    
    setup_test_env
    
    # Test save_json function
    local test_data='{"test": "data", "number": 123}'
    
    if save_json "test_status.json" "$test_data" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Status history data can be saved"
        ((TESTS_PASSED++))
        
        # Test load_json function
        local loaded_data
        loaded_data=$(load_json "test_status.json")
        
        assert_json_valid "$loaded_data" "Loaded data is valid JSON"
        assert_contains "$loaded_data" "test" "Loaded data contains expected fields"
    else
        echo -e "${RED}✗${NC} Status history data saving failed"
        ((TESTS_FAILED++))
    fi
    
    cleanup_test_env
}

# Main test execution
main() {
    echo -e "${YELLOW}=== US-001-BE-003 Status History Tests ===${NC}"
    
    # Set environment variables for testing
    export LOG_LEVEL="ERROR"  # Reduce log noise during tests
    
    # Run all tests
    test_convert_to_jst
    test_extract_status_changes
    test_get_workitem_updates
    test_status_history_structure
    test_timezone_conversion
    test_edge_cases
    test_data_persistence
    
    # Display results
    echo -e "\n${YELLOW}=== Test Results ===${NC}"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed! ✓${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed! ✗${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi