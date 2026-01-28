#!/bin/bash

# Test script for ado-tracker.sh
# shellcheck disable=SC2317
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/ado-tracker.sh"
TEST_WORKDIR="$(mktemp -d)"
TEST_COUNT=0
PASS_COUNT=0

cleanup() {
    rm -rf "$TEST_WORKDIR"
}
trap cleanup EXIT

# Test helper functions
run_test() {
    local test_name="$1"
    local expected_exit_code="$2"
    shift 2
    local command=("$@")
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"
    
    set +e
    (cd "$TEST_WORKDIR" && "${command[@]}") >/dev/null 2>&1
    local actual_exit_code=$?
    set -e
    
    if [[ $actual_exit_code -eq $expected_exit_code ]]; then
        echo "  ✓ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ✗ FAIL (expected exit code $expected_exit_code, got $actual_exit_code)"
    fi
    echo
}

run_test_with_output() {
    local test_name="$1"
    local expected_exit_code="$2"
    local expected_output="$3"
    shift 3
    local command=("$@")
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"
    
    set +e
    local output
    output=$(cd "$TEST_WORKDIR" && "${command[@]}" 2>&1)
    local actual_exit_code=$?
    set -e
    
    local pass=true
    
    if [[ $actual_exit_code -ne $expected_exit_code ]]; then
        echo "  ✗ FAIL (expected exit code $expected_exit_code, got $actual_exit_code)"
        pass=false
    fi
    
    if [[ "$output" != *"$expected_output"* ]]; then
        echo "  ✗ FAIL (expected output to contain '$expected_output')"
        echo "  Actual output: $output"
        pass=false
    fi
    
    if $pass; then
        echo "  ✓ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
    echo
}

echo "Running tests for ado-tracker.sh"
echo "=================================="
echo

# Test 1: Check if script is executable
if [[ -x "$SCRIPT_PATH" ]]; then
    echo "✓ Script is executable"
else
    echo "✗ Script is not executable"
    exit 1
fi
echo

# Test 2: No arguments - should show error and usage
run_test_with_output "No arguments" 1 "Error: コマンドを指定してください" "$SCRIPT_PATH"

# Test 3: Help option
run_test_with_output "Help option" 0 "Usage:" "$SCRIPT_PATH" --help

# Test 4: Help command  
run_test_with_output "Help command" 0 "Usage:" "$SCRIPT_PATH" help

# Test 5: Version option
run_test_with_output "Version option" 0 "v1.0.0" "$SCRIPT_PATH" --version

# Test 6: Invalid command
run_test_with_output "Invalid command" 1 "Error: 不明なコマンド" "$SCRIPT_PATH" invalid_command

# Test 7: Fetch command without default project (AZURE_DEVOPS_PROJECT)
run_test_with_output "Fetch without default project" 1 "AZURE_DEVOPS_PROJECT が設定されていません" "$SCRIPT_PATH" fetch

# Test 8: Fetch with invalid project name from env
run_test_with_output "Fetch with invalid project name" 1 "Error: プロジェクト名に無効な文字が含まれています" env AZURE_DEVOPS_PROJECT=invalid@project "$SCRIPT_PATH" fetch 30

# Test 9: Fetch with invalid days
run_test_with_output "Fetch with invalid days" 1 "Error: 日数は1-365の範囲で指定してください" env AZURE_DEVOPS_PROJECT=validproject "$SCRIPT_PATH" fetch 0

# Test 10: Fetch with valid arguments (missing PAT causes config error)
run_test_with_output "Fetch with valid arguments" 2 "AZURE_DEVOPS_PAT が設定されていません" env AZURE_DEVOPS_PROJECT=TestProject "$SCRIPT_PATH" fetch 30

# Configuration Management Tests

# Test 12: Config show command
run_test_with_output "Config show command" 0 "Azure DevOps Tracker 設定情報" "$SCRIPT_PATH" config show

# Test 13: Config show (default)
run_test_with_output "Config show (default)" 0 "Azure DevOps Tracker 設定情報" "$SCRIPT_PATH" config

# Test 14: Config template generation
run_test_with_output "Config template generation" 0 ".env.template を生成しました" "$SCRIPT_PATH" config template

# Test 15: Config validate without PAT
run_test_with_output "Config validate without PAT" 2 "AZURE_DEVOPS_PAT が設定されていません" "$SCRIPT_PATH" config validate

# Test 16: Config invalid subcommand
run_test_with_output "Config invalid subcommand" 1 "Usage: ado-tracker.sh config" "$SCRIPT_PATH" config invalid

# API Connection Tests

# Test 17: Test connection without PAT
run_test_with_output "Test connection without PAT" 1 "AZURE_DEVOPS_PAT が設定されていません" "$SCRIPT_PATH" test-connection

# Test 18: Test connection command availability
run_test_with_output "Test connection command in help" 0 "test-connection" "$SCRIPT_PATH" help

echo "=================================="
echo "Test Summary:"
echo "Total tests: $TEST_COUNT"
echo "Passed: $PASS_COUNT"
echo "Failed: $((TEST_COUNT - PASS_COUNT))"

if [[ $PASS_COUNT -eq $TEST_COUNT ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed!"
    exit 1
fi
