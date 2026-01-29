#!/bin/bash
# US-001-FE-001: Work Table Generation Test (Updated Specification)
set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAIN_SCRIPT="$REPO_ROOT/ado-tracker.sh"
TEST_WORKDIR="$(mktemp -d)"
TEST_DATA_DIR="$TEST_WORKDIR/test_data"
DATA_DIR="$TEST_WORKDIR/data"
TEST_OUTPUT_DIR="$TEST_WORKDIR/test_output"

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
    
    # Create test directories
    mkdir -p "$TEST_DATA_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$TEST_OUTPUT_DIR"
    
    # Create sample workitems.json
    cat > "$DATA_DIR/workitems.json" << 'EOF'
{
  "workitems": [
    {
      "id": 12345,
      "title": "Implement user authentication feature",
      "assignedTo": "田中太郎",
      "state": "Done",
      "lastModified": "2025-01-15T10:30:00+09:00"
    },
    {
      "id": 12346,
      "title": "Fix login validation bug",
      "assignedTo": "佐藤花子",
      "state": "Done",
      "lastModified": "2025-01-14T15:45:00+09:00"
    },
    {
      "id": 12347,
      "title": "Update API documentation",
      "assignedTo": "鈴木一郎",
      "state": "Blocked",
      "lastModified": "2025-01-13T09:20:00+09:00"
    },
    {
      "id": 12348,
      "title": "Refactor database connection pool",
      "assignedTo": "田中太郎",
      "state": "Done",
      "lastModified": "2025-01-12T14:15:00+09:00"
    }
  ]
}
EOF

    # Create sample status_history.json with realistic workflow
    cat > "$DATA_DIR/status_history.json" << 'EOF'
{
  "status_history": [
    {
      "workitemId": 12345,
      "changeDate": "2025-01-10T09:00:00+09:00",
      "changedBy": "田中太郎",
      "assignedTo": "田中太郎",
      "previousStatus": "New",
      "newStatus": "Doing",
      "revision": 1
    },
    {
      "workitemId": 12345,
      "changeDate": "2025-01-15T17:30:00+09:00",
      "changedBy": "田中太郎",
      "assignedTo": "田中太郎",
      "previousStatus": "Doing",
      "newStatus": "Done",
      "revision": 2
    },
    {
      "workitemId": 12346,
      "changeDate": "2025-01-12T10:00:00+09:00",
      "changedBy": "佐藤花子",
      "assignedTo": "佐藤花子",
      "previousStatus": "New",
      "newStatus": "Doing",
      "revision": 1
    },
    {
      "workitemId": 12346,
      "changeDate": "2025-01-14T15:45:00+09:00",
      "changedBy": "佐藤花子",
      "assignedTo": "佐藤花子",
      "previousStatus": "Doing",
      "newStatus": "Done",
      "revision": 2
    },
    {
      "workitemId": 12347,
      "changeDate": "2025-01-11T14:00:00+09:00",
      "changedBy": "鈴木一郎",
      "assignedTo": "鈴木一郎",
      "previousStatus": "New",
      "newStatus": "Doing",
      "revision": 1
    },
    {
      "workitemId": 12347,
      "changeDate": "2025-01-13T09:20:00+09:00",
      "changedBy": "鈴木一郎",
      "assignedTo": "鈴木一郎",
      "previousStatus": "Doing",
      "newStatus": "Blocked",
      "revision": 2
    },
    {
      "workitemId": 12347,
      "changeDate": "2025-01-20T10:00:00+09:00",
      "changedBy": "鈴木一郎",
      "assignedTo": "鈴木一郎",
      "previousStatus": "Blocked",
      "newStatus": "Doing",
      "revision": 3
    },
    {
      "workitemId": 12348,
      "changeDate": "2025-01-08T11:00:00+09:00",
      "changedBy": "田中太郎",
      "assignedTo": "田中太郎",
      "previousStatus": "New",
      "newStatus": "Doing",
      "revision": 1
    },
    {
      "workitemId": 12348,
      "changeDate": "2025-01-12T14:15:00+09:00",
      "changedBy": "田中太郎",
      "assignedTo": "田中太郎",
      "previousStatus": "Doing",
      "newStatus": "Done",
      "revision": 2
    }
  ]
}
EOF

    log_info "Test environment setup complete"
}

# Cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    rm -rf "$TEST_WORKDIR"
    log_info "Cleanup complete"
}

# Test assignee extraction
test_assignee_extraction() {
    log_test "Testing assignee extraction from history..."
    
    local assignees
    if assignees=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && extract_assignees_from_history '2025-01'" 2>/dev/null); then
        # Check for expected assignees
        if echo "$assignees" | grep -q "田中太郎" && echo "$assignees" | grep -q "佐藤花子" && echo "$assignees" | grep -q "鈴木一郎"; then
            log_success "Assignee extraction includes all expected members"
        else
            log_error "Assignee extraction missing expected members: $assignees"
            return 1
        fi
    else
        log_error "Assignee extraction failed to execute"
        return 1
    fi
}

