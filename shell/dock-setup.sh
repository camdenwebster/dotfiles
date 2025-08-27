#!/bin/bash

# Dock configuration script
# This script downloads dockutil and configures the macOS dock

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[DOCK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[DOCK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[DOCK]${NC} $1"
}

print_error() {
    echo -e "${RED}[DOCK]${NC} $1"
}

print_status "Starting dock configuration..."

# Step 1: Download and install dockutil
print_status "Step 1: Installing dockutil..."

# Check if dockutil is already installed
if command -v dockutil &> /dev/null; then
    print_success "dockutil is already installed"
else
    print_status "Downloading dockutil..."
    
    # Create temp directory for download
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Download dockutil package
    curl -L -o dockutil.pkg "https://github.com/kcrawford/dockutil/releases/download/3.1.3/dockutil-3.1.3.pkg"
    
    # Install the package
    print_status "Installing dockutil package..."
    sudo installer -pkg dockutil.pkg -target /
    
    # Clean up
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    print_success "dockutil installed successfully"
fi

# Verify dockutil is available
if ! command -v dockutil &> /dev/null; then
    print_error "dockutil installation failed or not in PATH"
    exit 1
fi

# Step 2: Remove unwanted dock items
print_status "Step 2: Removing unwanted dock items..."

# List of items to remove
items_to_remove=(
    "Maps"
    "Photos"
    "FaceTime"
    "Contacts"
    "Freeform"
    "TV"
    "News"
    "Keynote"
    "Numbers"
    "Pages"
    "App Store"
)

for item in "${items_to_remove[@]}"; do
    print_status "Removing: $item"
    # Use --no-restart to avoid restarting dock after each removal
    if dockutil --remove "$item" --no-restart 2>/dev/null; then
        print_success "Removed: $item"
    else
        print_warning "Could not remove: $item (may not be present)"
    fi
done

# Step 3: Add desired dock items at specific positions
print_status "Step 3: Adding new dock items..."

# Define apps to add with their positions
declare -A apps_to_add=(
    ["Obsidian"]="/Applications/Obsidian.app"
    ["Visual Studio Code"]="/Applications/Visual Studio Code.app"
    ["Xcode"]="/Applications/Xcode.app"
    ["Slack"]="/Applications/Slack.app"
)

declare -A app_positions=(
    ["Obsidian"]=4
    ["Visual Studio Code"]=5
    ["Xcode"]=6
    ["Slack"]=7
)

# Add each application at the specified position
for app_name in "Obsidian" "Visual Studio Code" "Xcode" "Slack"; do
    app_path="${apps_to_add[$app_name]}"
    position="${app_positions[$app_name]}"
    
    print_status "Adding: $app_name at position $position"
    
    # Check if app exists before adding
    if [[ -d "$app_path" ]]; then
        # Remove if already exists (to avoid duplicates), then add at correct position
        dockutil --remove "$app_name" --no-restart 2>/dev/null || true
        
        if dockutil --add "$app_path" --position "$position" --no-restart; then
            print_success "Added: $app_name at position $position"
        else
            print_error "Failed to add: $app_name"
        fi
    else
        print_warning "Application not found: $app_path"
        print_warning "Skipping: $app_name"
    fi
done

# Step 4: Restart the Dock to apply all changes
print_status "Step 4: Restarting Dock to apply changes..."
killall Dock

print_success "Dock configuration completed successfully!"
print_status "Your dock has been customized with the following changes:"
echo "  🗑️  Removed unwanted applications"
echo "  📱 Added Obsidian at position 4"
echo "  💻 Added Visual Studio Code at position 5"
echo "  🔨 Added Xcode at position 6"
echo "  💬 Added Slack at position 7"
print_status "The Dock will restart automatically to show the changes."
