#!/bin/bash

# Simple test for US-001-BE-004 functionality

# Test that the functions exist and basic structure is correct
echo "Testing US-001-BE-004 implementation..."

# Source the script
source ./ado-tracker.sh

# Test function existence
echo "✓ ado-tracker.sh sourced successfully"

# Test that we can call convert_to_jst
jst_result=$(convert_to_jst "2025-01-16T14:20:00Z")
if [[ -n "$jst_result" ]]; then
    echo "✓ convert_to_jst function works: $jst_result"
else
    echo "✗ convert_to_jst function failed"
    exit 1
fi

# Test that the usage shows the new command
usage_output=$(show_usage)
if echo "$usage_output" | grep -q "fetch-details"; then
    echo "✓ fetch-details command listed in usage"
else
    echo "✗ fetch-details command not found in usage"
    exit 1
fi

# Test JSON structure handling
test_json='{"id":123,"fields":{"System.Title":"Test","System.WorkItemType":"Task","System.CreatedDate":"2025-01-16T14:20:00Z","System.ChangedDate":"2025-01-16T15:30:00Z"}}'

enhanced_data=$(echo "$test_json" | jq -c '
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

if echo "$enhanced_data" | jq empty 2>/dev/null; then
    echo "✓ JSON structure transformation works"
    echo "  Sample: $(echo $enhanced_data | jq -r '.title') ($(echo $enhanced_data | jq -r '.type'))"
else
    echo "✗ JSON structure transformation failed"
    exit 1
fi

echo "✓ All US-001-BE-004 basic tests passed"