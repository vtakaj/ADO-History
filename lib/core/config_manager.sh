#!/bin/bash
# Configuration management functions

# .env ファイル読み込み
load_env_file() {
    local env_file=".env"
    
    if [[ -f "$env_file" ]]; then
        # セキュリティ: .envファイルの権限確認
        local perms=$(stat -c %a "$env_file" 2>/dev/null || stat -f %A "$env_file" 2>/dev/null)
        if [[ "$perms" != "600" ]]; then
            log_warn ".envファイルの権限が安全ではありません: $perms (推奨: 600)"
        fi
        
        # .env をそのまま読み込み（コメント/空行は source で問題ない）
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
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
    
    # デフォルトプロジェクト検証
    if [[ -z "$AZURE_DEVOPS_PROJECT" ]]; then
        log_error "AZURE_DEVOPS_PROJECT が設定されていません。.env にデフォルトプロジェクトを設定してください"
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
作業記録対象者: ${WORK_TABLE_ASSIGNEES:-"(未設定)"}
PAT設定: $(if [[ -n "$AZURE_DEVOPS_PAT" ]]; then echo "設定済み"; else echo "未設定"; fi)
EOF
}

# .env テンプレート生成
generate_env_template() {
    cat > .env.template << 'EOF'
# Azure DevOps 接続設定
AZURE_DEVOPS_PAT=your_personal_access_token_here
AZURE_DEVOPS_ORG=your_organization_name
# fetch コマンドで使用するデフォルトプロジェクト名
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

# 作業記録テーブル対象者（カンマ区切り）
WORK_TABLE_ASSIGNEES=
EOF
    
    chmod 600 .env.template
    log_info ".env.template を生成しました"
    log_info ".env.template を .env にコピーして設定値を入力してください"
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
