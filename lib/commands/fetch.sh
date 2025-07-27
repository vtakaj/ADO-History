#!/bin/bash
# Fetch command implementations

# Work Items取得（Enhanced with US-001-BE-005 checkpoint support）
fetch_workitems() {
    local project="$1"
    local days="${2:-30}"
    
    log_info "プロジェクト '$project' のWork Items取得を開始"
    
    # データディレクトリ初期化
    init_data_directories
    
    # US-001-BE-005: Check for existing checkpoint
    local checkpoint_data
    if checkpoint_data=$(load_checkpoint); then
        local checkpoint_operation
        checkpoint_operation=$(echo "$checkpoint_data" | jq -r '.operation')
        if [[ "$checkpoint_operation" == "fetch_workitems" ]]; then
            log_info "前回の中断から復旧します"
            local checkpoint_project
            checkpoint_project=$(echo "$checkpoint_data" | jq -r '.data.project')
            if [[ "$checkpoint_project" == "$project" ]]; then
                log_info "同一プロジェクトのチェックポイントが見つかりました。継続処理を開始します"
            else
                log_warn "異なるプロジェクトのチェックポイントです。新規処理を開始します"
                clear_checkpoint
            fi
        else
            log_warn "異なる操作のチェックポイントです。新規処理を開始します"
            clear_checkpoint
        fi
    fi
    
    # 日付フィルタ計算（WIQL用に日付のみの形式）
    local changed_date=$(date -d "$days days ago" '+%Y-%m-%d' 2>/dev/null || date -v-${days}d '+%Y-%m-%d' 2>/dev/null)
    
    # Work Items WIQL (Work Item Query Language) APIを使用
    local wiql_endpoint="${project}/_apis/wit/wiql"
    
    # WIQL クエリ（過去N日間のWork Items）
    # プロジェクト内の全Work Itemsから日付フィルタで絞り込み
    local wiql_query="SELECT [System.Id] FROM WorkItems WHERE [System.ChangedDate] >= '$changed_date' ORDER BY [System.ChangedDate] DESC"
    
    local wiql_data="{\"query\": \"$wiql_query\"}"
    
    log_info "WIQL クエリでWork Items IDsを取得中"
    if [[ "$LOG_LEVEL" == "INFO" ]]; then
        log_info "クエリ: $wiql_query"
    fi
    
    # WIQLクエリでWork Item IDsを取得
    local wiql_response
    if wiql_response=$(call_ado_api "$wiql_endpoint" "POST" "$wiql_data"); then
        log_info "WIQL クエリ成功"
        
        
        # レスポンスからJSONの開始位置を見つける
        local json_response
        json_response=$(echo "$wiql_response" | grep -o '{.*}' | head -1)
        
        # JSONが有効かチェック
        if ! echo "$json_response" | jq empty 2>/dev/null; then
            log_error "無効なJSONレスポンスを受信しました"
            log_error "元レスポンス: $(echo "$wiql_response" | head -c 500)..."
            return 1
        fi
        
        # 有効なJSONレスポンスを使用
        wiql_response="$json_response"
        
        # Work Item IDsを抽出
        local workitem_ids
        workitem_ids=$(echo "$wiql_response" | jq -r '.workItems[]?.id' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        
        if [[ -z "$workitem_ids" ]]; then
            log_info "指定条件のWork Itemsが見つかりませんでした"
            save_json "workitems.json" '{"workitems": []}'
            return 0
        fi
        
        log_info "Work Item IDs取得: $(echo "$workitem_ids" | tr ',' '\n' | wc -l)件"
        
        # Work Items詳細を取得（バッチ処理）
        local all_workitems='{"workitems": []}'
        local total_count=0
        
        # IDsを配列に変換してバッチ処理
        local ids_array
        ids_array=$(echo "$workitem_ids" | tr ',' '\n')
        
        local batch_ids=""
        local batch_count=0
        
        while IFS= read -r id; do
            if [[ -n "$id" ]]; then
                if [[ -n "$batch_ids" ]]; then
                    batch_ids="${batch_ids},${id}"
                else
                    batch_ids="$id"
                fi
                ((batch_count++))
                
                # バッチサイズに達したか、最後のIDの場合は処理実行
                local total_ids_count
                total_ids_count=$(echo "$ids_array" | wc -l)
                local current_total=$((total_count + batch_count))
                if [[ $batch_count -ge $BATCH_SIZE ]] || [[ $total_ids_count -eq $current_total ]]; then
                    local batch_endpoint="${project}/_apis/wit/workitems?ids=${batch_ids}&\$expand=Fields"
                    
                    log_info "Work Items詳細取得 (バッチ: $batch_count件)"
                    
                    local batch_response
                    if batch_response=$(call_ado_api "$batch_endpoint"); then
                        # Work Items情報を抽出
                        local workitems_batch
                        workitems_batch=$(echo "$batch_response" | jq -c '.value[] | {id: .id, title: (.fields["System.Title"] // ""), assignedTo: ((.fields["System.AssignedTo"] // {}).displayName // ""), state: (.fields["System.State"] // ""), lastModified: (.fields["System.ChangedDate"] // "")}')
                        
                        if [[ -n "$workitems_batch" ]]; then
                            local batch_array
                            batch_array=$(echo "$workitems_batch" | jq -s '.')
                            
                            all_workitems=$(echo "$all_workitems" | jq --argjson batch "$batch_array" '.workitems += $batch')
                            
                            total_count=$((total_count + batch_count))
                            log_info "バッチ処理完了: $batch_count件 (累計: $total_count件)"
                        fi
                        
                        # レート制限対応の待機
                        sleep 0.5
                    else
                        log_error "Work Items詳細取得に失敗: IDs=$batch_ids"
                        return 1
                    fi
                    
                    # バッチリセット
                    batch_ids=""
                    batch_count=0
                fi
            fi
        done <<< "$ids_array"
        
    else
        log_error "WIQL クエリに失敗しました"
        return 1
    fi
    
    # データの保存
    if save_json "workitems.json" "$all_workitems"; then
        log_info "Work Items取得完了: $total_count件"
        log_info "保存先: $DATA_DIR/workitems.json"
        
        # US-001-BE-005: Clear checkpoint on successful completion
        clear_checkpoint
        
        return 0
    else
        log_error "Work Itemsの保存に失敗しました"
        
        # US-001-BE-005: Save checkpoint for recovery
        local checkpoint_state
        checkpoint_state=$(jq -n \
            --arg project "$project" \
            --arg days "$days" \
            --arg total_count "$total_count" \
            '{
                project: $project,
                days: $days,
                processed_count: ($total_count | tonumber),
                stage: "data_save_failed"
            }')
        save_checkpoint "$checkpoint_state" "fetch_workitems"
        
        return 1
    fi
}

# Fetch status history for all work items
fetch_all_status_history() {
    local project="$1"
    
    if [[ -z "$project" ]]; then
        log_error "プロジェクト名が指定されていません"
        return 1
    fi
    
    log_info "全Work Itemsのステータス変更履歴取得を開始"
    
    # Load work items data
    local workitems_data
    workitems_data=$(load_json "workitems.json")
    
    if [[ -z "$workitems_data" ]] || [[ "$workitems_data" == "{}" ]]; then
        log_error "Work Itemsデータが見つかりません。先にfetchコマンドを実行してください"
        return 1
    fi
    
    # Get work item IDs
    local workitem_ids
    workitem_ids=$(echo "$workitems_data" | jq -r '.workitems[].id' 2>/dev/null)
    
    if [[ -z "$workitem_ids" ]]; then
        log_error "Work Item IDsが取得できませんでした"
        return 1
    fi
    
    local total_items
    total_items=$(echo "$workitem_ids" | wc -l)
    log_info "処理対象Work Items: $total_items件"
    
    local all_status_history='{"status_history": []}'
    local processed_count=0
    
    while IFS= read -r workitem_id; do
        if [[ -n "$workitem_id" ]]; then
            ((processed_count++))
            log_info "進捗: $processed_count/$total_items - Work Item $workitem_id の履歴取得中"
            
            # Get updates for this work item
            local updates_response
            if updates_response=$(get_workitem_updates "$workitem_id" "$project"); then
                # Extract status changes
                local status_changes
                status_changes=$(extract_status_changes "$updates_response" "$workitem_id")
                
                if [[ -n "$status_changes" ]]; then
                    # Process each status change and convert to JST
                    while IFS= read -r change; do
                        if [[ -n "$change" ]]; then
                            # Convert changeDate to JST
                            local jst_change
                            local original_date
                            original_date=$(echo "$change" | jq -r '.changeDate')
                            local jst_date
                            jst_date=$(convert_to_jst "$original_date")
                            
                            jst_change=$(echo "$change" | jq --arg jst_date "$jst_date" '.changeDate = $jst_date')
                            
                            # Add to all_status_history
                            all_status_history=$(echo "$all_status_history" | jq --argjson change "$jst_change" '.status_history += [$change]')
                        fi
                    done <<< "$status_changes"
                fi
                
                # Rate limiting - wait between requests
                sleep 0.5
            else
                log_warn "Work Item $workitem_id の履歴取得をスキップ"
            fi
        fi
    done <<< "$workitem_ids"
    
    # Sort status history by change date
    all_status_history=$(echo "$all_status_history" | jq '.status_history |= sort_by(.changeDate)')
    
    # Save status history
    if save_json "status_history.json" "$all_status_history"; then
        local history_count
        history_count=$(echo "$all_status_history" | jq '.status_history | length')
        log_info "ステータス変更履歴取得完了: $history_count件"
        log_info "保存先: $DATA_DIR/status_history.json"
        return 0
    else
        log_error "ステータス変更履歴の保存に失敗しました"
        return 1
    fi
}

# 全Work Itemsの詳細情報取得 (バッチ処理最適化)
fetch_all_details() {
    local project="$1"
    
    if [[ -z "$project" ]]; then
        log_error "プロジェクト名が指定されていません"
        return 1
    fi
    
    log_info "全Work Itemsの詳細情報取得を開始"
    
    # Load work items data
    local workitems_data
    workitems_data=$(load_json "workitems.json")
    
    if [[ -z "$workitems_data" ]] || [[ "$workitems_data" == "{}" ]]; then
        log_error "Work Itemsデータが見つかりません。先にfetchコマンドを実行してください"
        return 1
    fi
    
    # Get work item IDs
    local workitem_ids
    workitem_ids=$(echo "$workitems_data" | jq -r '.workitems[].id' 2>/dev/null)
    
    if [[ -z "$workitem_ids" ]]; then
        log_error "Work Item IDsが取得できませんでした"
        return 1
    fi
    
    local total_items
    total_items=$(echo "$workitem_ids" | wc -l)
    log_info "処理対象Work Items: $total_items件"
    
    local all_details='{"workitem_details": []}'
    local processed_count=0
    
    # Process in batches for performance optimization
    local batch_ids=""
    local batch_count=0
    
    while IFS= read -r workitem_id; do
        if [[ -n "$workitem_id" ]]; then
            if [[ -n "$batch_ids" ]]; then
                batch_ids="${batch_ids},${workitem_id}"
            else
                batch_ids="$workitem_id"
            fi
            ((batch_count++))
            
            # Process batch when batch size is reached or at the end
            if [[ $batch_count -ge $BATCH_SIZE ]] || [[ $((processed_count + batch_count)) -eq $total_items ]]; then
                log_info "詳細情報取得 (バッチ: $batch_count件, 進捗: $((processed_count + batch_count))/$total_items)"
                
                # Use batch API endpoint for better performance
                local batch_endpoint="${project}/_apis/wit/workitems?ids=${batch_ids}&\$expand=fields"
                
                local batch_response
                if batch_response=$(call_ado_api "$batch_endpoint"); then
                    # Process each work item in the batch
                    local details_batch
                    details_batch=$(echo "$batch_response" | jq -c '.value[] | 
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
                        }')
                    
                    if [[ -n "$details_batch" ]]; then
                        # Convert dates to JST for each item
                        local jst_details=""
                        while IFS= read -r detail; do
                            if [[ -n "$detail" ]]; then
                                # Convert dates to JST
                                local created_date_utc
                                created_date_utc=$(echo "$detail" | jq -r '.createdDate')
                                local created_date_jst
                                created_date_jst=$(convert_to_jst "$created_date_utc")
                                
                                local modified_date_utc
                                modified_date_utc=$(echo "$detail" | jq -r '.lastModifiedDate')
                                local modified_date_jst
                                modified_date_jst=$(convert_to_jst "$modified_date_utc")
                                
                                # Update with JST dates
                                local jst_detail
                                jst_detail=$(echo "$detail" | jq \
                                    --arg created_jst "$created_date_jst" \
                                    --arg modified_jst "$modified_date_jst" \
                                    '.createdDate = $created_jst | .lastModifiedDate = $modified_jst')
                                
                                if [[ -n "$jst_details" ]]; then
                                    jst_details="${jst_details}
${jst_detail}"
                                else
                                    jst_details="$jst_detail"
                                fi
                            fi
                        done <<< "$details_batch"
                        
                        if [[ -n "$jst_details" ]]; then
                            local batch_array
                            batch_array=$(echo "$jst_details" | jq -s '.')
                            
                            all_details=$(echo "$all_details" | jq --argjson batch "$batch_array" '.workitem_details += $batch')
                            
                            processed_count=$((processed_count + batch_count))
                            log_info "バッチ処理完了: $batch_count件 (累計: $processed_count件)"
                        fi
                    fi
                    
                    # Rate limiting - wait between batch requests
                    sleep 0.5
                else
                    log_error "詳細情報取得に失敗: IDs=$batch_ids"
                    # Continue with next batch instead of failing completely
                    processed_count=$((processed_count + batch_count))
                fi
                
                # Reset batch
                batch_ids=""
                batch_count=0
            fi
        fi
    done <<< "$workitem_ids"
    
    # Save detailed work items data
    if save_json "workitem_details.json" "$all_details"; then
        local details_count
        details_count=$(echo "$all_details" | jq '.workitem_details | length')
        log_info "Work Item詳細情報取得完了: $details_count件"
        log_info "保存先: $DATA_DIR/workitem_details.json"
        return 0
    else
        log_error "Work Item詳細情報の保存に失敗しました"
        return 1
    fi
}

# コマンド実装
cmd_fetch() {
    local project=""
    local days="30"
    local with_details=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-details)
                with_details=true
                shift
                ;;
            -*)
                echo "Error: 不明なオプション: $1" >&2
                exit 1
                ;;
            *)
                if [[ -z "$project" ]]; then
                    project="$1"
                elif [[ -z "$days" || "$days" == "30" ]]; then
                    days="$1"
                else
                    echo "Error: 余分な引数: $1" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # バリデーション
    validate_project_name "$project" || exit 1
    validate_days "$days" || exit 1
    
    # 設定検証
    if ! validate_config; then
        log_error "設定が不正です。config validateコマンドで確認してください"
        exit 2
    fi
    
    # Work Items取得実行
    if fetch_workitems "$project" "$days"; then
        log_info "チケット履歴の取得が完了しました"
        
        # 取得データの概要表示
        local workitems_data
        workitems_data=$(load_json "workitems.json")
        
        if [[ -n "$workitems_data" ]]; then
            local count
            count=$(echo "$workitems_data" | jq '.workitems | length')
            log_info "取得されたWork Items数: $count件"
            
            # 最初の5件を表示（サンプル）
            if [[ "$count" -gt 0 ]]; then
                log_info "取得データのサンプル（最初の5件）:"
                echo "$workitems_data" | jq -r '.workitems[0:5][] | 
                    "  - [\(.id)] \(.title) (\(.state)) - \(.assignedTo)"'
                
                # Automatically fetch status history after work items
                log_info ""
                log_info "ステータス変更履歴の取得を開始します..."
                if fetch_all_status_history "$project"; then
                    # Optionally fetch work item details if requested
                    if [[ "$with_details" == true ]]; then
                        log_info ""
                        log_info "Work Item詳細情報の取得を開始します..."
                        if fetch_all_details "$project"; then
                            log_info "全データ（詳細情報含む）の取得が完了しました"
                        else
                            log_warn "Work Item詳細情報の取得に失敗しましたが、基本データとステータス履歴の取得は成功しました"
                        fi
                    else
                        log_info "全データの取得が完了しました"
                        log_info "詳細情報が必要な場合は --with-details オプションまたは fetch-details コマンドを使用してください"
                    fi
                else
                    log_warn "ステータス変更履歴の取得に失敗しましたが、Work Itemsの取得は成功しました"
                fi
            fi
        fi
    else
        log_error "チケット履歴の取得に失敗しました"
        exit 1
    fi
}

