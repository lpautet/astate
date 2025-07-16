#!/bin/bash

# iOS App Icon Generator
# Converts SVG to all required iOS app icon sizes

SVG_FILE="app-icon.svg"
OUTPUT_DIR="AppIcons"

# Check if SVG file exists
if [ ! -f "$SVG_FILE" ]; then
    echo "❌ Error: $SVG_FILE not found!"
    exit 1
fi

# Check if rsvg-convert is installed
if ! command -v rsvg-convert > /dev/null 2>&1; then
    echo "❌ Error: rsvg-convert not found!"
    echo "Install with: brew install librsvg"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "🎨 Generating iOS app icons from $SVG_FILE..."

# Function to generate icon
generate_icon() {
    local name=$1
    local size=$2
    local comment=$3
    local output_file="$OUTPUT_DIR/${name}.png"
    
    echo "  📱 Generating ${name}.png (${size}×${size}) - $comment"
    rsvg-convert -w "$size" -h "$size" "$SVG_FILE" -o "$output_file"
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Created: $output_file"
    else
        echo "  ❌ Failed to create: $output_file"
    fi
}

# Generate all required iOS icon sizes
generate_icon "AppIcon-1024" "1024" "App Store"
generate_icon "AppIcon-180" "180" "iPhone @3x (60pt)"
generate_icon "AppIcon-167" "167" "iPad Pro @2x (83.5pt)"
generate_icon "AppIcon-152" "152" "iPad @2x (76pt)"
generate_icon "AppIcon-120" "120" "iPhone @2x (60pt)"
generate_icon "AppIcon-114" "114" "iPhone @2x (57pt) - Legacy"
generate_icon "AppIcon-87" "87" "iPhone @3x (29pt) - Settings"
generate_icon "AppIcon-80" "80" "iPad @2x (40pt) - Spotlight"
generate_icon "AppIcon-76" "76" "iPad @1x (76pt)"
generate_icon "AppIcon-60" "60" "iPhone @1x (60pt) - Legacy"
generate_icon "AppIcon-58" "58" "iPhone @2x (29pt) - Settings"
generate_icon "AppIcon-40" "40" "iPad @1x (40pt) - Spotlight"
generate_icon "AppIcon-29" "29" "iPhone @1x (29pt) - Settings"
generate_icon "AppIcon-20" "20" "iPhone @1x (20pt) - Notification"

echo ""
echo "🎉 Icon generation complete!"
echo "📁 All icons saved to: $OUTPUT_DIR/"
echo ""
echo "📋 Quick sizes reference:"
echo "  • AppIcon-1024.png  → App Store"
echo "  • AppIcon-180.png   → iPhone @3x"
echo "  • AppIcon-167.png   → iPad Pro @2x"  
echo "  • AppIcon-152.png   → iPad @2x"
echo "  • AppIcon-120.png   → iPhone @2x"
echo ""
echo "💡 Import these into Xcode Assets.xcassets → AppIcon" 