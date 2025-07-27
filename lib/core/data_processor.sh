#!/bin/bash
# Data processing functions for Work Items and status history

# Extract status changes from updates
extract_status_changes() {
    local updates_json="$1"
    local workitem_id="$2"
    
    if [[ -z "$updates_json" ]]; then
        log_error "更新履歴JSONが指定されていません"
        return 1
    fi
    
    if [[ -z "$workitem_id" ]]; then
        log_error "Work Item IDが指定されていません"
        return 1
    fi
    
    # Extract status changes and calculate current assignee for each change
    echo "$updates_json" | jq -c --arg workitem_id "$workitem_id" '
        # First, get all assignee changes with their dates
        [.value[] | select(.fields."System.AssignedTo") | {
            changeDate: (.fields["System.ChangedDate"].newValue // .revisedDate),
            assignedTo: (.fields["System.AssignedTo"].newValue.displayName // .fields["System.AssignedTo"].newValue // ""),
            revision: .rev
        }] as $assignee_changes |
        
        # Function to get assignee at specific date
        def get_assignee_at_date(date):
            $assignee_changes | map(select(.changeDate <= date)) | sort_by(.changeDate) | 
            if length > 0 then .[-1].assignedTo else "" end;
        
        # Process status changes and add current assignee
        .value[] | 
        select(.fields and (.fields["System.State"] or .fields["System.Status"])) |
        
        # Calculate current assignee at the time of this status change
        ((.fields["System.ChangedDate"].newValue // .revisedDate)) as $change_date |
        
        {
            workitemId: ($workitem_id | tonumber),
            changeDate: $change_date,
            changedBy: (.revisedBy.displayName // .revisedBy.uniqueName // "Unknown"),
            assignedTo: get_assignee_at_date($change_date),
            previousStatus: (.fields["System.State"].oldValue // .fields["System.Status"].oldValue // null),
            newStatus: (.fields["System.State"].newValue // .fields["System.Status"].newValue // ""),
            revision: .rev
        } |
        # Only include actual status changes (exclude initial creation)
        select(.previousStatus != null and .previousStatus != .newStatus)
    ' 2>/dev/null || echo ""
}

# Work Items基本情報抽出
extract_workitem_info() {
    local workitems_json="$1"
    
    if [[ -z "$workitems_json" ]]; then
        log_error "Work Items JSONデータが指定されていません"
        return 1
    fi
    
    # 基本情報の抽出と検証
    echo "$workitems_json" | jq -r '.workitems[] | 
        "ID: \(.id), Title: \(.title), Assignee: \(.assignedTo), State: \(.state), Modified: \(.lastModified)"'
}

# Work Item詳細情報の抽出とマージ
merge_workitem_data() {
    local basic_data="$1"
    local details_response="$2"
    local workitem_id="$3"
    
    if [[ -z "$basic_data" ]] || [[ -z "$details_response" ]] || [[ -z "$workitem_id" ]]; then
        log_error "必要なパラメータが不足しています"
        return 1
    fi
    
    # 詳細情報を抽出し、JST変換を適用
    local enhanced_data
    enhanced_data=$(echo "$details_response" | jq -c --arg workitem_id "$workitem_id" '
        {
            id: (.id // ($workitem_id | tonumber)),
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
    
    if [[ -n "$enhanced_data" ]]; then
        # Convert dates to JST
        local created_date_utc
        created_date_utc=$(echo "$enhanced_data" | jq -r '.createdDate')
        local created_date_jst
        created_date_jst=$(convert_to_jst "$created_date_utc")
        
        local modified_date_utc
        modified_date_utc=$(echo "$enhanced_data" | jq -r '.lastModifiedDate')
        local modified_date_jst
        modified_date_jst=$(convert_to_jst "$modified_date_utc")
        
        # Update with JST dates
        enhanced_data=$(echo "$enhanced_data" | jq \
            --arg created_jst "$created_date_jst" \
            --arg modified_jst "$modified_date_jst" \
            '.createdDate = $created_jst | .lastModifiedDate = $modified_jst')
        
        echo "$enhanced_data"
        return 0
    else
        log_error "詳細情報の抽出に失敗しました"
        return 1
    fi
}

# US-001-FE-001: 担当者抽出
extract_assignees_from_history() {
    local year_month="$1"
    
    # status_historyのassignedToフィールドから担当者を取得
    jq -r --arg year_month "$year_month" '
        .status_history[] |
        select(.changeDate | startswith($year_month)) |
        select(.assignedTo != null and .assignedTo != "") |
        .assignedTo
    ' "$DATA_DIR/status_history.json" | sort -u | tr '\n' ';' | sed 's/;$//'
}

# US-001-FE-001: 指定日の担当者の稼働チケット取得
get_active_tickets_for_assignee_on_date() {
    local assignee="$1"
    local date="$2"
    
    if [[ ! -f "$DATA_DIR/status_history.json" ]] || [[ ! -f "$DATA_DIR/workitems.json" ]]; then
        return 0
    fi
    
    # status_historyのassignedToフィールドを使用して正確な担当者判定
    jq -r --arg assignee "$assignee" --arg target_date "$date" '
        .status_history | group_by(.workitemId) |
        .[] |
        select(.[0].workitemId) as $ticket_group |
        map(select(.changeDate <= ($target_date + "T23:59:59+09:00"))) | sort_by(.changeDate) |
        if length > 0 then
            .[-1] |
            if (.assignedTo == $assignee and (.newStatus == "Doing" or .newStatus == "Code Review" or .newStatus == "Active")) then
                # 指定月より前に完了チェック
                ($ticket_group | map(select(.newStatus == "Done" or .newStatus == "Completed")) | sort_by(.changeDate)) as $done_history |
                if ($done_history | length > 0) then
                    ($done_history[0].changeDate[0:7]) as $done_month |
                    ($target_date[0:7]) as $target_month |
                    if ($done_month < $target_month) then
                        empty
                    else
                        .workitemId
                    end
                else
                    .workitemId
                end
            elif (.assignedTo == $assignee and .newStatus == "Done") then
                # Done当日のみ表示（Done変更が指定日に発生した場合のみ）
                if (.changeDate[0:10] == $target_date) then
                    .workitemId
                else
                    empty  
                end
            else
                empty
            end
        else
            empty
        end
    ' "$DATA_DIR/status_history.json" 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//'
}