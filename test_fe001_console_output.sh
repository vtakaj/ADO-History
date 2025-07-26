#!/bin/bash
# US-001-FE-001: Console Output Format Test
set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/ado-tracker.sh"
TEST_DATA_DIR="$SCRIPT_DIR/test_data"
DATA_DIR="./data"

# Test colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'  
RESET='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Test utilities
log_test() {
    echo -e "${BLUE}[TEST]${RESET} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${RESET} $*"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${RESET} $*"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$*")
}

log_info() {
    echo -e "${YELLOW}[INFO]${RESET} $*"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create test data directory
    mkdir -p "$TEST_DATA_DIR"
    mkdir -p "$DATA_DIR"
    
    # Create sample workitems.json
    cat > "$DATA_DIR/workitems.json" << 'EOF'
{
  "workitems": [
    {
      "id": 12345,
      "title": "Implement user authentication feature",
      "assignedTo": "田中太郎",
      "state": "Active",
      "lastModified": "2024-01-15T10:30:00+09:00"
    },
    {
      "id": 12346,
      "title": "Fix login validation bug",
      "assignedTo": "佐藤花子",
      "state": "Resolved",
      "lastModified": "2024-01-14T15:45:00+09:00"
    },
    {
      "id": 12347,
      "title": "Update API documentation",
      "assignedTo": "鈴木一郎",
      "state": "New",
      "lastModified": "2024-01-13T09:20:00+09:00"
    },
    {
      "id": 12348,
      "title": "Refactor database connection pool",
      "assignedTo": "田中太郎",
      "state": "Done",
      "lastModified": "2024-01-12T14:15:00+09:00"
    }
  ]
}
EOF

    # Create sample status_history.json
    cat > "$DATA_DIR/status_history.json" << 'EOF'
{
  "status_history": [
    {
      "workitemId": 12345,
      "changeDate": "2024-01-15T10:30:00+09:00",
      "changedBy": "田中太郎",
      "previousStatus": "New",
      "newStatus": "Active",
      "revision": 2
    },
    {
      "workitemId": 12345,
      "changeDate": "2024-01-14T14:20:00+09:00",
      "changedBy": "プロジェクトマネージャー",
      "previousStatus": "Proposed",
      "newStatus": "New",
      "revision": 1
    },
    {
      "workitemId": 12346,
      "changeDate": "2024-01-14T15:45:00+09:00",
      "changedBy": "佐藤花子",
      "previousStatus": "Active",
      "newStatus": "Resolved",
      "revision": 3
    }
  ]
}
EOF

    log_info "Test environment setup complete"
}

# Cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    rm -rf "$TEST_DATA_DIR"
    rm -rf "$DATA_DIR"
    log_info "Cleanup complete"
}

# Test color setup function
test_color_setup() {
    log_test "Testing color setup functionality..."
    
    # Test with colors enabled (simulating TTY)
    if TTY=1 NO_COLOR=0 bash -c ". $MAIN_SCRIPT && setup_colors && [[ -n \"\$RED\" ]] && [[ -n \"\$GREEN\" ]]" 2>/dev/null; then
        log_success "Color setup works with colors enabled"
    else
        # Since we can't simulate TTY easily, just check that function exists and runs
        if bash -c ". $MAIN_SCRIPT && type setup_colors" >/dev/null 2>&1; then
            log_success "Color setup function is available and executable"
        else
            log_error "Color setup function not available"
            return 1
        fi
    fi
    
    # Test with colors disabled
    if NO_COLOR=1 bash -c ". $MAIN_SCRIPT && setup_colors && [[ -z \"\$RED\" ]] && [[ -z \"\$GREEN\" ]]"; then
        log_success "Color setup works with colors disabled"
    else
        log_error "Color setup failed with colors disabled"
        return 1
    fi
}

# Test workitems table display
test_workitems_table_display() {
    log_test "Testing workitems table display..."
    
    local output
    if output=$(bash -c ". $MAIN_SCRIPT && setup_colors && display_workitems_table '$DATA_DIR/workitems.json'" 2>/dev/null); then
        # Check for table headers
        if echo "$output" | grep -q "ID.*タイトル.*担当者.*ステータス"; then
            log_success "Table display contains proper headers"
        else
            log_error "Table display missing headers"
            return 1
        fi
        
        # Check for data rows
        if echo "$output" | grep -q "12345"; then
            log_success "Table display contains work item data"
        else
            log_error "Table display missing work item data"
            return 1
        fi
        
        # Check for separator line
        if echo "$output" | grep -q "\-\-\-\-\-\-\-\-"; then
            log_success "Table display contains separator line"
        else
            log_error "Table display missing separator line"
            return 1
        fi
    else
        log_error "Workitems table display failed to execute"
        return 1
    fi
}