# Test table header generation
test_table_header_generation() {
    log_test "Testing table header generation..."
    
    local output
    if output=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && generate_table_header '田中太郎;佐藤花子;鈴木一郎'" 2>/dev/null); then
        # Check for required headers
        if echo "$output" | grep -q "| 日付 | 曜日 |" && echo "$output" | grep -q "田中太郎" && echo "$output" | grep -q "佐藤花子" && echo "$output" | grep -q "鈴木一郎"; then
            log_success "Table header contains all required columns"
        else
            log_error "Table header missing required columns"
            return 1
        fi
        
        # Check for separator line
        if echo "$output" | grep -q "|------|------|"; then
            log_success "Table header contains separator line"
        else
            log_error "Table header missing separator line"
            return 1
        fi
    else
        log_error "Table header generation failed to execute"
        return 1
    fi
}

# Test Japanese day of week function
test_japanese_day_of_week() {
    log_test "Testing Japanese day of week conversion..."
    
    local monday
    if monday=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && get_japanese_day_of_week 1" 2>/dev/null); then
        if [[ "$monday" == "月" ]]; then
            log_success "Japanese day conversion works for Monday"
        else
            log_error "Japanese day conversion incorrect for Monday: $monday"
            return 1
        fi
    else
        log_error "Japanese day conversion failed to execute"
        return 1
    fi
    
    local sunday
    if sunday=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && get_japanese_day_of_week 7" 2>/dev/null); then
        if [[ "$sunday" == "日" ]]; then
            log_success "Japanese day conversion works for Sunday"
        else
            log_error "Japanese day conversion incorrect for Sunday: $sunday"
            return 1
        fi
    else
        log_error "Japanese day conversion failed for Sunday"
        return 1
    fi
}

# Test active tickets detection
test_active_tickets_detection() {
    log_test "Testing active tickets detection..."
    
    # Test for a day when ticket 12345 should be active (during Doing period)
    local active_tickets
    if active_tickets=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && get_active_tickets_for_assignee_on_date '田中太郎' '2025-01-12'" 2>/dev/null); then
        if echo "$active_tickets" | grep -q "12345"; then
            log_success "Active tickets detection works for ongoing ticket"
        else
            log_error "Active tickets detection missed ongoing ticket 12345: '$active_tickets'"
            return 1
        fi
    else
        log_error "Active tickets detection failed to execute"
        return 1
    fi
    
    # Test for a day when ticket should be done
    local done_tickets
    if done_tickets=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && get_active_tickets_for_assignee_on_date '田中太郎' '2025-01-15'" 2>/dev/null); then
        if echo "$done_tickets" | grep -q "12345"; then
            log_success "Active tickets detection works for completion day"
        else
            log_error "Active tickets detection missed completion day for ticket 12345: '$done_tickets'"
            return 1
        fi
    else
        log_error "Active tickets detection failed for completion day"
        return 1
    fi
}

# Test ticket list generation
test_ticket_list_generation() {
    log_test "Testing ticket list generation..."
    
    local output
    if output=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && generate_ticket_list '2025-01' ''" 2>/dev/null); then
        # Check for list header
        if echo "$output" | grep -q "## 対応チケット一覧"; then
            log_success "Ticket list contains header"
        else
            log_error "Ticket list missing header"
            return 1
        fi
        
        # Check for ticket entries
        if echo "$output" | grep -q "12345" && echo "$output" | grep -q "12346"; then
            log_success "Ticket list contains expected tickets"
        else
            log_error "Ticket list missing expected tickets"
            return 1
        fi
        
        # Check for markdown format
        if echo "$output" | grep -Fq -- "- **#"; then
            log_success "Ticket list uses correct markdown format"
        else
            log_error "Ticket list incorrect markdown format"
            return 1
        fi
    else
        log_error "Ticket list generation failed to execute"
        return 1
    fi
}

# Test full work table generation
test_full_work_table_generation() {
    log_test "Testing full work table generation..."
    
    local output_file="$TEST_OUTPUT_DIR/test_2025-01.md"
    
    if (cd "$TEST_WORKDIR" && bash "$MAIN_SCRIPT" generate-work-table 2025-01 "$output_file" >/dev/null 2>&1); then
        log_success "Work table generation command executed successfully"
        
        if [[ -f "$output_file" ]]; then
            log_success "Work table output file created"
            
            # Check file contents
            local content
            content=$(cat "$output_file")
            
            # Check for markdown title
            if echo "$content" | grep -q "# 作業記録テーブル (2025-01)"; then
                log_success "Work table contains proper title"
            else
                log_error "Work table missing title"
                return 1
            fi
            
            # Check for table structure
            if echo "$content" | grep -q "| 日付 | 曜日 |"; then
                log_success "Work table contains table structure"
            else
                log_error "Work table missing table structure"
                return 1
            fi
            
            # Check for ticket list
            if echo "$content" | grep -q "## 対応チケット一覧"; then
                log_success "Work table contains ticket list"
            else
                log_error "Work table missing ticket list"
                return 1
            fi
            
            # Check for month entries (should have 31 days in January)
            local day_count
            day_count=$(echo "$content" | grep -c "| 2025/01/[0-9][0-9] |" || true)
            if [[ $day_count -eq 31 ]]; then
                log_success "Work table contains all 31 days of January"
            else
                log_error "Work table has incorrect number of days: $day_count (expected 31)"
                return 1
            fi
            
        else
            log_error "Work table output file not created"
            return 1
        fi
    else
        log_error "Work table generation command failed"
        return 1
    fi
}

