#!/bin/bash
# File utility functions

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

# Ensure directory exists
ensure_directory() {
    local dir_path="$1"
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path"
        log_info "ディレクトリを作成: $dir_path"
    fi
}

# Backup file with timestamp
backup_file() {
    local file_path="$1"
    local backup_dir="${2:-$BACKUP_DIR}"
    
    if [[ -f "$file_path" ]]; then
        local filename=$(basename "$file_path")
        local backup_path="$backup_dir/${filename}.$(date +%Y%m%d_%H%M%S)"
        ensure_directory "$backup_dir"
        cp "$file_path" "$backup_path"
        log_info "ファイルをバックアップ: $file_path → $backup_path"
    fi
}

# Cleanup temporary files
cleanup_temp_files() {
    local pattern="${1:-/tmp/ado-tracker-*}"
    local count=0
    
    for file in $pattern; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            ((count++))
        fi
    done
    
    if [[ $count -gt 0 ]]; then
        log_info "一時ファイルをクリーンアップ: $count個"
    fi
}