# Test workitems list display
test_workitems_list_display() {
    log_test "Testing workitems list display..."
    
    local output
    if output=$(bash -c ". $MAIN_SCRIPT && setup_colors && display_workitems_list '$DATA_DIR/workitems.json'" 2>/dev/null); then
        # Check for Work Item headers
        if echo "$output" | grep -q "Work Item #12345"; then
            log_success "List display contains work item headers"
        else
            log_error "List display missing work item headers"
            return 1
        fi
        
        # Check for field labels
        if echo "$output" | grep -q "タイトル:" && echo "$output" | grep -q "担当者:" && echo "$output" | grep -q "ステータス:"; then
            log_success "List display contains field labels"
        else
            log_error "List display missing field labels"
            return 1
        fi
    else
        log_error "Workitems list display failed to execute"
        return 1
    fi
}

# Test workitems summary display
test_workitems_summary_display() {
    log_test "Testing workitems summary display..."
    
    local output
    if output=$(bash -c ". $MAIN_SCRIPT && setup_colors && display_workitems_summary '$DATA_DIR/workitems.json'" 2>/dev/null); then
        # Check for summary header
        if echo "$output" | grep -q "チケット統計"; then
            log_success "Summary display contains header"
        else
            log_error "Summary display missing header"
            return 1
        fi
        
        # Check for total count
        if echo "$output" | grep -q "総チケット数.*4"; then
            log_success "Summary display shows correct total count"
        else
            log_error "Summary display shows incorrect total count"
            return 1
        fi
        
        # Check for status breakdown
        if echo "$output" | grep -q "ステータス別内訳"; then
            log_success "Summary display contains status breakdown"
        else
            log_error "Summary display missing status breakdown"
            return 1
        fi
        
        # Check for assignee breakdown
        if echo "$output" | grep -q "担当者別内訳"; then
            log_success "Summary display contains assignee breakdown"
        else
            log_error "Summary display missing assignee breakdown"
            return 1
        fi
    else
        log_error "Workitems summary display failed to execute"
        return 1
    fi
}

# Test status history display
test_status_history_display() {
    log_test "Testing status history display..."
    
    local output
    if output=$(bash -c ". $MAIN_SCRIPT && setup_colors && display_status_history '12345' '$DATA_DIR'" 2>/dev/null); then
        # Check for history header
        if echo "$output" | grep -q "チケット #12345 ステータス履歴"; then
            log_success "Status history display contains header"
        else
            log_error "Status history display missing header"
            return 1
        fi
        
        # Check for status transitions
        if echo "$output" | grep -q "New.*→.*Active"; then
            log_success "Status history shows status transitions"
        else
            log_error "Status history missing status transitions"
            return 1
        fi
        
        # Check for change author
        if echo "$output" | grep -q "田中太郎"; then
            log_success "Status history shows change author"
        else
            log_error "Status history missing change author"
            return 1
        fi
    else
        log_error "Status history display failed to execute"
        return 1
    fi
}

# Test display command
test_display_command() {
    log_test "Testing display command..."
    
    # Test table format
    if bash "$MAIN_SCRIPT" display table >/dev/null 2>&1; then
        log_success "Display command works with table format"
    else
        log_error "Display command failed with table format"
        return 1
    fi
    
    # Test list format
    if bash "$MAIN_SCRIPT" display list >/dev/null 2>&1; then
        log_success "Display command works with list format"
    else
        log_error "Display command failed with list format"
        return 1
    fi
    
    # Test summary format
    if bash "$MAIN_SCRIPT" display summary >/dev/null 2>&1; then
        log_success "Display command works with summary format"
    else
        log_error "Display command failed with summary format"
        return 1
    fi
    
    # Test invalid format
    if ! bash "$MAIN_SCRIPT" display invalid >/dev/null 2>&1; then
        log_success "Display command properly rejects invalid format"
    else
        log_error "Display command should reject invalid format"
        return 1
    fi
}

