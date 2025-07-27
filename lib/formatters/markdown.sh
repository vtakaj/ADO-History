#!/bin/bash
# Markdown formatting functions

# US-001-FE-001: テーブルヘッダー生成
generate_table_header() {
    local assignees_str="$1"
    local assignees
    IFS=';' read -ra assignees <<< "$assignees_str"
    
    echo -n "| 日付 | 曜日 |"
    for assignee in "${assignees[@]}"; do
        echo -n " ${assignee} | 作業内容 |"
    done
    echo
    
    echo -n "|------|------|"
    for assignee in "${assignees[@]}"; do
        echo -n "---------|----------|"
    done
    echo
}

# US-001-FE-001: テーブル行生成
generate_table_row() {
    local date="$1"
    local assignees_str="$2"
    local assignees
    IFS=';' read -ra assignees <<< "$assignees_str"
    
    local formatted_date
    formatted_date=$(date -d "$date" '+%Y/%m/%d' 2>/dev/null || \
                    date -j -f "%Y-%m-%d" "$date" '+%Y/%m/%d' 2>/dev/null)
    local day_of_week
    day_of_week=$(date -d "$date" '+%u' 2>/dev/null || \
                  date -j -f "%Y-%m-%d" "$date" '+%u' 2>/dev/null)
    local japanese_dow
    japanese_dow=$(get_japanese_day_of_week "$day_of_week")
    
    echo -n "| $formatted_date | $japanese_dow |"
    
    for assignee in "${assignees[@]}"; do
        local work_content=""
        local active_tickets
        active_tickets=$(get_active_tickets_for_assignee_on_date "$assignee" "$date")
        
        if [[ -n "$active_tickets" ]]; then
            work_content="$active_tickets"
        fi
        
        echo -n " | $work_content |"
    done
    echo
}

# US-001-FE-001: テーブルフッター生成
generate_table_footer() {
    local assignees_str="$1"
    local assignees
    IFS=';' read -ra assignees <<< "$assignees_str"
    
    echo -n "| **合計** | |"
    for assignee in "${assignees[@]}"; do
        echo -n " **--:--** | |"
    done
    echo
}

# US-001-FE-001: 月単位のチケットリスト生成
generate_ticket_list() {
    local year_month="$1"
    
    echo
    echo "## 対応チケット一覧 (${year_month//-/年}月)"
    echo
    
    # 指定月にステータス変更があったチケットを取得
    local tickets
    tickets=$(jq -r --arg year_month "$year_month" '
        .status_history[] |
        select(.changeDate | startswith($year_month)) |
        .workitemId
    ' "$DATA_DIR/status_history.json" 2>/dev/null | sort -u)
    
    if [[ -z "$tickets" ]]; then
        echo "該当するチケットがありません。"
        return 0
    fi
    
    # 各チケットの情報を取得して表示
    echo "$tickets" | while read -r ticket_id; do
        if [[ -n "$ticket_id" ]]; then
            local ticket_info
            ticket_info=$(jq -r --arg id "$ticket_id" '
                .workitems[] |
                select(.id == ($id | tonumber)) |
                "- **\(.id)**: \(.title)"
            ' "$DATA_DIR/workitems.json" 2>/dev/null)
            
            if [[ -n "$ticket_info" ]]; then
                echo "$ticket_info"
            else
                echo "- **$ticket_id**: (タイトル情報なし)"
            fi
        fi
    done
}