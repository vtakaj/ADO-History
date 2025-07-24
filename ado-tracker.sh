#!/bin/bash
set -euo pipefail

# グローバル変数
SCRIPT_NAME="$(basename "$0")"
VERSION="1.0.0"

# 使用方法表示
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [options]

Commands:
  fetch <project> [days]     チケット履歴を取得
  help                       このヘルプを表示

Options:
  -h, --help                 ヘルプを表示
  -v, --version              バージョンを表示

Examples:
  $SCRIPT_NAME fetch MyProject 30
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
    local command="${1:-}"
    
    case "$command" in
        fetch)
            cmd_fetch "${@:2}"
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