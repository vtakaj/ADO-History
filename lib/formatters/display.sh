#!/bin/bash
# Display and UI formatting functions

# 使用方法表示
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [options]

Commands:
  fetch <project> [days] [--with-details]  チケット履歴とステータス変更履歴を取得
  status-history <project>                 ステータス変更履歴のみを取得
  fetch-details <project>                  Work Item詳細情報のみを取得
  generate-work-table <YYYY-MM> <file>     月次作業記録テーブル（マークダウン）を生成
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
  $SCRIPT_NAME generate-work-table 2025-01 ./work_records/2025-01.md  # 月次作業記録テーブル生成
  $SCRIPT_NAME test-connection
  $SCRIPT_NAME config show
  $SCRIPT_NAME config validate
  $SCRIPT_NAME config template
  $SCRIPT_NAME help
EOF
}

# US-001-FE-001: カラー設定
setup_colors() {
    if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        RESET='\033[0m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
    fi
}

# US-001-FE-001: 進捗表示
show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    
    local percentage=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percentage * bar_length / 100))
    
    # プログレスバー作成
    local bar=""
    for ((i=0; i<filled_length; i++)); do bar+="█"; done
    for ((i=filled_length; i<bar_length; i++)); do bar+="░"; done
    
    printf "\r${BLUE}[%s] %3d%% (%d/%d) %s${RESET}" \
        "$bar" "$percentage" "$current" "$total" "$message"
    
    if [[ "$current" -eq "$total" ]]; then
        echo  # 改行
    fi
}

# US-001-FE-001: スピナー表示
show_spinner() {
    local pid="$1"
    local message="$2"
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${YELLOW}%s ${message}${RESET}" "${spinner:i++%${#spinner}:1}"
        sleep 0.1
    done
    printf "\r%*s\r" $((${#message} + 10)) ""  # クリア
}