#!/bin/bash
# Generate work table command implementation

# US-001-FE-001: 月次作業記録テーブル生成
generate_monthly_work_table() {
    local year_month="$1"      # YYYY-MM形式
    local output_file="$2"     # 出力ファイルパス
    
    if [[ -z "$year_month" ]] || [[ -z "$output_file" ]]; then
        log_error "年月（YYYY-MM）と出力ファイルパスを指定してください"
        return 1
    fi
    
    # データファイル存在確認
    if [[ ! -f "$DATA_DIR/workitems.json" ]] || [[ ! -f "$DATA_DIR/status_history.json" ]]; then
        log_error "チケットデータまたはステータス履歴データが見つかりません"
        return 1
    fi
    
    log_info "月次作業記録テーブルを生成中: $year_month"
    
    # 出力ディレクトリ作成
    mkdir -p "$(dirname "$output_file")"
    
    # ステータス履歴から担当者を抽出
    local assignees
    assignees=$(extract_assignees_from_history "$year_month")
    
    if [[ -z "$assignees" ]]; then
        log_warn "指定月($year_month)にステータス変更履歴が見つかりません"
        echo "# 作業記録テーブル ($year_month)" > "$output_file"
        echo "" >> "$output_file"
        echo "指定月にステータス変更履歴がありません。" >> "$output_file"
        return 0
    fi
    
    # テーブル生成
    {
        echo "# 作業記録テーブル ($year_month)"
        echo ""
        generate_table_header "$assignees"
        
        # 月の各日についてテーブル行を生成
        local start_date="${year_month}-01"
        local end_date
        end_date=$(get_last_day_of_month "$year_month")
        
        # 月の日数を計算
        local year="${year_month%-*}"
        local month="${year_month#*-}"
        local days_in_month
        days_in_month=$(date -d "${year}-${month}-01 + 1 month - 1 day" '+%d' 2>/dev/null || \
                       date -j -v+1m -v-1d -f "%Y-%m-%d" "${year}-${month}-01" '+%d' 2>/dev/null)
        
        # 各日のテーブル行を生成
        for ((day=1; day<=days_in_month; day++)); do
            local current_date
            printf -v current_date "%s-%02d" "$year_month" "$day"
            generate_table_row "$current_date" "$assignees"
        done
        
        # フッター（月間合計）生成
        generate_table_footer "$assignees"
        
        # チケットリスト生成
        generate_ticket_list "$year_month"
        
    } > "$output_file"
    
    log_info "作業記録テーブル生成完了: $output_file"
}

# US-001-FE-001: 作業記録テーブル生成コマンド実装
cmd_generate_work_table() {
    local year_month="${1:-}"
    local output_file="${2:-}"
    
    # 引数検証
    if [[ -z "$year_month" ]]; then
        echo "Error: 年月（YYYY-MM形式）を指定してください" >&2
        echo "使用例: $SCRIPT_NAME generate-work-table 2025-01 ./work_records/2025-01.md" >&2
        exit 1
    fi
    
    if [[ -z "$output_file" ]]; then
        echo "Error: 出力ファイルパスを指定してください" >&2
        echo "使用例: $SCRIPT_NAME generate-work-table 2025-01 ./work_records/2025-01.md" >&2
        exit 1
    fi
    
    # 年月形式検証
    if [[ ! "$year_month" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
        echo "Error: 年月はYYYY-MM形式で指定してください（例: 2025-01）" >&2
        exit 1
    fi
    
    # データファイル存在確認
    if [[ ! -f "$DATA_DIR/workitems.json" ]] || [[ ! -f "$DATA_DIR/status_history.json" ]]; then
        echo "${RED}エラー: チケットデータまたはステータス履歴データが見つかりません${RESET}" >&2
        echo "先に fetch コマンドでデータを取得してください" >&2
        exit 1
    fi
    
    log_info "作業記録テーブルを生成します: $year_month → $output_file"
    
    # テーブル生成実行
    if generate_monthly_work_table "$year_month" "$output_file"; then
        log_info "作業記録テーブルの生成が完了しました: $output_file"
        echo "${GREEN}✓${RESET} 作業記録テーブル: $output_file"
    else
        log_error "作業記録テーブルの生成に失敗しました"
        exit 1
    fi
}