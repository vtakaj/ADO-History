#!/bin/bash

# Test the modified extract_status_changes function

set -euo pipefail

# Load environment variables
export $(grep -v '^#' .env | xargs)

# Source the main script
source ado-tracker.sh

# Test with actual API response
echo "Testing extract_status_changes with Work Item 5148..."

# Get actual updates
updates_response=$(get_workitem_updates "5148" "Kurohebi" 2>/dev/null)

if [[ -n "$updates_response" ]]; then
    echo "✓ Got updates response"
    
    # Extract status changes
    status_changes=$(extract_status_changes "$updates_response" "5148")
    
    if [[ -n "$status_changes" ]]; then
        echo "✓ Status changes extracted successfully"
        echo "Number of status changes: $(echo "$status_changes" | wc -l)"
        echo ""
        echo "Status changes:"
        echo "$status_changes" | jq -r '. | "Rev \(.revision): \(.previousStatus) → \(.newStatus) (\(.changeDate)) by \(.changedBy)"'
    else
        echo "✗ No status changes found"
        
        # Debug: Check what System.State entries exist
        echo "Debug: System.State entries in response:"
        echo "$updates_response" | jq '.value[] | select(.fields and .fields["System.State"]) | {rev: .rev, state: .fields["System.State"], date: .revisedDate}'
    fi
else
    echo "✗ Failed to get updates response"
fi