# Status history command
cmd_status_history() {
    local project="${1:-}"
    
    # バリデーション
    if [[ -z "$project" ]]; then
        log_error "プロジェクト名を指定してください"
        exit 1
    fi
    
    validate_project_name "$project" || exit 1
    
    # 設定検証
    if ! validate_config; then
        log_error "設定が不正です。config validateコマンドで確認してください"
        exit 2
    fi
    
    # Status history取得実行
    if fetch_all_status_history "$project"; then
        log_info "ステータス変更履歴の取得が完了しました"
        
        # 取得データの概要表示
        local status_data
        status_data=$(load_json "status_history.json")
        
        if [[ -n "$status_data" ]]; then
            local count
            count=$(echo "$status_data" | jq '.status_history | length')
            log_info "取得されたステータス変更履歴数: $count件"
            
            # 最初の5件を表示（サンプル）
            if [[ "$count" -gt 0 ]]; then
                log_info "取得データのサンプル（最初の5件）:"
                echo "$status_data" | jq -r '.status_history[0:5][] | 
                    "  - Work Item \(.workitemId): \(.previousStatus) → \(.newStatus) (\(.changeDate)) by \(.changedBy)"'
            fi
        fi
    else
        log_error "ステータス変更履歴の取得に失敗しました"
        exit 1
    fi
}

