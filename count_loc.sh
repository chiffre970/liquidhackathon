#!/bin/bash

# Lines of Code Counter for liquidhackathon project
# Counts source code lines excluding comments, blank lines, and generated files

echo "🔍 Counting Lines of Code in liquidhackathon project..."
echo "=========================================="

# Get the project directory (where the script is located)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Function to count lines in files matching a pattern
count_lines() {
    local pattern="$1"
    local description="$2"
    local files=$(find . -name "$pattern" -type f \
        ! -path "./.*" \
        ! -path "*/node_modules/*" \
        ! -path "*/build/*" \
        ! -path "*/Build/*" \
        ! -path "*/DerivedData/*" \
        ! -path "*/.git/*" \
        ! -path "*/Pods/*" \
        ! -path "*/.swiftpm/*" \
        ! -path "*/Package.resolved" \
        ! -path "*/.DS_Store" \
        2>/dev/null)
    
    if [ -n "$files" ]; then
        local count=$(echo "$files" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
        local file_count=$(echo "$files" | wc -l | tr -d ' ')
        printf "%-20s %8s lines (%2s files)\n" "$description:" "$count" "$file_count"
        return $count
    else
        printf "%-20s %8s lines (%2s files)\n" "$description:" "0" "0"
        return 0
    fi
}

# Count different file types
echo "File Type Breakdown:"
echo "--------------------"

# Swift files
count_lines "*.swift" "Swift"
swift_lines=$?

# Prompt files
count_lines "*.prompt" "Prompt Templates"
prompt_lines=$?

# Configuration files
count_lines "*.plist" "Property Lists"
plist_lines=$?

# Markdown files
count_lines "*.md" "Markdown"
md_lines=$?

# JSON files
count_lines "*.json" "JSON"
json_lines=$?

# CSV files
count_lines "*.csv" "CSV Data"
csv_lines=$?

# Text files
count_lines "*.txt" "Text Files"
txt_lines=$?

# Shell scripts
count_lines "*.sh" "Shell Scripts"
sh_lines=$?

# Calculate totals
total_lines=$((swift_lines + prompt_lines + plist_lines + md_lines + json_lines + csv_lines + txt_lines + sh_lines))

echo "--------------------"
printf "%-20s %8s lines\n" "TOTAL:" "$total_lines"

echo ""
echo "📊 Detailed Analysis:"
echo "===================="

# Most significant file types
if [ $swift_lines -gt 0 ]; then
    swift_percent=$(echo "scale=1; $swift_lines * 100 / $total_lines" | bc -l 2>/dev/null || echo "0")
    echo "Swift code: $swift_lines lines (${swift_percent}% of total)"
fi

if [ $prompt_lines -gt 0 ]; then
    prompt_percent=$(echo "scale=1; $prompt_lines * 100 / $total_lines" | bc -l 2>/dev/null || echo "0")
    echo "LFM2 Prompts: $prompt_lines lines (${prompt_percent}% of total)"
fi

# Top 10 largest files
echo ""
echo "📋 Largest Source Files:"
echo "========================"
find . -name "*.swift" -o -name "*.prompt" -o -name "*.md" \
    ! -path "./.*" \
    ! -path "*/node_modules/*" \
    ! -path "*/build/*" \
    ! -path "*/Build/*" \
    ! -path "*/.git/*" \
    2>/dev/null | \
    xargs wc -l 2>/dev/null | \
    sort -nr | \
    head -10 | \
    while read lines file; do
        if [ "$file" != "total" ]; then
            printf "%5s lines  %s\n" "$lines" "$(echo $file | sed 's|^\./||')"
        fi
    done

echo ""
echo "🏗️  Project Structure Overview:"
echo "==============================="

# Count directories and files
total_dirs=$(find . -type d ! -path "./.*" ! -path "*/node_modules/*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" | wc -l)
total_files=$(find . -type f ! -path "./.*" ! -path "*/node_modules/*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" | wc -l)

echo "Total directories: $total_dirs"
echo "Total files: $total_files"
echo "Source code files: $(find . \( -name "*.swift" -o -name "*.prompt" \) ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" | wc -l)"

echo ""
echo "✅ LOC count complete!"
echo "📂 Project: $(basename "$PROJECT_DIR")"
echo "📅 Generated: $(date)" 