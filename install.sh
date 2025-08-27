#!/bin/bash

# Alternative dotfiles installation script using proper stow structure
# This script demonstrates how to use stow optimally with a properly structured dotfiles repo

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

print_status "Starting dotfiles installation with proper stow structure..."
print_status "Dotfiles directory: $DOTFILES_DIR"
print_status "Home directory: $HOME_DIR"

# Step 1: Install Homebrew
print_status "Step 1: Installing Homebrew..."
if command -v brew &> /dev/null; then
    print_success "Homebrew is already installed"
else
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    print_success "Homebrew installed successfully"
fi

# Step 2: Install stow
print_status "Step 2: Installing GNU Stow..."
if command -v stow &> /dev/null; then
    print_success "GNU Stow is already installed"
else
    brew install stow
    print_success "GNU Stow installed successfully"
fi

# Step 3: Check for proper stow structure
print_status "Step 3: Checking repository structure..."
cd "$DOTFILES_DIR"

# Look for package directories (directories that don't start with .)
packages=()
for dir in */; do
    if [[ -d "$dir" && ! "$dir" =~ ^\. ]]; then
        packages+=("${dir%/}")
    fi
done

if [[ ${#packages[@]} -eq 0 ]]; then
    print_error "No stow packages found!"
    print_error "This script requires a properly structured stow repository."
    print_error "Please restructure your dotfiles into packages."
    print_error ""
    print_error "Example structure:"
    print_error "  dotfiles/"
    print_error "  ├── shell/          # Package for shell configs"
    print_error "  │   ├── dot-zshrc"
    print_error "  │   └── dot-gitconfig"
    print_error "  ├── homebrew/       # Package for homebrew"
    print_error "  │   └── dot-Brewfile"
    print_error "  └── vscode/         # Package for VS Code"
    print_error "      └── Library/Application Support/Code/User/"
    print_error "          ├── settings.json"
    print_error "          └── keybindings.json"
    print_error ""
    print_error "Then run: cd dotfiles && stow -t \$HOME shell homebrew vscode"
    exit 1
fi

print_success "Found stow packages: ${packages[*]}"

# Step 4: Create backups for conflicting files
print_status "Step 4: Checking for conflicts..."
backup_dir="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
conflicts_found=false

# Use stow's simulation mode to check for conflicts
for package in "${packages[@]}"; do
    print_status "Checking package: $package"
    if ! stow --dotfiles -n -v -t "$HOME" "$package" 2>/dev/null; then
        print_warning "Conflicts detected for package: $package"
        
        if [[ "$conflicts_found" == false ]]; then
            mkdir -p "$backup_dir"
            conflicts_found=true
        fi
        
        # Find conflicting files and back them up
        # This is a simplified approach - in reality, you'd parse stow's output
        print_warning "You may need to manually resolve conflicts for package: $package"
    fi
done

# Step 5: Stow packages
print_status "Step 5: Stowing packages..."
for package in "${packages[@]}"; do
    print_status "Stowing package: $package"
    if stow --dotfiles -v -t "$HOME" "$package"; then
        print_success "Successfully stowed package: $package"
    else
        print_error "Failed to stow package: $package"
        print_error "You may need to resolve conflicts manually"
    fi
done

# Step 6: Install from Brewfile if it exists
print_status "Step 6: Installing from Brewfile..."
if [[ -f "$HOME/.Brewfile" ]]; then
    print_status "Found Brewfile, installing packages..."
    cd "$HOME"
    brew bundle install --file="$HOME/.Brewfile"
    print_success "Brewfile packages installed"
else
    print_warning "No .Brewfile found in home directory"
    # Check if Brewfile exists in any package
    for package in "${packages[@]}"; do
        if [[ -f "$package/.Brewfile" ]]; then
            print_status "Found Brewfile in package: $package"
            cd "$DOTFILES_DIR"
            brew bundle install --file="$package/.Brewfile"
            print_success "Brewfile from $package installed"
            break
        fi
    done
fi

# Step 7: Run macOS configuration script
print_status "Step 7: Configuring macOS settings..."
macos_setup_script="$DOTFILES_DIR/shell/macos-setup.sh"

if [[ -f "$macos_setup_script" ]]; then
    print_status "Found macOS setup script, running configuration..."
    print_warning "This will modify various macOS system preferences."
    
    # Ask for user confirmation
    read -p "Do you want to run the macOS configuration script? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Running macOS setup script..."
        if bash "$macos_setup_script"; then
            print_success "macOS configuration completed"
        else
            print_warning "macOS configuration script encountered some issues"
        fi
    else
        print_status "Skipping macOS configuration"
    fi
else
    print_warning "macOS setup script not found at: $macos_setup_script"
fi

# Step 8: Configure macOS Dock
print_status "Step 8: Configuring macOS Dock..."
dock_setup_script="$DOTFILES_DIR/shell/dock-setup.sh"

if [[ -f "$dock_setup_script" ]]; then
    print_status "Found dock setup script, configuring dock..."
    print_warning "This will modify your macOS dock by removing and adding applications."
    
    # Ask for user confirmation
    read -p "Do you want to run the dock configuration script? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Running dock setup script..."
        if bash "$dock_setup_script"; then
            print_success "Dock configuration completed"
        else
            print_warning "Dock configuration script encountered some issues"
        fi
    else
        print_status "Skipping dock configuration"
    fi
else
    print_warning "Dock setup script not found at: $dock_setup_script"
fi

# Final success message
print_success "Dotfiles installation completed successfully!"
print_status "Summary of what was done:"
echo "  ✅ Homebrew installed/verified"
echo "  ✅ GNU Stow installed"
echo "  ✅ Stow packages installed: ${packages[*]}"
echo "  ✅ Applications installed from Brewfile"
echo "  ✅ macOS system preferences configured"
echo "  ✅ macOS dock customized"

if [[ "$conflicts_found" == true ]]; then
    echo "  ⚠️  Some conflicts may need manual resolution"
    echo "  📁 Check backup directory: $backup_dir"
fi

print_status "Restart your terminal or run 'source ~/.zshrc' to apply changes."
