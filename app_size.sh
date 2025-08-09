#!/bin/bash

# App Size Analysis for Vera iOS App
# Analyzes source code size, build artifacts, and estimates final app size

echo "📱 Vera iOS App Size Analysis"
echo "=============================="

# Get the project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Function to format bytes in human readable format
format_bytes() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc -l)GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc -l)MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc -l)KB"
    else
        echo "${bytes}B"
    fi
}

echo "🔍 Analyzing project size components..."
echo ""

# 1. Source Code Size
echo "📄 Source Code Analysis:"
echo "------------------------"

# Swift source files
swift_size=$(find . -name "*.swift" -type f ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}')
swift_files=$(find . -name "*.swift" -type f ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" | wc -l | tr -d ' ')

# Asset files (images, etc.)
assets_size=$(find . \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.pdf" -o -name "*.svg" \) -type f ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
assets_files=$(find . \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.pdf" -o -name "*.svg" \) -type f ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" | wc -l | tr -d ' ')

# Configuration files
config_size=$(find . \( -name "*.plist" -o -name "*.json" -o -name "*.strings" \) -type f ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
config_files=$(find . \( -name "*.plist" -o -name "*.json" -o -name "*.strings" \) -type f ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" | wc -l | tr -d ' ')

# Prompt templates
prompt_size=$(find . -name "*.prompt" -type f ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
prompt_files=$(find . -name "*.prompt" -type f ! -path "./.*" ! -path "*/build/*" ! -path "*/Build/*" ! -path "*/.git/*" | wc -l | tr -d ' ')

printf "Swift source:     %8s (%2s files)\n" "$(format_bytes ${swift_size:-0})" "$swift_files"
printf "Assets:           %8s (%2s files)\n" "$(format_bytes ${assets_size:-0})" "$assets_files"
printf "Config files:     %8s (%2s files)\n" "$(format_bytes ${config_size:-0})" "$config_files"
printf "Prompt templates: %8s (%2s files)\n" "$(format_bytes ${prompt_size:-0})" "$prompt_files"

source_total=$((${swift_size:-0} + ${assets_size:-0} + ${config_size:-0} + ${prompt_size:-0}))
echo "------------------------"
printf "Source Total:     %8s\n" "$(format_bytes $source_total)"

echo ""

# 2. Build Artifacts
echo "🔨 Build Artifacts:"
echo "-------------------"

# Find DerivedData
derived_data_path="$HOME/Library/Developer/Xcode/DerivedData"
vera_derived_data=$(find "$derived_data_path" -name "Vera-*" -type d 2>/dev/null | head -1)

if [ -n "$vera_derived_data" ] && [ -d "$vera_derived_data" ]; then
    echo "Found DerivedData: $(basename "$vera_derived_data")"
    
    # Check for app bundle
    app_bundle=$(find "$vera_derived_data" -name "Vera.app" -type d 2>/dev/null | head -1)
    
    if [ -n "$app_bundle" ] && [ -d "$app_bundle" ]; then
        app_size=$(du -sk "$app_bundle" 2>/dev/null | awk '{print $1 * 1024}')
        printf "App Bundle:       %8s\n" "$(format_bytes $app_size)"
        
        # Analyze app bundle contents
        echo ""
        echo "📦 App Bundle Breakdown:"
        echo "------------------------"
        
        # Main executable
        if [ -f "$app_bundle/Vera" ]; then
            exec_size=$(wc -c < "$app_bundle/Vera" 2>/dev/null || echo "0")
            printf "Executable:       %8s\n" "$(format_bytes $exec_size)"
        fi
        
        # Frameworks
        if [ -d "$app_bundle/Frameworks" ]; then
            frameworks_size=$(du -sk "$app_bundle/Frameworks" 2>/dev/null | awk '{print $1 * 1024}' || echo "0")
            frameworks_count=$(find "$app_bundle/Frameworks" -name "*.framework" | wc -l | tr -d ' ')
            printf "Frameworks:       %8s (%s frameworks)\n" "$(format_bytes $frameworks_size)" "$frameworks_count"
            
            # List major frameworks
            echo "  Major frameworks:"
            find "$app_bundle/Frameworks" -name "*.framework" -exec basename {} \; 2>/dev/null | head -5 | sed 's/^/    - /'
        fi
        
        # App resources
        info_plist_size=$(wc -c < "$app_bundle/Info.plist" 2>/dev/null || echo "0")
        printf "Info.plist:       %8s\n" "$(format_bytes $info_plist_size)"
        
        # Assets and resources
        resources_size=0
        if [ -d "$app_bundle/Base.lproj" ]; then
            base_size=$(du -sk "$app_bundle/Base.lproj" 2>/dev/null | awk '{print $1 * 1024}' || echo "0")
            resources_size=$((resources_size + base_size))
        fi
        
        # Count other resource files
        other_resources=$(find "$app_bundle" -type f ! -name "Vera" ! -name "Info.plist" ! -path "*/Frameworks/*" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
        total_resources=$((resources_size + other_resources))
        printf "Resources:        %8s\n" "$(format_bytes $total_resources)"
        
    else
        echo "❌ No app bundle found. App may not be built yet."
        echo "💡 Run 'xcodebuild -scheme Vera -configuration Release' to build the app"
    fi
    
    # Check overall DerivedData size
    derived_size=$(du -sk "$vera_derived_data" 2>/dev/null | awk '{print $1 * 1024}')
    echo ""
    printf "DerivedData Total: %8s\n" "$(format_bytes $derived_size)"
    
else
    echo "❌ No DerivedData found for Vera project"
    echo "💡 Build the project in Xcode to generate build artifacts"
fi

echo ""

# 3. Estimated Final App Size
echo "📊 Size Estimates:"
echo "------------------"

# Base iOS app overhead (typical for SwiftUI apps)
base_overhead=5242880  # ~5MB base overhead

# Swift runtime and standard library (if not optimized)
swift_runtime=2097152  # ~2MB

# Estimate compressed size (App Store compression is typically 60-70%)
if [ -n "$app_size" ] && [ "$app_size" -gt 0 ]; then
    compressed_size=$(echo "scale=0; $app_size * 0.65" | bc -l)
    printf "Current build:    %8s\n" "$(format_bytes $app_size)"
    printf "Compressed est:   %8s (App Store)\n" "$(format_bytes ${compressed_size%.*})"
else
    # Estimate based on source code
    estimated_size=$((source_total + base_overhead + swift_runtime))
    compressed_estimate=$(echo "scale=0; $estimated_size * 0.65" | bc -l)
    printf "Source + overhead: %8s\n" "$(format_bytes $estimated_size)"
    printf "Compressed est:    %8s (App Store)\n" "$(format_bytes ${compressed_estimate%.*})"
fi

echo ""

# 4. Dependencies Analysis
echo "📚 Dependencies:"
echo "----------------"

# Check Package.resolved for external dependencies
if [ -f "Vera.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    echo "Swift Package Dependencies:"
    cat "Vera.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" | grep '"identity"' | sed 's/.*"identity" : "\([^"]*\)".*/  - \1/' 2>/dev/null
elif [ -f ".swiftpm/xcode/package.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    echo "Swift Package Dependencies:"
    cat ".swiftpm/xcode/package.xcworkspace/xcshareddata/swiftpm/Package.resolved" | grep '"identity"' | sed 's/.*"identity" : "\([^"]*\)".*/  - \1/' 2>/dev/null
else
    echo "No Package.resolved found"
fi

# Check for CocoaPods if Podfile exists
if [ -f "Podfile" ]; then
    echo ""
    echo "CocoaPods Dependencies:"
    grep "pod '" Podfile | sed "s/.*pod '\([^']*\)'.*/  - \1/" 2>/dev/null
fi

echo ""

# 5. Optimization Suggestions
echo "⚡ Optimization Suggestions:"
echo "----------------------------"

if [ "$source_total" -gt 1048576 ]; then  # > 1MB source
    echo "• Source code is substantial ($(format_bytes $source_total))"
    echo "  - Consider code splitting and lazy loading"
    echo "  - Review unused imports and dead code"
fi

if [ "$assets_size" -gt 2097152 ]; then  # > 2MB assets
    echo "• Large asset size detected ($(format_bytes $assets_size))"
    echo "  - Optimize images (WebP, smaller dimensions)"
    echo "  - Use vector assets where possible"
fi

if [ -n "$app_size" ] && [ "$app_size" -gt 52428800 ]; then  # > 50MB
    echo "• App size is large ($(format_bytes $app_size))"
    echo "  - Consider on-demand resources"
    echo "  - Review framework dependencies"
fi

echo "• General optimizations:"
echo "  - Enable Bitcode for better App Store optimization"
echo "  - Use release build configuration"
echo "  - Strip debug symbols"
echo "  - Enable dead code stripping"

echo ""
echo "✅ App size analysis complete!"
echo "📅 Generated: $(date)" 