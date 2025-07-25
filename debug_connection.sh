#!/bin/bash
# Debug script for Azure DevOps connection issues
set -euo pipefail

# Load environment
source .env

echo "=== Azure DevOps 接続デバッグ ==="
echo "組織: $AZURE_DEVOPS_ORG"
echo "PAT: ${AZURE_DEVOPS_PAT:0:8}****"
echo

echo "1. 基本接続テスト"
echo "curl -v --connect-timeout 10 https://dev.azure.com"
echo "---"
curl -v --connect-timeout 10 https://dev.azure.com 2>&1 | head -20
echo
echo

echo "2. Azure DevOps API エンドポイントテスト"
API_URL="https://dev.azure.com/${AZURE_DEVOPS_ORG}/_apis/projects?api-version=7.2"
echo "URL: $API_URL"
echo "---"

# Create auth header
AUTH_HEADER="Authorization: Basic $(echo -n ":${AZURE_DEVOPS_PAT}" | base64 -w 0)"

curl -v \
  --connect-timeout 10 \
  --max-time 30 \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -H "Accept: application/json" \
  "$API_URL" 2>&1 | head -30

echo
echo "=== デバッグ完了 ==="