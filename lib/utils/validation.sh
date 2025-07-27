#!/bin/bash
# Validation utility functions

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