#!/bin/bash
set -euo pipefail

# グローバル変数
SCRIPT_NAME="$(basename "$0")"
VERSION="1.0.0"

# データ管理用ディレクトリとファイル
DATA_DIR="./data"
BACKUP_DIR="./data/backup"

# US-001-BE-005: Checkpoint/Recovery support
CHECKPOINT_FILE="$DATA_DIR/checkpoint.json"
MAX_EXPONENTIAL_BACKOFF=300  # Maximum backoff delay in seconds

# 環境変数デフォルト値
AZURE_DEVOPS_PAT="${AZURE_DEVOPS_PAT:-}"
AZURE_DEVOPS_ORG="${AZURE_DEVOPS_ORG:-}"
AZURE_DEVOPS_PROJECT="${AZURE_DEVOPS_PROJECT:-}"
API_VERSION="${API_VERSION:-7.2}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
RETRY_COUNT="${RETRY_COUNT:-3}"
RETRY_DELAY="${RETRY_DELAY:-1}"
REQUEST_TIMEOUT="${REQUEST_TIMEOUT:-30}"
BATCH_SIZE="${BATCH_SIZE:-50}"

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

# .env ファイル読み込み
load_env_file() {
    local env_file=".env"
    
    if [[ -f "$env_file" ]]; then
        # セキュリティ: .envファイルの権限確認
        local perms=$(stat -c %a "$env_file" 2>/dev/null || stat -f %A "$env_file" 2>/dev/null)
        if [[ "$perms" != "600" ]]; then
            log_warn ".envファイルの権限が安全ではありません: $perms (推奨: 600)"
        fi
        
        # コメント行と空行を除外して読み込み
        set -a
        source <(grep -v '^#' "$env_file" | grep -v '^$')
        set +a
        
        log_info ".envファイルを読み込み: $env_file"
    fi
}