# Test command validation
test_command_validation() {
    log_test "Testing command validation..."
    
    # Test missing arguments
    if ! (cd "$TEST_WORKDIR" && bash "$MAIN_SCRIPT" generate-work-table >/dev/null 2>&1); then
        log_success "Command properly validates missing arguments"
    else
        log_error "Command should fail with missing arguments"
        return 1
    fi
    
    # Test invalid date format
    if ! (cd "$TEST_WORKDIR" && bash "$MAIN_SCRIPT" generate-work-table "2025-1" "/tmp/test.md" >/dev/null 2>&1); then
        log_success "Command properly validates invalid date format"
    else
        log_error "Command should fail with invalid date format"
        return 1
    fi
    
    # Test missing data files
    local temp_data_dir="$DATA_DIR.bak"
    mv "$DATA_DIR" "$temp_data_dir" 2>/dev/null || true
    
    if ! (cd "$TEST_WORKDIR" && bash "$MAIN_SCRIPT" generate-work-table 2025-01 "/tmp/test.md" >/dev/null 2>&1); then
        log_success "Command properly handles missing data files"
    else
        log_error "Command should fail with missing data files"
        mv "$temp_data_dir" "$DATA_DIR" 2>/dev/null || true
        return 1
    fi
    
    # Restore data files
    mv "$temp_data_dir" "$DATA_DIR" 2>/dev/null || true
}

# Test blocked status handling
test_blocked_status_handling() {
    log_test "Testing blocked status handling..."
    
    # Test that ticket 12347 shows as active on 2025-01-12 (during Doing)
    local active_before_blocked
    if active_before_blocked=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && get_active_tickets_for_assignee_on_date '鈴木一郎' '2025-01-12'" 2>/dev/null); then
        if echo "$active_before_blocked" | grep -q "12347"; then
            log_success "Blocked status handling: ticket active before blocking"
        else
            log_error "Blocked status handling: ticket should be active before blocking"
            return 1
        fi
    else
        log_error "Blocked status handling test failed to execute"
        return 1
    fi
    
    # Test that ticket 12347 shows as active on 2025-01-20 (unblocked day)
    local active_after_unblocked
    if active_after_unblocked=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && get_active_tickets_for_assignee_on_date '鈴木一郎' '2025-01-20'" 2>/dev/null); then
        if echo "$active_after_unblocked" | grep -q "12347"; then
            log_success "Blocked status handling: ticket active after unblocking"
        else
            log_error "Blocked status handling: ticket should be active after unblocking"
            return 1
        fi
    else
        log_error "Blocked status handling test for unblocking failed"
        return 1
    fi
}

# Test last day of month calculation
test_last_day_calculation() {
    log_test "Testing last day of month calculation..."
    
    local last_day_jan
    if last_day_jan=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && get_last_day_of_month '2025-01'" 2>/dev/null); then
        if [[ "$last_day_jan" == "2025-01-31" ]]; then
            log_success "Last day calculation works for January"
        else
            log_error "Last day calculation incorrect for January: $last_day_jan"
            return 1
        fi
    else
        log_error "Last day calculation failed for January"
        return 1
    fi
    
    local last_day_feb
    if last_day_feb=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && get_last_day_of_month '2025-02'" 2>/dev/null); then
        if [[ "$last_day_feb" == "2025-02-28" ]]; then
            log_success "Last day calculation works for February (non-leap year)"
        else
            log_error "Last day calculation incorrect for February: $last_day_feb"
            return 1
        fi
    else
        log_error "Last day calculation failed for February"
        return 1
    fi
}

# Main test execution
main() {
    echo -e "${BOLD}=== US-001-FE-001 Work Table Generation Tests ===${RESET}"
    echo
    
    # Setup
    setup_test_environment
    
    # Run tests
    test_assignee_extraction || true
    test_table_header_generation || true
    test_japanese_day_of_week || true
    test_active_tickets_detection || true
    test_ticket_list_generation || true
    test_full_work_table_generation || true
    test_command_validation || true
    test_blocked_status_handling || true
    test_last_day_calculation || true
    
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