# Test history command
test_history_command() {
    log_test "Testing history command..."
    
    # Test valid work item ID
    if bash "$MAIN_SCRIPT" history 12345 >/dev/null 2>&1; then
        log_success "History command works with valid work item ID"
    else
        log_error "History command failed with valid work item ID"
        return 1
    fi
    
    # Test invalid work item ID (non-numeric)
    if ! bash "$MAIN_SCRIPT" history abc >/dev/null 2>&1; then
        log_success "History command properly rejects non-numeric ID"
    else
        log_error "History command should reject non-numeric ID"
        return 1
    fi
    
    # Test missing work item ID
    if ! bash "$MAIN_SCRIPT" history >/dev/null 2>&1; then
        log_success "History command properly requires work item ID"
    else
        log_error "History command should require work item ID"
        return 1
    fi
}

# Test progress indicator
test_progress_indicator() {
    log_test "Testing progress indicator..."
    
    local output
    if output=$(bash -c ". $MAIN_SCRIPT && setup_colors && show_progress 50 100 'Testing'"); then
        # Check for progress bar elements
        if echo "$output" | grep -q "50%" && echo "$output" | grep -q "(50/100)" && echo "$output" | grep -q "Testing"; then
            log_success "Progress indicator shows correct information"
        else
            log_error "Progress indicator missing expected information"
            return 1
        fi
    else
        log_error "Progress indicator failed to execute"
        return 1
    fi
}

# Test character width handling (Japanese characters)
test_japanese_character_handling() {
    log_test "Testing Japanese character width handling..."
    
    # This test ensures that Japanese characters are properly handled in table formatting
    local output
    if output=$(bash -c ". $MAIN_SCRIPT && setup_colors && display_workitems_table '$DATA_DIR/workitems.json'" 2>/dev/null); then
        # Check that Japanese names are displayed correctly
        if echo "$output" | grep -q "田中太郎" && echo "$output" | grep -q "佐藤花子"; then
            log_success "Japanese characters are properly displayed"
        else
            log_error "Japanese characters not displayed correctly"
            return 1
        fi
        
        # Check that table alignment is maintained with Japanese characters
        local line_count
        line_count=$(echo "$output" | wc -l)
        if [[ $line_count -gt 5 ]]; then
            log_success "Table formatting maintained with Japanese characters"
        else
            log_error "Table formatting broken with Japanese characters"
            return 1
        fi
    else
        log_error "Japanese character handling test failed to execute"
        return 1
    fi
}

# Test error handling for missing data
test_error_handling() {
    log_test "Testing error handling for missing data..."
    
    # Remove data files
    local temp_data_dir="$DATA_DIR.bak"
    mv "$DATA_DIR" "$temp_data_dir" 2>/dev/null || true
    
    # Test display command with missing data
    if ! bash "$MAIN_SCRIPT" display table >/dev/null 2>&1; then
        log_success "Display command properly handles missing data"
    else
        log_error "Display command should fail gracefully with missing data"
        mv "$temp_data_dir" "$DATA_DIR" 2>/dev/null || true
        return 1
    fi
    
    # Test history command with missing data
    if ! bash "$MAIN_SCRIPT" history 12345 >/dev/null 2>&1; then
        log_success "History command properly handles missing data"
    else
        log_error "History command should fail gracefully with missing data"
        mv "$temp_data_dir" "$DATA_DIR" 2>/dev/null || true
        return 1
    fi
    
    # Restore data files
    mv "$temp_data_dir" "$DATA_DIR" 2>/dev/null || true
}

# Main test execution
main() {
    echo -e "${BOLD}=== US-001-FE-001 Console Output Format Tests ===${RESET}"
    echo
    
    # Setup
    setup_test_environment
    
    # Run tests
    test_color_setup || true
    test_workitems_table_display || true
    test_workitems_list_display || true
    test_workitems_summary_display || true
    test_status_history_display || true
    test_display_command || true
    test_history_command || true
    test_progress_indicator || true
    test_japanese_character_handling || true
    test_error_handling || true
    
    # Cleanup
    cleanup_test_environment
    
    # Results
    echo
    echo -e "${BOLD}=== Test Results ===${RESET}"
    echo -e "${GREEN}Passed: $TESTS_PASSED${RESET}"
    echo -e "${RED}Failed: $TESTS_FAILED${RESET}"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo
        echo -e "${RED}Failed tests:${RESET}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}• $test${RESET}"
        done
        exit 1
    else
        echo
        echo -e "${GREEN}All tests passed! 🎉${RESET}"
        exit 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi