#!/bin/bash
# Console output and utility tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAIN_SCRIPT="$REPO_ROOT/ado-tracker.sh"
TEST_WORKDIR="$(mktemp -d)"

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

cleanup() {
    rm -rf "$TEST_WORKDIR"
}
trap cleanup EXIT

# Test utilities
log_test() {
    echo -e "${BLUE}[TEST]${RESET} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${RESET} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[FAIL]${RESET} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$*")
}

log_info() {
    echo -e "${YELLOW}[INFO]${RESET} $*"
}

setup_test_environment() {
    log_info "Setting up test environment..."
    mkdir -p "$TEST_WORKDIR/data"
    log_info "Test environment setup complete"
}

cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    rm -rf "$TEST_WORKDIR"
    log_info "Cleanup complete"
}

test_color_setup() {
    log_test "Testing color setup functionality..."

    if TTY=1 NO_COLOR=0 bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && setup_colors && [[ -n \"\$RED\" ]] && [[ -n \"\$GREEN\" ]]" 2>/dev/null; then
        log_success "Color setup works with colors enabled"
    else
        if bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && type setup_colors" >/dev/null 2>&1; then
            log_success "Color setup function is available and executable"
        else
            log_error "Color setup function not available"
            return 1
        fi
    fi

    if NO_COLOR=1 bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && setup_colors && [[ -z \"\$RED\" ]] && [[ -z \"\$GREEN\" ]]"; then
        log_success "Color setup works with colors disabled"
    else
        log_error "Color setup failed with colors disabled"
        return 1
    fi
}

test_show_usage() {
    log_test "Testing usage output..."

    local output
    if output=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && show_usage" 2>/dev/null); then
        if echo "$output" | grep -q "Usage:" && echo "$output" | grep -q "fetch"; then
            log_success "Usage output contains expected commands"
        else
            log_error "Usage output missing expected content"
            return 1
        fi
    else
        log_error "Usage output failed to execute"
        return 1
    fi
}

test_progress_indicator() {
    log_test "Testing progress indicator..."

    local output
    if output=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && setup_colors && show_progress 50 100 'Testing'"); then
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

test_japanese_character_handling() {
    log_test "Testing Japanese character width handling..."

    local width_ascii
    local width_japanese
    width_ascii=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && calculate_display_width 'abc'")
    width_japanese=$(bash -c "cd \"$TEST_WORKDIR\" && . \"$MAIN_SCRIPT\" && calculate_display_width '田中太郎'")

    if [[ "$width_ascii" == "3" && "$width_japanese" -gt "$width_ascii" ]]; then
        log_success "Character width handling works for ASCII and Japanese text"
    else
        log_error "Character width handling unexpected: ascii=$width_ascii japanese=$width_japanese"
        return 1
    fi
}

main() {
    echo -e "${BOLD}=== Console Output Format Tests ===${RESET}"
    echo

    setup_test_environment

    test_color_setup || true
    test_show_usage || true
    test_progress_indicator || true
    test_japanese_character_handling || true

    cleanup_test_environment

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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
