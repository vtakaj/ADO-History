#!/bin/bash

# Test script for US-001-BE-004: Work Item details fetching functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/ado-tracker.sh"

# Load script in a way that doesn't trigger the main execution
set +euo pipefail
source "$SCRIPT_PATH"
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
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to find: $needle"
        echo "  In: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_json_valid() {
    local json_data="$1"
    local test_name="$2"
    
    if echo "$json_data" | jq empty 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Invalid JSON: $json_data"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"
    
    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Value should not be empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test setup
setup_test_env() {
    # Create temporary data directory for tests
    export DATA_DIR="$(mktemp -d)"
    export BACKUP_DIR="$DATA_DIR/backup"
    mkdir -p "$BACKUP_DIR"
    
    # Set test environment variables
    export AZURE_DEVOPS_PAT="test-pat-token-12345678901234567890123456789012345678901234567890"
    export AZURE_DEVOPS_ORG="test-org"
    export API_VERSION="7.2"
    export LOG_LEVEL="ERROR"  # Suppress logs during tests
    export BATCH_SIZE="5"
}

# Test cleanup
cleanup_test_env() {
    if [[ -n "${DATA_DIR:-}" ]] && [[ -d "$DATA_DIR" ]]; then
        rm -rf "$DATA_DIR"
    fi
}

# Mock API responses
create_mock_workitem_details_response() {
    cat << 'EOF'
{
    "id": 123,
    "fields": {
        "System.Title": "Test Work Item",
        "System.WorkItemType": "User Story",
        "Microsoft.VSTS.Common.Priority": 2,
        "System.CreatedDate": "2025-01-10T10:00:00Z",
        "System.ChangedDate": "2025-01-15T19:30:00Z",
        "Microsoft.VSTS.Scheduling.OriginalEstimate": 8.0,
        "System.AssignedTo": {
            "displayName": "Test User"
        },
        "System.State": "Active",
        "System.Description": "This is a test work item description"
    }
}
EOF
}

create_mock_batch_details_response() {
    cat << 'EOF'
{
    "count": 3,
    "value": [
        {
            "id": 123,
            "fields": {
                "System.Title": "Test Work Item 1",
                "System.WorkItemType": "User Story",
                "Microsoft.VSTS.Common.Priority": 2,
                "System.CreatedDate": "2025-01-10T10:00:00Z",
                "System.ChangedDate": "2025-01-15T19:30:00Z",
                "Microsoft.VSTS.Scheduling.OriginalEstimate": 8.0,
                "System.AssignedTo": {
                    "displayName": "Test User 1"
                },
                "System.State": "Active",
                "System.Description": "Test description 1"
            }
        },
        {
            "id": 124,
            "fields": {
                "System.Title": "Test Work Item 2",
                "System.WorkItemType": "Bug",
                "Microsoft.VSTS.Common.Priority": 1,
                "System.CreatedDate": "2025-01-11T14:00:00Z",
                "System.ChangedDate": "2025-01-16T10:15:00Z",
                "System.AssignedTo": {
                    "displayName": "Test User 2"
                },
                "System.State": "In Progress",
                "System.Description": "Test description 2"
            }
        },
        {
            "id": 125,
            "fields": {
                "System.Title": "Test Work Item 3",
                "System.WorkItemType": "Task",
                "System.CreatedDate": "2025-01-12T09:00:00Z",
                "System.ChangedDate": "2025-01-17T15:45:00Z",
                "System.AssignedTo": {
                    "displayName": "Test User 3"
                },
                "System.State": "Done"
            }
        }
    ]
}
EOF
}

create_mock_workitems_json() {
    cat << 'EOF'
{
    "workitems": [
        {
            "id": 123,
            "title": "Test Work Item 1",
            "assignedTo": "Test User 1",
            "state": "Active",
            "lastModified": "2025-01-15T19:30:00Z"
        },
        {
            "id": 124,
            "title": "Test Work Item 2",
            "assignedTo": "Test User 2",
            "state": "In Progress",
            "lastModified": "2025-01-16T10:15:00Z"
        },
        {
            "id": 125,
            "title": "Test Work Item 3",
            "assignedTo": "Test User 3",
            "state": "Done",
            "lastModified": "2025-01-17T15:45:00Z"
        }
    ]
}
EOF
}

# Test cases

test_merge_workitem_data() {
    echo -e "${YELLOW}Testing merge_workitem_data function...${NC}"
    
    local basic_data="{}"
    local details_response
    details_response=$(create_mock_workitem_details_response)
    local workitem_id="123"
    
    local result
    result=$(merge_workitem_data "$basic_data" "$details_response" "$workitem_id")
    
    assert_json_valid "$result" "merge_workitem_data returns valid JSON"
    assert_contains "$result" '"id": 123' "Result contains work item ID"
    assert_contains "$result" '"title": "Test Work Item"' "Result contains title"
    assert_contains "$result" '"type": "User Story"' "Result contains work item type"
    assert_contains "$result" '"priority": 2' "Result contains priority"
    assert_contains "$result" '"originalEstimate": 8' "Result contains original estimate"
    assert_contains "$result" '"assignedTo": "Test User"' "Result contains assigned user"
    assert_contains "$result" '"currentStatus": "Active"' "Result contains current status"
    assert_contains "$result" '+09:00' "Result contains JST timezone conversion"
}

test_get_workitem_details_parameters() {
    echo -e "${YELLOW}Testing get_workitem_details parameter validation...${NC}"
    
    # Test missing workitem_id
    local result
    result=$(get_workitem_details "" "test-project" 2>&1 || true)
    assert_contains "$result" "Work Item IDが指定されていません" "Validates missing work item ID"
    
    # Test missing project
    result=$(get_workitem_details "123" "" 2>&1 || true)
    assert_contains "$result" "プロジェクト名が指定されていません" "Validates missing project name"
}

test_fetch_all_details_with_mock_data() {
    echo -e "${YELLOW}Testing fetch_all_details with mock data...${NC}"
    
    # Setup mock workitems.json
    local workitems_data
    workitems_data=$(create_mock_workitems_json)
    save_json "workitems.json" "$workitems_data"
    
    # Mock the call_ado_api function to return our test data
    call_ado_api() {
        create_mock_batch_details_response
        return 0
    }
    
    # Run fetch_all_details
    local result
    result=$(fetch_all_details "test-project" 2>&1 || true)
    
    # Check that workitem_details.json was created
    if [[ -f "$DATA_DIR/workitem_details.json" ]]; then
        echo -e "${GREEN}✓${NC} workitem_details.json file created"
        ((TESTS_PASSED++))
        
        local details_data
        details_data=$(cat "$DATA_DIR/workitem_details.json")
        
        assert_json_valid "$details_data" "workitem_details.json is valid JSON"
        assert_contains "$details_data" '"workitem_details"' "Contains workitem_details array"
        assert_contains "$details_data" '"Test Work Item 1"' "Contains first work item title"
        assert_contains "$details_data" '"User Story"' "Contains work item type"
        assert_contains "$details_data" '"Bug"' "Contains different work item types"
        assert_contains "$details_data" '+09:00' "Contains JST timezone conversion"
    else
        echo -e "${RED}✗${NC} workitem_details.json file not created"
        ((TESTS_FAILED++))
    fi
}

test_workitem_details_json_structure() {
    echo -e "${YELLOW}Testing work item details JSON structure...${NC}"
    
    local details_response
    details_response=$(create_mock_workitem_details_response)
    
    local enhanced_data
    enhanced_data=$(echo "$details_response" | jq -c '
        {
            id: .id,
            title: (.fields["System.Title"] // ""),
            type: (.fields["System.WorkItemType"] // ""),
            priority: (.fields["Microsoft.VSTS.Common.Priority"] // null),
            createdDate: (.fields["System.CreatedDate"] // ""),
            lastModifiedDate: (.fields["System.ChangedDate"] // ""),
            originalEstimate: (.fields["Microsoft.VSTS.Scheduling.OriginalEstimate"] // null),
            assignedTo: ((.fields["System.AssignedTo"] // {}).displayName // ""),
            currentStatus: (.fields["System.State"] // ""),
            description: (.fields["System.Description"] // "")
        }
    ')
    
    assert_json_valid "$enhanced_data" "Enhanced data structure is valid JSON"
    
    # Check all required fields are present
    local id_value
    id_value=$(echo "$enhanced_data" | jq -r '.id')
    assert_equals "123" "$id_value" "ID field extracted correctly"
    
    local title_value
    title_value=$(echo "$enhanced_data" | jq -r '.title')
    assert_equals "Test Work Item" "$title_value" "Title field extracted correctly"
    
    local type_value
    type_value=$(echo "$enhanced_data" | jq -r '.type')
    assert_equals "User Story" "$type_value" "Type field extracted correctly"
    
    local priority_value
    priority_value=$(echo "$enhanced_data" | jq -r '.priority')
    assert_equals "2" "$priority_value" "Priority field extracted correctly"
    
    local estimate_value
    estimate_value=$(echo "$enhanced_data" | jq -r '.originalEstimate')
    assert_equals "8" "$estimate_value" "Original estimate field extracted correctly"
}

test_null_value_handling() {
    echo -e "${YELLOW}Testing NULL value handling...${NC}"
    
    # Create mock response with missing optional fields
    local minimal_response='
    {
        "id": 126,
        "fields": {
            "System.Title": "Minimal Work Item",
            "System.WorkItemType": "Task",
            "System.CreatedDate": "2025-01-12T09:00:00Z",
            "System.ChangedDate": "2025-01-17T15:45:00Z",
            "System.State": "New"
        }
    }'
    
    local enhanced_data
    enhanced_data=$(echo "$minimal_response" | jq -c '
        {
            id: .id,
            title: (.fields["System.Title"] // ""),
            type: (.fields["System.WorkItemType"] // ""),
            priority: (.fields["Microsoft.VSTS.Common.Priority"] // null),
            createdDate: (.fields["System.CreatedDate"] // ""),
            lastModifiedDate: (.fields["System.ChangedDate"] // ""),
            originalEstimate: (.fields["Microsoft.VSTS.Scheduling.OriginalEstimate"] // null),
            assignedTo: ((.fields["System.AssignedTo"] // {}).displayName // ""),
            currentStatus: (.fields["System.State"] // ""),
            description: (.fields["System.Description"] // "")
        }
    ')
    
    assert_json_valid "$enhanced_data" "Minimal data structure is valid JSON"
    
    local priority_value
    priority_value=$(echo "$enhanced_data" | jq -r '.priority')
    assert_equals "null" "$priority_value" "NULL priority handled correctly"
    
    local estimate_value
    estimate_value=$(echo "$enhanced_data" | jq -r '.originalEstimate')
    assert_equals "null" "$estimate_value" "NULL original estimate handled correctly"
    
    local assignee_value
    assignee_value=$(echo "$enhanced_data" | jq -r '.assignedTo')
    assert_equals "" "$assignee_value" "Missing assignee handled correctly"
    
    local description_value
    description_value=$(echo "$enhanced_data" | jq -r '.description')
    assert_equals "" "$description_value" "Missing description handled correctly"
}

test_jst_conversion() {
    echo -e "${YELLOW}Testing JST conversion...${NC}"
    
    local utc_time="2025-01-15T19:30:00Z"
    local jst_time
    jst_time=$(convert_to_jst "$utc_time")
    
    assert_not_empty "$jst_time" "JST conversion produces output"
    assert_contains "$jst_time" "+09:00" "JST conversion includes timezone offset"
    
    # Test with different UTC format
    local utc_time2="2025-01-15T19:30:00.123Z"
    local jst_time2
    jst_time2=$(convert_to_jst "$utc_time2")
    
    assert_not_empty "$jst_time2" "JST conversion with milliseconds produces output"
    assert_contains "$jst_time2" "+09:00" "JST conversion with milliseconds includes timezone offset"
}

# Main test execution
main() {
    echo "=== US-001-BE-004 Work Item Details Tests ==="
    echo
    
    setup_test_env
    
    # Run all tests
    test_merge_workitem_data
    echo
    test_get_workitem_details_parameters
    echo
    test_fetch_all_details_with_mock_data
    echo
    test_workitem_details_json_structure
    echo
    test_null_value_handling
    echo
    test_jst_conversion
    echo
    
    cleanup_test_env
    
    # Test results summary
    echo "=== Test Results ==="
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo
    
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
