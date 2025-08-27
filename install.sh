#!/bin/bash

# Dotfiles installation script
# This script installs homebrew, stow, sets up symlinks, and installs apps from Brewfile

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

print_status "Starting dotfiles installation..."
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

# Step 3: Create symlinks for dotfiles
print_status "Step 3: Creating symlinks for dotfiles..."

# Note: This script works with the current flat structure of your dotfiles repo.
# For optimal stow usage, consider restructuring into packages (see comments at end).

# Back up any existing files that would conflict
backup_dir="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

dotfiles_to_link=(
    ".gitconfig"
    ".gitignore_global"
    ".osx"
    ".zprofile"
    ".zshrc"
    ".Brewfile"
)

# Check for conflicts and backup if necessary
conflicts_found=false
for dotfile in "${dotfiles_to_link[@]}"; do
    if [[ -f "$HOME/$dotfile" && ! -L "$HOME/$dotfile" ]]; then
        if [[ "$conflicts_found" == false ]]; then
            print_warning "Found existing dotfiles that would conflict. Creating backup..."
            mkdir -p "$backup_dir"
            conflicts_found=true
        fi
        print_warning "Backing up existing $dotfile"
        mv "$HOME/$dotfile" "$backup_dir/"
    fi
done

if [[ "$conflicts_found" == true ]]; then
    print_success "Existing files backed up to: $backup_dir"
fi

# Create symlinks directly (since current repo structure is flat)
print_status "Creating symlinks for dotfiles..."
cd "$DOTFILES_DIR"
for dotfile in "${dotfiles_to_link[@]}"; do
    if [[ -f "$DOTFILES_DIR/$dotfile" ]]; then
        # Remove existing symlink if it exists
        if [[ -L "$HOME/$dotfile" ]]; then
            rm "$HOME/$dotfile"
        fi
        # Create new symlink
        ln -sf "$DOTFILES_DIR/$dotfile" "$HOME/$dotfile"
        print_success "Linked $dotfile → $HOME/$dotfile"
    else
        print_warning "File $dotfile not found in dotfiles directory"
    fi
done

# Step 4: Handle VS Code settings
print_status "Step 4: Setting up VS Code configuration..."

vscode_user_dir="$HOME/Library/Application Support/Code/User"
vscode_dotfiles_dir="$DOTFILES_DIR/.vscode"

# Create VS Code User directory if it doesn't exist
mkdir -p "$vscode_user_dir"

# VS Code files to link
vscode_files=(
    "settings.json"
    "keybindings.json"
    "tasks.json"
)

# Backup existing VS Code settings if they exist and aren't symlinks
vscode_backup_dir="$HOME/vscode_backup_$(date +%Y%m%d_%H%M%S)"
vscode_conflicts_found=false

for vscode_file in "${vscode_files[@]}"; do
    target_file="$vscode_user_dir/$vscode_file"
    source_file="$vscode_dotfiles_dir/$vscode_file"
    
    if [[ -f "$source_file" ]]; then
        if [[ -f "$target_file" && ! -L "$target_file" ]]; then
            if [[ "$vscode_conflicts_found" == false ]]; then
                print_warning "Found existing VS Code settings. Creating backup..."
                mkdir -p "$vscode_backup_dir"
                vscode_conflicts_found=true
            fi
            print_warning "Backing up existing $vscode_file"
            mv "$target_file" "$vscode_backup_dir/"
        fi
        
        # Remove existing symlink if it exists
        if [[ -L "$target_file" ]]; then
            rm "$target_file"
        fi
        
        # Create new symlink
        ln -sf "$source_file" "$target_file"
        print_success "Linked VS Code $vscode_file → $target_file"
    else
        print_warning "VS Code file $vscode_file not found in .vscode directory"
    fi
done

if [[ "$vscode_conflicts_found" == true ]]; then
    print_success "Existing VS Code settings backed up to: $vscode_backup_dir"
fi

# Step 5: Install apps from Brewfile
print_status "Step 5: Installing applications from Brewfile..."

if [[ -f "$HOME/.Brewfile" ]]; then
    cd "$HOME"
    print_status "Running 'brew bundle install' from Brewfile..."
    brew bundle install --file="$HOME/.Brewfile"
    print_success "Applications installed from Brewfile"
else
    print_error "Brewfile not found at $HOME/.Brewfile"
    exit 1
fi

# Final success message
print_success "Dotfiles installation completed successfully!"
print_status "Summary of what was done:"
echo "  ✅ Homebrew installed/verified"
echo "  ✅ GNU Stow installed"
echo "  ✅ Dotfiles symlinked to home directory"
echo "  ✅ VS Code settings symlinked"
echo "  ✅ Applications installed from Brewfile"

if [[ "$conflicts_found" == true ]]; then
    echo "  📁 Original dotfiles backed up to: $backup_dir"
fi

if [[ "$vscode_conflicts_found" == true ]]; then
    echo "  📁 Original VS Code settings backed up to: $vscode_backup_dir"
fi

print_status "You may need to restart your terminal or run 'source ~/.zshrc' to apply shell configuration changes."

print_status ""
print_status "OPTIONAL: For better stow integration, consider restructuring your dotfiles:"
print_status "Instead of having files in the root, create package directories like:"
print_status "  dotfiles/"
print_status "  ├── shell/"
print_status "  │   ├── .zshrc"
print_status "  │   ├── .zprofile"
print_status "  │   └── .gitconfig"
print_status "  ├── homebrew/"
print_status "  │   └── .Brewfile"
print_status "  └── vscode/"
print_status "      └── Library/Application Support/Code/User/"
print_status "          ├── settings.json"
print_status "          ├── keybindings.json"
print_status "          └── tasks.json"
print_status ""
print_status "Then you could use: stow -t \$HOME shell homebrew vscode"
print_status "This would allow better organization and selective stowing of packages."
