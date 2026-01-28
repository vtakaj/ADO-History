#!/bin/bash
# API Client functions for Azure DevOps REST API

# Azure DevOps API 呼び出し（Enhanced with US-001-BE-005 features）
call_ado_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    if [[ -z "$endpoint" ]]; then
        log_error "API エンドポイントが指定されていません"
        return 1
    fi
    
    # PAT検証
    if [[ -z "$AZURE_DEVOPS_PAT" ]]; then
        log_error "AZURE_DEVOPS_PAT が設定されていません"
        return 1
    fi
    
    # 組織名検証
    if [[ -z "$AZURE_DEVOPS_ORG" ]]; then
        log_error "AZURE_DEVOPS_ORG が設定されていません"
        return 1
    fi
    
    # API URL構築
    local api_url="https://dev.azure.com/${AZURE_DEVOPS_ORG}/${endpoint}"
    
    # api-versionパラメータの追加（既存パラメータがある場合は&で結合）
    if [[ "$endpoint" == *"?"* ]]; then
        api_url="${api_url}&api-version=${API_VERSION}"
    else
        api_url="${api_url}?api-version=${API_VERSION}"
    fi
    
    # ログ出力を標準エラーに送る（レスポンスの汚染防止）
    {
        log_info "API呼び出し: $method $api_url"
    } >&2
    
    # Base64エンコード用のPAT（空のユーザー名とPATの組み合わせ）
    local auth_header="Authorization: Basic $(echo -n ":${AZURE_DEVOPS_PAT}" | base64 -w 0)"

    # curlオプション設定（Enhanced with header capture for Retry-After）
    local curl_opts=(
        -s
        -H "Content-Type: application/json"
        -H "$auth_header"
        -H "Accept: application/json"
        --connect-timeout "$REQUEST_TIMEOUT"
        --max-time "$((REQUEST_TIMEOUT * 2))"
    )
    
    # HTTPメソッドに応じたオプション追加
    case "$method" in
        POST|PUT|PATCH)
            if [[ -n "$data" ]]; then
                curl_opts+=(-d "$data")
            fi
            curl_opts+=(-X "$method")
            ;;
        GET)
            ;;
        *)
            log_error "サポートされていないHTTPメソッド: $method"
            return 1
            ;;
    esac
    
    # レスポンス一時ファイル
    local headers_file
    headers_file=$(mktemp)
    local response_file
    response_file=$(mktemp)
    curl_opts+=(-D "$headers_file")
    
    # リトライ処理（指数バックオフ）
    local attempt=1
    local delay="$RETRY_DELAY"
    local http_code
    
    while [[ $attempt -le $RETRY_COUNT ]]; do
        {
            log_info "試行 $attempt/$RETRY_COUNT (待機時間: ${delay}秒)"
        } >&2
        
        # API呼び出し実行
        local curl_output
        curl_output=$(curl "${curl_opts[@]}" -o "$response_file" -w "%{http_code}" "$api_url" 2>/dev/null)
        http_code="$curl_output"
        
        # Extract headers and body
        local headers=""
        if [[ -s "$headers_file" ]]; then
            headers=$(cat "$headers_file")
        fi
        
        # HTTPステータスコード確認（Enhanced with US-001-BE-005 error handling）
        case "$http_code" in
            200|201|204)
                # 成功
                if [[ -s "$response_file" ]]; then
                    {
                        log_info "✓ API呼び出し成功 (HTTP $http_code) - レスポンスサイズ: $(wc -c < "$response_file") bytes"
                    } >&2
                    cat "$response_file"
                else
                    {
                        log_warn "API呼び出し成功だがレスポンスが空 (HTTP $http_code)"
                    } >&2
                fi
                rm -f "$response_file" "$headers_file"
                return 0
                ;;
            401|403|404)
                # Non-retryable errors
                handle_api_error "$http_code" "$(cat "$response_file" 2>/dev/null)" "$endpoint"
                rm -f "$response_file" "$headers_file"
                return 1
                ;;
            429)
                # Rate limiting - extract Retry-After if available
                local retry_after
                if retry_after=$(echo "$headers" | grep -i "retry-after:" | head -1 | cut -d: -f2 | tr -d ' \r\n'); then
                    if [[ "$retry_after" =~ ^[0-9]+$ ]]; then
                        delay="$retry_after"
                        log_warn "レート制限: Retry-Afterヘッダーにより ${delay}秒 待機します (HTTP $http_code)"
                    else
                        delay=$((delay * 2))
                        log_warn "レート制限: 指数バックオフにより ${delay}秒 待機します (HTTP $http_code)"
                    fi
                else
                    delay=$((delay * 2))
                    log_warn "レート制限: 指数バックオフにより ${delay}秒 待機します (HTTP $http_code)"
                fi
                ;;
            500|502|503|504|000)
                # Retryable errors
                handle_api_error "$http_code" "$(cat "$response_file" 2>/dev/null)" "$endpoint"
                delay=$((delay * 2))  # Exponential backoff
                ;;
            *)
                # Unknown errors
                handle_api_error "$http_code" "$(cat "$response_file" 2>/dev/null)" "$endpoint"
                delay=$((delay * 2))  # Exponential backoff
                ;;
        esac
        
        # 最後の試行でない場合はリトライ（Enhanced with exponential backoff）
        if [[ $attempt -lt $RETRY_COUNT ]]; then
            # Cap the delay at maximum
            if [[ $delay -gt $MAX_EXPONENTIAL_BACKOFF ]]; then
                delay=$MAX_EXPONENTIAL_BACKOFF
            fi
            
            log_warn "${delay}秒後にリトライします..."
            sleep "$delay"
            ((attempt++))
        else
            log_error "API呼び出しが失敗しました (HTTP $http_code) - 最大リトライ回数に到達"
            if [[ -s "$response_file" ]]; then
                log_error "最終レスポンス: $(cat "$response_file")"
            fi
            rm -f "$response_file" "$headers_file"
            return 1
        fi
    done
    
    rm -f "$response_file" "$headers_file"
    return 1
}

# API接続テスト（モック版）
test_api_connection_mock() {
    log_info "Azure DevOps API接続テスト（モック環境）を開始します"
    
    # 設定値検証
    if ! validate_config; then
        log_error "設定値が不正です"
        return 1
    fi
    
    log_info "組織: $AZURE_DEVOPS_ORG"
    log_info "PAT: $(mask_pat "$AZURE_DEVOPS_PAT")"
    log_info "APIバージョン: $API_VERSION"
    
    log_info "モック環境でAPI機能をテストします..."
    
    # モックレスポンスの生成
    local mock_response='{"count":3,"value":[{"id":"project1-id","name":"ProjectAlpha","description":"Main development project"},{"id":"project2-id","name":"ProjectBeta","description":"Testing project"},{"id":"project3-id","name":"ProjectGamma","description":"Research project"}]}'
    
    log_info "✓ API接続テスト成功（モック）"
    log_info "✓ 認証確認完了（モック）"
    log_info "✓ 利用可能なプロジェクト数: 3"
    
    # プロジェクト一覧表示
    if command -v jq >/dev/null 2>&1; then
        echo "$mock_response" | jq -r '.value[] | "  - \(.name) (ID: \(.id))"'
    else
        echo "  - ProjectAlpha (ID: project1-id)"
        echo "  - ProjectBeta (ID: project2-id)" 
        echo "  - ProjectGamma (ID: project3-id)"
    fi
    
    log_info ""
    log_info "注意: これはモック環境でのテストです"
    log_info "実際のAzure DevOps APIに接続するには --mock オプションを外してください"
    
    return 0
}

# API接続テスト
test_api_connection() {
    log_info "Azure DevOps API接続テストを開始します"
    
    # 設定値検証
    if ! validate_config; then
        log_error "設定値が不正です"
        return 1
    fi
    
    log_info "組織: $AZURE_DEVOPS_ORG"
    log_info "PAT: $(mask_pat "$AZURE_DEVOPS_PAT")"
    log_info "APIバージョン: $API_VERSION"
    
    # プロジェクト一覧取得で接続テスト
    local projects_endpoint="_apis/projects"
    
    log_info "プロジェクト一覧を取得して接続をテストします..."
    
    local response
    if response=$(call_ado_api "$projects_endpoint"); then
        # JSONレスポンスの簡易検証
        if echo "$response" | grep -q '"value"' && echo "$response" | grep -q '"count"'; then
            local project_count
            project_count=$(echo "$response" | grep -o '"count":[0-9]*' | cut -d: -f2)
            
            log_info "✓ API接続テスト成功"
            log_info "✓ 認証確認完了"
            log_info "✓ 利用可能なプロジェクト数: $project_count"
            
            # プロジェクト一覧表示（デバッグ用）
            if [[ "$LOG_LEVEL" == "INFO" ]] && command -v jq >/dev/null 2>&1; then
                echo "$response" | jq -r '.value[] | "  - \(.name) (ID: \(.id))"' 2>/dev/null || true
            fi
            
            return 0
        else
            log_error "レスポンス形式が期待される形式と異なります"
            log_error "レスポンス: $response"
            return 1
        fi
    else
        log_error "API接続テストに失敗しました"
        return 1
    fi
}

# Get work item updates (US-001-BE-003)
get_workitem_updates() {
    local workitem_id="$1"
    local project="$2"
    
    if [[ -z "$workitem_id" ]]; then
        log_error "Work Item IDが指定されていません"
        return 1
    fi
    
    if [[ -z "$project" ]]; then
        log_error "プロジェクト名が指定されていません"
        return 1
    fi
    
    local updates_endpoint="${project}/_apis/wit/workitems/${workitem_id}/updates"
    
    {
        log_info "Work Item $workitem_id の更新履歴を取得中"
    } >&2
    
    local updates_response
    if updates_response=$(call_ado_api "$updates_endpoint"); then
        echo "$updates_response"
        return 0
    else
        log_error "Work Item $workitem_id の更新履歴取得に失敗"
        return 1
    fi
}

# US-001-BE-004: Work Item詳細情報取得
get_workitem_details() {
    local workitem_id="$1"
    local project="$2"
    
    if [[ -z "$workitem_id" ]]; then
        log_error "Work Item IDが指定されていません"
        return 1
    fi
    
    if [[ -z "$project" ]]; then
        log_error "プロジェクト名が指定されていません"
        return 1
    fi
    
    # Work Item Details API endpoint with field expansion
    local details_endpoint="${project}/_apis/wit/workitems/${workitem_id}?\$expand=fields"
    
    {
        log_info "Work Item $workitem_id の詳細情報を取得中"
    } >&2
    
    local details_response
    if details_response=$(call_ado_api "$details_endpoint"); then
        echo "$details_response"
        return 0
    else
        log_error "Work Item $workitem_id の詳細情報取得に失敗"
        return 1
    fi
}
