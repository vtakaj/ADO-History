#!/bin/bash
# Logging functions

# ログ機能（US-001-BE-005: Enhanced logging with timestamps）
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >&2
}

log_error() {
    log_message "ERROR" "$*"
}

log_warn() {
    if [[ "$LOG_LEVEL" != "ERROR" ]]; then
        log_message "WARN" "$*"
    fi
}

log_info() {
    if [[ "$LOG_LEVEL" == "INFO" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [INFO] $*"
    fi
}

# US-001-BE-005: Enhanced API error handling and retry mechanism
handle_api_error() {
    local http_code="$1"
    local response="$2"
    local endpoint="$3"
    
    case "$http_code" in
        401)
            log_error "認証エラー: PATを確認してください"
            log_error "対処法: 1) PATの有効期限を確認 2) アクセス権限を確認 3) 組織名を確認"
            ;;
        403)
            log_error "権限エラー: プロジェクトへのアクセス権限がありません"
            log_error "対処法: 1) PATに必要な権限が付与されているか確認 2) プロジェクトメンバーに追加されているか確認"
            ;;
        404)
            log_error "リソースが見つかりません: $endpoint"
            log_error "対処法: 1) プロジェクト名を確認 2) 組織名を確認 3) Work Item IDの存在を確認"
            ;;
        429)
            # Extract Retry-After header if available
            local retry_after
            if [[ -n "$response" ]] && retry_after=$(echo "$response" | grep -i "retry-after" | head -1 | cut -d: -f2 | tr -d ' '); then
                log_warn "レート制限: ${retry_after}秒後にリトライします (HTTP $http_code)"
                return "$retry_after"
            else
                log_warn "レート制限: デフォルト待機時間でリトライします (HTTP $http_code)"
                return 60
            fi
            ;;
        500|502|503|504)
            log_warn "サーバーエラー: しばらく待ってからリトライしてください (HTTP $http_code)"
            log_warn "対処法: 1) Azure DevOpsサービスステータスを確認 2) 時間をおいて再実行"
            ;;
        000)
            log_warn "ネットワークエラーまたはタイムアウト"
            log_warn "対処法: 1) インターネット接続を確認 2) プロキシ設定を確認 3) タイムアウト値を調整"
            ;;
        *)
            log_warn "予期しないHTTPステータスコード: $http_code"
            if [[ -n "$response" ]]; then
                log_warn "レスポンス内容（最初の200文字）: $(echo "$response" | head -c 200)"
            fi
            ;;
    esac
    
    return 1
}

# US-001-BE-005: Exponential backoff retry mechanism
retry_with_backoff() {
    local command="$1"
    local max_retries="${2:-$RETRY_COUNT}"
    local initial_delay="${3:-$RETRY_DELAY}"
    local endpoint="${4:-unknown}"
    
    local attempt=1
    local delay="$initial_delay"
    
    while [[ $attempt -le $max_retries ]]; do
        log_info "試行 $attempt/$max_retries (次回待機時間: ${delay}秒)"
        
        if eval "$command"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_retries ]]; then
            log_warn "リトライまで ${delay}秒 待機します..."
            sleep "$delay"
            
            # Exponential backoff: double the delay up to maximum
            delay=$((delay * 2))
            if [[ $delay -gt $MAX_EXPONENTIAL_BACKOFF ]]; then
                delay=$MAX_EXPONENTIAL_BACKOFF
            fi
            
            ((attempt++))
        else
            log_error "最大リトライ回数($max_retries)に達しました: $endpoint"
            return 1
        fi
    done
    
    return 1
}

# US-001-BE-005: Checkpoint mechanism for interruption recovery
save_checkpoint() {
    local checkpoint_data="$1"
    local operation_type="$2"
    
    # Ensure data directory exists
    mkdir -p "$(dirname "$CHECKPOINT_FILE")"
    
    local checkpoint_json
    checkpoint_json=$(jq -n \
        --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --arg operation "$operation_type" \
        --argjson data "$checkpoint_data" \
        '{
            timestamp: $timestamp,
            operation: $operation,
            data: $data
        }')
    
    echo "$checkpoint_json" > "$CHECKPOINT_FILE"
    log_info "チェックポイント保存: $CHECKPOINT_FILE (操作: $operation_type)"
}

# US-001-BE-005: Load checkpoint for recovery
load_checkpoint() {
    if [[ -f "$CHECKPOINT_FILE" ]]; then
        if jq empty "$CHECKPOINT_FILE" 2>/dev/null; then
            log_info "チェックポイントから復旧: $CHECKPOINT_FILE"
            cat "$CHECKPOINT_FILE"
            return 0
        else
            log_warn "破損したチェックポイントファイルを削除: $CHECKPOINT_FILE"
            rm -f "$CHECKPOINT_FILE"
        fi
    fi
    
    return 1
}

# US-001-BE-005: Clear checkpoint after successful completion
clear_checkpoint() {
    if [[ -f "$CHECKPOINT_FILE" ]]; then
        rm -f "$CHECKPOINT_FILE"
        log_info "チェックポイント削除: 処理完了"
    fi
}