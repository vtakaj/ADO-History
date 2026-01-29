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
            # チケット番号に#を付けて表示
            work_content=$(echo "$active_tickets" | sed 's/\([0-9]\+\)/#\1/g')
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

# 作業記録テーブルに実際に表示されるチケットを取得
get_table_displayed_tickets() {
    local year_month="$1"
    local target_assignees="$2"  # セミコロン区切りの担当者リスト
    
    local all_tickets=""
    
    # 月の各日について処理
    local year="${year_month%-*}"
    local month="${year_month#*-}"
    local days_in_month
    days_in_month=$(date -d "${year}-${month}-01 + 1 month - 1 day" '+%d' 2>/dev/null || \
                   date -j -v+1m -v-1d -f "%Y-%m-%d" "${year}-${month}-01" '+%d' 2>/dev/null)
    
    IFS=';' read -ra assignee_array <<< "$target_assignees"
    
    for ((day=1; day<=days_in_month; day++)); do
        local current_date
        printf -v current_date "%s-%02d" "$year_month" "$day"
        
        for assignee in "${assignee_array[@]}"; do
            local day_tickets
            day_tickets=$(get_active_tickets_for_assignee_on_date "$assignee" "$current_date")
            
            if [[ -n "$day_tickets" ]]; then
                # スペース区切りのチケットIDを改行区切りに変換して追加
                local ticket_ids
                ticket_ids=$(echo "$day_tickets" | tr ' ' '\n')
                
                if [[ -n "$all_tickets" ]]; then
                    all_tickets="${all_tickets}\n${ticket_ids}"
                else
                    all_tickets="$ticket_ids"
                fi
            fi
        done
    done
    
    # 重複を削除してソート
    if [[ -n "$all_tickets" ]]; then
        echo -e "$all_tickets" | sort -u | grep -v '^$'
    fi
}

# US-001-FE-001: 月単位のチケットリスト生成
generate_ticket_list() {
    local year_month="$1"
    local target_assignees="$2"  # セミコロン区切りの担当者リスト（オプション）
    
    echo
    echo "## 対応チケット一覧 (${year_month//-/年}月)"
    echo
    
    # 作業記録テーブルに実際に表示されるチケットのみを取得
    local tickets
    if [[ -n "$target_assignees" ]]; then
        # 担当者フィルタリングありの場合：作業記録テーブルに表示されるチケットのみ
        tickets=$(get_table_displayed_tickets "$year_month" "$target_assignees")
    else
        # 全担当者の場合（従来通り）
        tickets=$(jq -r --arg year_month "$year_month" '
            .status_history[] |
            select(.changeDate | startswith($year_month)) |
            .workitemId
        ' "$DATA_DIR/status_history.json" 2>/dev/null | sort -u)
    fi
    
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
                "- **#\(.id)**: \(.title)"
            ' "$DATA_DIR/workitems.json" 2>/dev/null)
            
            if [[ -n "$ticket_info" ]]; then
                echo "$ticket_info"
            else
                echo "- **#$ticket_id**: (タイトル情報なし)"
            fi
        fi
    done
}
