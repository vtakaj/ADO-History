#!/bin/bash
# String utility functions

# Sanitize filename for safe file operations
sanitize_filename() {
    local filename="$1"
    # Replace unsafe characters with underscores
    echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

# Truncate string to specified length with ellipsis
truncate_string() {
    local string="$1"
    local max_length="${2:-80}"
    
    if [[ ${#string} -le $max_length ]]; then
        echo "$string"
    else
        echo "${string:0:$((max_length-3))}..."
    fi
}

# Calculate display width for proper table formatting
calculate_display_width() {
    local string="$1"
    # Simple implementation - just return character count
    # In a more complex implementation, this could handle multi-byte characters
    echo ${#string}
}