#!/bin/bash
set -euo pipefail

# グローバル変数
SCRIPT_NAME="$(basename "$0")"
VERSION="1.0.0"

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

# ログ機能
log_error() {
    echo "[ERROR] $*" >&2
}

log_warn() {
    if [[ "$LOG_LEVEL" != "ERROR" ]]; then
        echo "[WARN] $*" >&2
    fi
}

log_info() {
    if [[ "$LOG_LEVEL" == "INFO" ]]; then
        echo "[INFO] $*"
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
  fetch <project> [days]     チケット履歴を取得
  test-connection            API接続テストを実行
  test-connection --mock     モック環境でAPI機能をテスト
  config [show|validate|template] 設定管理
  help                       このヘルプを表示

Options:
  -h, --help                 ヘルプを表示
  -v, --version              バージョンを表示

Examples:
  $SCRIPT_NAME fetch MyProject 30
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

# Azure DevOps API 呼び出し
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
    
    # Base64エンコード用のPAT（空のユーザー名とPATの組み合わせ）
    local auth_header="Authorization: Basic $(echo -n ":${AZURE_DEVOPS_PAT}" | base64 -w 0)"
    
    # API URL構築
    local api_url="https://dev.azure.com/${AZURE_DEVOPS_ORG}/${endpoint}?api-version=${API_VERSION}"
    
    log_info "API呼び出し: $method $api_url"
    
    # curlオプション設定
    local curl_opts=(
        -s
        -w "%{http_code}"
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
    
    # リトライ処理
    local attempt=1
    local http_code
    
    while [[ $attempt -le $RETRY_COUNT ]]; do
        log_info "試行 $attempt/$RETRY_COUNT"
        
        # API呼び出し実行
        http_code=$(curl "${curl_opts[@]}" -o "$response_file" "$api_url" 2>/dev/null || echo "000")
        
        # HTTPステータスコード確認
        case "$http_code" in
            200|201|204)
                # 成功
                if [[ -s "$response_file" ]]; then
                    cat "$response_file"
                fi
                rm -f "$response_file"
                return 0
                ;;
            401)
                log_error "認証エラー: PATが無効または期限切れです (HTTP $http_code)"
                rm -f "$response_file"
                return 1
                ;;
            403)
                log_error "アクセス拒否: 権限が不足しています (HTTP $http_code)"
                rm -f "$response_file"
                return 1
                ;;
            404)
                log_error "リソースが見つかりません: $api_url (HTTP $http_code)"
                rm -f "$response_file"
                return 1
                ;;
            429)
                log_warn "レート制限に達しました。${RETRY_DELAY}秒後にリトライします (HTTP $http_code)"
                ;;
            500|502|503|504)
                log_warn "サーバーエラーが発生しました。${RETRY_DELAY}秒後にリトライします (HTTP $http_code)"
                ;;
            000)
                log_warn "ネットワークエラーまたはタイムアウトです。${RETRY_DELAY}秒後にリトライします"
                ;;
            *)
                log_warn "予期しないHTTPステータスコード: $http_code。${RETRY_DELAY}秒後にリトライします"
                ;;
        esac
        
        # 最後の試行でない場合はリトライ
        if [[ $attempt -lt $RETRY_COUNT ]]; then
            sleep "$RETRY_DELAY"
            ((attempt++))
        else
            log_error "API呼び出しが失敗しました (HTTP $http_code)"
            if [[ -s "$response_file" ]]; then
                log_error "レスポンス: $(cat "$response_file")"
            fi
            rm -f "$response_file"
            return 1
        fi
    done
    
    rm -f "$response_file"
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

# コマンド実装（後で実装される）
cmd_fetch() {
    local project="${1:-}"
    local days="${2:-30}"
    
    # バリデーション
    validate_project_name "$project" || exit 1
    validate_days "$days" || exit 1
    
    echo "fetch コマンドの実装予定地"
    echo "プロジェクト: $project"
    echo "日数: $days"
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