# 設定値検証
validate_config() {
    local errors=0
    
    # PAT 検証
    if [[ -z "$AZURE_DEVOPS_PAT" ]]; then
        log_error "AZURE_DEVOPS_PAT が設定されていません"
        ((errors++))
    elif [[ ${#AZURE_DEVOPS_PAT} -lt 52 ]]; then
        log_error "AZURE_DEVOPS_PAT の形式が正しくありません（長さ不足）"
        ((errors++))
    fi
    
    # 組織名検証
    if [[ -z "$AZURE_DEVOPS_ORG" ]]; then
        log_error "AZURE_DEVOPS_ORG が設定されていません"
        ((errors++))
    elif [[ ! "$AZURE_DEVOPS_ORG" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]]; then
        log_error "AZURE_DEVOPS_ORG の形式が正しくありません"
        ((errors++))
    fi
    
    # APIバージョン検証
    if [[ ! "$API_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        log_error "API_VERSION の形式が正しくありません: $API_VERSION"
        ((errors++))
    fi
    
    # リトライ設定検証
    if [[ ! "$RETRY_COUNT" =~ ^[0-9]+$ ]] || [[ "$RETRY_COUNT" -lt 0 ]] || [[ "$RETRY_COUNT" -gt 10 ]]; then
        log_error "RETRY_COUNT は0-10の範囲で設定してください: $RETRY_COUNT"
        ((errors++))
    fi
    
    return $errors
}

# PAT のマスク表示
mask_pat() {
    local pat="$1"
    if [[ -n "$pat" && ${#pat} -gt 8 ]]; then
        echo "${pat:0:4}****${pat: -4}"
    else
        echo "****"
    fi
}

# 設定情報表示（PAT除く）
show_config() {
    cat << EOF
=== Azure DevOps Tracker 設定情報 ===
組織名: ${AZURE_DEVOPS_ORG:-"(未設定)"}
デフォルトプロジェクト: ${AZURE_DEVOPS_PROJECT:-"(未設定)"}
APIバージョン: $API_VERSION
ログレベル: $LOG_LEVEL
リトライ回数: $RETRY_COUNT
リトライ間隔: ${RETRY_DELAY}秒
リクエストタイムアウト: ${REQUEST_TIMEOUT}秒
バッチサイズ: $BATCH_SIZE
PAT設定: $(if [[ -n "$AZURE_DEVOPS_PAT" ]]; then echo "設定済み"; else echo "未設定"; fi)
EOF
}

# .env テンプレート生成
generate_env_template() {
    cat > .env.template << 'EOF'
# Azure DevOps 接続設定
AZURE_DEVOPS_PAT=your_personal_access_token_here
AZURE_DEVOPS_ORG=your_organization_name
AZURE_DEVOPS_PROJECT=your_default_project_name

# API設定
API_VERSION=7.2
LOG_LEVEL=INFO

# リトライ設定
RETRY_COUNT=3
RETRY_DELAY=1
REQUEST_TIMEOUT=30

# バッチ処理設定
BATCH_SIZE=50
EOF
    
    chmod 600 .env.template
    log_info ".env.template を生成しました"
    log_info ".env.template を .env にコピーして設定値を入力してください"
}

# 使用方法表示
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [options]

Commands:
  fetch <project> [days] [--with-details]  チケット履歴とステータス変更履歴を取得
  status-history <project>                 ステータス変更履歴のみを取得
  fetch-details <project>                  Work Item詳細情報のみを取得
  test-connection                          API接続テストを実行
  test-connection --mock                   モック環境でAPI機能をテスト
  config [show|validate|template]          設定管理
  help                                     このヘルプを表示

Options:
  -h, --help                 ヘルプを表示
  -v, --version              バージョンを表示
  --with-details             fetch時に詳細情報も同時取得（オプション）

Examples:
  $SCRIPT_NAME fetch MyProject 30                    # 基本情報とステータス履歴のみ
  $SCRIPT_NAME fetch MyProject 30 --with-details     # 詳細情報も含めて取得
  $SCRIPT_NAME status-history MyProject
  $SCRIPT_NAME fetch-details MyProject               # 詳細情報のみ取得
  $SCRIPT_NAME test-connection
  $SCRIPT_NAME config show
  $SCRIPT_NAME config validate
  $SCRIPT_NAME config template
  $SCRIPT_NAME help
EOF
}

# 引数バリデーション
validate_project_name() {
    local project="$1"
    
    if [[ -z "$project" ]]; then
        echo "Error: プロジェクト名を指定してください" >&2
        return 1
    fi
    
    if [[ ! "$project" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: プロジェクト名に無効な文字が含まれています" >&2
        return 1
    fi
}

# 数値バリデーション
validate_days() {
    local days="$1"
    
    if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ "$days" -lt 1 ]] || [[ "$days" -gt 365 ]]; then
        echo "Error: 日数は1-365の範囲で指定してください" >&2
        return 1
    fi
}

# 設定確認コマンド
cmd_config() {
    case "${1:-show}" in
        show)
            show_config
            ;;
        validate)
            if validate_config; then
                echo "設定は正常です"
            else
                echo "設定にエラーがあります" >&2
                exit 2
            fi
            ;;
        template)
            generate_env_template
            ;;
        *)
            echo "Usage: $SCRIPT_NAME config [show|validate|template]" >&2
            exit 1
            ;;
    esac
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
        -D -    # Include response headers for Retry-After parsing
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
    local response_file
    response_file=$(mktemp)
    local headers_file
    headers_file=$(mktemp)
    
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
        http_code=$(echo "$curl_output" | tail -1)
        
        # Extract headers and body
        local headers
        headers=$(echo "$curl_output" | head -n -1)
        
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

# データディレクトリ初期化
init_data_directories() {
    mkdir -p "$DATA_DIR" "$BACKUP_DIR"
    chmod 700 "$DATA_DIR" "$BACKUP_DIR"
    
    log_info "データディレクトリを初期化: $DATA_DIR"
}

# JSONファイル保存
save_json() {
    local filename="$1"
    local data="$2"
    local filepath="$DATA_DIR/$filename"
    
    # データディレクトリが存在しない場合は初期化
    if [[ ! -d "$DATA_DIR" ]]; then
        init_data_directories
    fi
    
    # バックアップ作成
    if [[ -f "$filepath" ]]; then
        cp "$filepath" "$BACKUP_DIR/${filename}.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # JSON形式検証
    if echo "$data" | jq empty 2>/dev/null; then
        echo "$data" | jq '.' > "$filepath"
        chmod 600 "$filepath"
        log_info "JSONファイル保存: $filepath"
    else
        log_error "無効なJSON形式: $filename"
        return 1
    fi
}

# JSONファイル読み込み
load_json() {
    local filename="$1"
    local filepath="$DATA_DIR/$filename"
    
    if [[ -f "$filepath" ]]; then
        if jq empty "$filepath" 2>/dev/null; then
            cat "$filepath"
        else
            log_error "破損したJSONファイル: $filepath"
            return 1
        fi
    else
        echo "{}"
    fi
}

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

# UTC to JST conversion
convert_to_jst() {
    local utc_time="$1"
    
    if [[ -z "$utc_time" ]]; then
        echo ""
        return
    fi
    
    # Remove timezone info if present
    local clean_time
    clean_time=$(echo "$utc_time" | sed 's/\.[0-9]*Z$//' | sed 's/Z$//')
    
    # Convert to JST (add 9 hours) - try different methods based on OS
    local jst_time=""
    
    # Method 1: GNU date (Linux) - using TZ environment variable
    if jst_time=$(TZ=Asia/Tokyo date -d "$clean_time UTC" '+%Y-%m-%dT%H:%M:%S+09:00' 2>/dev/null); then
        echo "$jst_time"
        return 0
    fi
    
    # Method 2: BSD date (macOS)
    if jst_time=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_time" -v+9H '+%Y-%m-%dT%H:%M:%S+09:00' 2>/dev/null); then
        echo "$jst_time"
        return 0
    fi
    
    # Method 3: Parse manually and add 9 hours
    if [[ "$clean_time" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]]; then
        local year="${BASH_REMATCH[1]}"
        local month="${BASH_REMATCH[2]}"
        local day="${BASH_REMATCH[3]}"
        local hour="${BASH_REMATCH[4]}"
        local minute="${BASH_REMATCH[5]}"
        local second="${BASH_REMATCH[6]}"
        
        # Convert to seconds since epoch and add 9 hours (32400 seconds)
        local epoch_utc
        if epoch_utc=$(date -d "$year-$month-$day $hour:$minute:$second UTC" +%s 2>/dev/null); then
            local epoch_jst=$((epoch_utc + 32400))
            local jst_formatted
            if jst_formatted=$(date -d "@$epoch_jst" '+%Y-%m-%dT%H:%M:%S+09:00' 2>/dev/null); then
                echo "$jst_formatted"
                return 0
            fi
        fi
    fi
    
    # Fallback: return original with JST timezone
    echo "${clean_time}+09:00"
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
    
    # Extract status changes only
    echo "$updates_json" | jq -c --arg workitem_id "$workitem_id" '
        .value[] | 
        select(.fields and (.fields["System.State"] or .fields["System.Status"])) |
        {
            workitemId: ($workitem_id | tonumber),
            changeDate: .revisedDate,
            changedBy: (.revisedBy.displayName // .revisedBy.uniqueName // "Unknown"),
            previousStatus: (.fields["System.State"].oldValue // .fields["System.Status"].oldValue // null),
            newStatus: (.fields["System.State"].newValue // .fields["System.Status"].newValue // ""),
            revision: .rev
        } |
        # Only include actual status changes (exclude initial creation)
        select(.previousStatus != null and .previousStatus != .newStatus)
    ' 2>/dev/null || echo ""
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

# メイン処理
main() {
    # .env ファイル読み込み
    load_env_file
    
    local command="${1:-}"
    
    case "$command" in
        fetch)
            cmd_fetch "${@:2}"
            ;;
        status-history)
            cmd_status_history "${@:2}"
            ;;
        fetch-details)
            cmd_fetch_details "${@:2}"
            ;;
        test-connection)
            if [[ "${2:-}" == "--mock" ]]; then
                test_api_connection_mock
            else
                test_api_connection
            fi
            ;;
        config)
            cmd_config "${@:2}"
            ;;
        help|--help|-h)
            show_usage
            ;;
        --version|-v)
            echo "$SCRIPT_NAME v$VERSION"
            ;;
        "")
            echo "Error: コマンドを指定してください" >&2
            show_usage >&2
            exit 1
            ;;
        *)
            echo "Error: 不明なコマンド: $command" >&2
            show_usage >&2
            exit 1
            ;;
    esac
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi