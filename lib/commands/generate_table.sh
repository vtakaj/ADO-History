#!/bin/bash
# Generate work table command implementation

# US-001-FE-001: 月次作業記録テーブル生成
generate_monthly_work_table() {
    local year_month="$1"      # YYYY-MM形式
    local output_file="$2"     # 出力ファイルパス
    local target_assignees="$3" # カンマ区切りの対象担当者（オプション）
    
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
    if [[ -n "$target_assignees" ]]; then
        # 指定された担当者のみを使用
        assignees=$(normalize_assignees "$target_assignees")
        log_info "対象担当者を限定: $target_assignees"
    else
        # 全担当者を自動抽出
        assignees=$(extract_assignees_from_history "$year_month")
    fi
    
    if [[ -z "$assignees" ]]; then
        if [[ -n "$target_assignees" ]]; then
            log_warn "指定された担当者($target_assignees)のステータス変更履歴が指定月($year_month)に見つかりません"
        else
            log_warn "指定月($year_month)にステータス変更履歴が見つかりません"
        fi
        echo "# 作業記録テーブル ($year_month)" > "$output_file"
        echo "" >> "$output_file"
        if [[ -n "$target_assignees" ]]; then
            echo "指定された担当者のステータス変更履歴がありません。" >> "$output_file"
        else
            echo "指定月にステータス変更履歴がありません。" >> "$output_file"
        fi
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
        generate_ticket_list "$year_month" "$assignees"
        
    } > "$output_file"
    
    log_info "作業記録テーブル生成完了: $output_file"
}

# US-001-FE-001: 作業記録テーブル生成コマンド実装
cmd_generate_work_table() {
    local year_month=""
    local output_file=""
    local target_assignees=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --assignees)
                target_assignees="$2"
                shift 2
                ;;
            -*)
                echo "Error: 不明なオプション: $1" >&2
                exit 1
                ;;
            *)
                if [[ -z "$year_month" ]]; then
                    year_month="$1"
                elif [[ -z "$output_file" ]]; then
                    output_file="$1"
                else
                    echo "Error: 余分な引数: $1" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 引数検証
    if [[ -z "$year_month" ]]; then
        echo "Error: 年月（YYYY-MM形式）を指定してください" >&2
        echo "使用例: $SCRIPT_NAME generate-work-table 2025-01 ./work_records/2025-01.md" >&2
        echo "担当者限定: $SCRIPT_NAME generate-work-table 2025-01 ./work_records/2025-01.md --assignees \"田中太郎,佐藤花子\"" >&2
        exit 1
    fi
    
    if [[ -z "$output_file" ]]; then
        echo "Error: 出力ファイルパスを指定してください" >&2
        echo "使用例: $SCRIPT_NAME generate-work-table 2025-01 ./work_records/2025-01.md" >&2
        echo "担当者限定: $SCRIPT_NAME generate-work-table 2025-01 ./work_records/2025-01.md --assignees \"田中太郎,佐藤花子\"" >&2
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
    
    if [[ -z "$target_assignees" && -n "${WORK_TABLE_ASSIGNEES:-}" ]]; then
        target_assignees="$WORK_TABLE_ASSIGNEES"
        log_info "環境変数WORK_TABLE_ASSIGNEESを使用します: $target_assignees"
    fi
    
    if [[ -n "$target_assignees" ]]; then
        log_info "作業記録テーブルを生成します: $year_month → $output_file (対象者: $target_assignees)"
    else
        log_info "作業記録テーブルを生成します: $year_month → $output_file"
    fi
    
    # テーブル生成実行
    if generate_monthly_work_table "$year_month" "$output_file" "$target_assignees"; then
        log_info "作業記録テーブルの生成が完了しました: $output_file"
        echo "${GREEN}✓${RESET} 作業記録テーブル: $output_file"
    else
        log_error "作業記録テーブルの生成に失敗しました"
        exit 1
    fi
}

normalize_assignees() {
    local input="$1"
    echo "$input" | tr ',' ';' | sed 's/[[:space:]]*;[[:space:]]*/;/g; s/^[[:space:]]*//; s/[[:space:]]*$//; s/;;*/;/g'
}
