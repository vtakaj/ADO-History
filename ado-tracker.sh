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
WORK_TABLE_ASSIGNEES="${WORK_TABLE_ASSIGNEES:-}"

# 出力制御設定
OUTPUT_FORMAT="${OUTPUT_FORMAT:-table}"  # table|list|summary
PAGER="${PAGER:-less -R}"               # ページャー設定
NO_COLOR="${NO_COLOR:-0}"               # カラー無効化

# モジュール読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Core modules
source "$SCRIPT_DIR/lib/core/logger.sh"
source "$SCRIPT_DIR/lib/core/config_manager.sh"
source "$SCRIPT_DIR/lib/core/api_client.sh"
source "$SCRIPT_DIR/lib/core/data_processor.sh"

# Command modules
source "$SCRIPT_DIR/lib/commands/fetch.sh"
source "$SCRIPT_DIR/lib/commands/test_connection.sh"
source "$SCRIPT_DIR/lib/commands/generate_table.sh"

# Formatter modules
source "$SCRIPT_DIR/lib/formatters/markdown.sh"
source "$SCRIPT_DIR/lib/formatters/display.sh"

# Utility modules
source "$SCRIPT_DIR/lib/utils/date_utils.sh"
source "$SCRIPT_DIR/lib/utils/string_utils.sh"
source "$SCRIPT_DIR/lib/utils/file_utils.sh"
source "$SCRIPT_DIR/lib/utils/validation.sh"

# メイン処理
main() {
    # カラー設定初期化
    setup_colors
    
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
        generate-work-table)
            cmd_generate_work_table "${@:2}"
            ;;
        test-connection)
            cmd_test_connection "${@:2}"
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