# US-001-BE-004: Work Item details command
cmd_fetch_details() {
    local project="${1:-}"
    
    # バリデーション
    if [[ -z "$project" ]]; then
        log_error "プロジェクト名を指定してください"
        exit 1
    fi
    
    validate_project_name "$project" || exit 1
    
    # 設定検証
    if ! validate_config; then
        log_error "設定が不正です。config validateコマンドで確認してください"
        exit 2
    fi
    
    # Work Item details取得実行
    if fetch_all_details "$project"; then
        log_info "Work Item詳細情報の取得が完了しました"
        
        # 取得データの概要表示
        local details_data
        details_data=$(load_json "workitem_details.json")
        
        if [[ -n "$details_data" ]]; then
            local count
            count=$(echo "$details_data" | jq '.workitem_details | length')
            log_info "取得されたWork Item詳細情報数: $count件"
            
            # 最初の3件を表示（サンプル）
            if [[ "$count" -gt 0 ]]; then
                log_info "取得データのサンプル（最初の3件）:"
                echo "$details_data" | jq -r '.workitem_details[0:3][] | 
                    "  - [\(.id)] \(.title) (\(.type))"
                    + if .priority then " - 優先度: \(.priority)" else "" end
                    + if .originalEstimate then " - 見積: \(.originalEstimate)h" else "" end
                    + " - 作成: \(.createdDate) - 担当: \(.assignedTo)"'
            fi
        fi
    else
        log_error "Work Item詳細情報の取得に失敗しました"
        exit 1
    fi
}