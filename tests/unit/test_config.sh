#!/bin/bash

# Advanced configuration tests for ado-tracker.sh
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/ado-tracker.sh"
TEST_WORKDIR="$(mktemp -d)"
TEST_COUNT=0
PASS_COUNT=0

reset_env_files() {
    rm -f "$TEST_WORKDIR/.env" "$TEST_WORKDIR/.env.template"
    unset AZURE_DEVOPS_PAT AZURE_DEVOPS_ORG AZURE_DEVOPS_PROJECT 2>/dev/null || true
}

# Cleanup function
cleanup() {
    rm -rf "$TEST_WORKDIR"
    unset AZURE_DEVOPS_PAT AZURE_DEVOPS_ORG AZURE_DEVOPS_PROJECT 2>/dev/null || true
}

# Test helper functions
run_test_with_env() {
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

echo "Running advanced configuration tests for ado-tracker.sh"
echo "========================================================"
echo

# Setup
trap cleanup EXIT

# Test 1: Environment variable validation with valid PAT
export AZURE_DEVOPS_PAT="abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnop"
export AZURE_DEVOPS_ORG="testorg"
export AZURE_DEVOPS_PROJECT="testproject"
run_test_with_env "Config validate with valid settings" 0 "設定は正常です" "$SCRIPT_PATH" config validate

# Test 1b: Missing default project
export AZURE_DEVOPS_PROJECT=""
run_test_with_env "Config validate without project" 2 "AZURE_DEVOPS_PROJECT が設定されていません" "$SCRIPT_PATH" config validate

# Test 2: Environment variable validation with short PAT
export AZURE_DEVOPS_PAT="short"
export AZURE_DEVOPS_PROJECT="testproject"
run_test_with_env "Config validate with short PAT" 2 "AZURE_DEVOPS_PAT の形式が正しくありません" "$SCRIPT_PATH" config validate

# Test 3: Environment variable validation with invalid org name
export AZURE_DEVOPS_PAT="abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnop"
export AZURE_DEVOPS_ORG="invalid-org-"
export AZURE_DEVOPS_PROJECT="testproject"
run_test_with_env "Config validate with invalid org name" 2 "AZURE_DEVOPS_ORG の形式が正しくありません" "$SCRIPT_PATH" config validate

# Test 4: Config show with environment variables
export AZURE_DEVOPS_ORG="testorg"
export AZURE_DEVOPS_PROJECT="testproject"
run_test_with_env "Config show with env vars" 0 "組織名: testorg" "$SCRIPT_PATH" config show

# Test 5: .env file loading
reset_env_files
mkdir -p "$TEST_WORKDIR"
cat > "$TEST_WORKDIR/.env" << 'EOF'
AZURE_DEVOPS_PAT=abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnop
AZURE_DEVOPS_ORG=envfileorg
AZURE_DEVOPS_PROJECT=envfileproject
LOG_LEVEL=ERROR
EOF
chmod 600 "$TEST_WORKDIR/.env"

run_test_with_env ".env file loading" 0 "組織名: envfileorg" "$SCRIPT_PATH" config show

# Test 6: .env file with unsafe permissions
chmod 644 "$TEST_WORKDIR/.env"
run_test_with_env ".env file unsafe permissions warning" 0 ".envファイルの権限が安全ではありません" "$SCRIPT_PATH" config show

# Test 7: Template generation creates file
reset_env_files
run_test_with_env "Template generation" 0 ".env.template を生成しました" "$SCRIPT_PATH" config template

# Verify template file was created
if [[ -f "$TEST_WORKDIR/.env.template" ]]; then
    echo "  ✓ .env.template file created"
    # Check permissions
    perms=$(stat -c %a "$TEST_WORKDIR/.env.template" 2>/dev/null || stat -f %A "$TEST_WORKDIR/.env.template" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        echo "  ✓ .env.template has correct permissions (600)"
    else
        echo "  ✗ .env.template has incorrect permissions: $perms"
    fi
else
    echo "  ✗ .env.template file was not created"
fi
echo

# Test 8: PAT masking functionality
export AZURE_DEVOPS_PAT="abcdefghijklmnop"
run_test_with_env "Config show masks PAT" 0 "PAT設定: 設定済み" "$SCRIPT_PATH" config show

# Test 9: Invalid API version
export API_VERSION="invalid"
export AZURE_DEVOPS_PROJECT="testproject"
run_test_with_env "Config validate with invalid API version" 2 "API_VERSION の形式が正しくありません" "$SCRIPT_PATH" config validate

# Test 10: Invalid retry count
export API_VERSION="7.2"
export RETRY_COUNT="15"
export AZURE_DEVOPS_PROJECT="testproject"
run_test_with_env "Config validate with invalid retry count" 2 "RETRY_COUNT は0-10の範囲で設定してください" "$SCRIPT_PATH" config validate

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
