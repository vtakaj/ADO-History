#!/bin/bash
# Date utility functions

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

# US-001-FE-001: 日本語曜日取得
get_japanese_day_of_week() {
    local dow="$1"  # 1=月曜日, 7=日曜日
    
    case "$dow" in
        1) echo "月" ;;
        2) echo "火" ;;
        3) echo "水" ;;
        4) echo "木" ;;
        5) echo "金" ;;
        6) echo "土" ;;
        7) echo "日" ;;
        *) echo "$dow" ;;
    esac
}

# US-001-FE-001: 月末日取得
get_last_day_of_month() {
    local year_month="$1"  # YYYY-MM
    date -d "${year_month}-01 + 1 month - 1 day" '+%Y-%m-%d' 2>/dev/null || \
    date -j -v+1m -v-1d -f "%Y-%m-%d" "${year_month}-01" '+%Y-%m-%d' 2>/dev/null
}