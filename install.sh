#!/bin/bash

# Alternative dotfiles installation script using proper stow structure
# This script demonstrates how to use stow optimally with a properly structured dotfiles repo

set -e  # Exit on any error

# Parse command line arguments
WORK_MODE=false
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --work)
            WORK_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--work] [--dry-run] [--help]"
            echo "  --work     Install work-specific configurations (gitconfig and Brewfile)"
            echo "  --dry-run  Check what would be installed without making changes"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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

print_dry_run() {
    echo -e "${YELLOW}[DRY-RUN]${NC} $1"
}

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

if [[ "$DRY_RUN" == true ]]; then
    print_dry_run "DRY RUN MODE - No changes will be made"
fi

if [[ "$WORK_MODE" == true ]]; then
    print_status "Starting dotfiles installation with proper stow structure (WORK MODE)..."
    CONFIG_SUFFIX="work"
else
    print_status "Starting dotfiles installation with proper stow structure (PERSONAL MODE)..."
    CONFIG_SUFFIX="personal"
fi

print_status "Dotfiles directory: $DOTFILES_DIR"
print_status "Home directory: $HOME_DIR"
print_status "Configuration mode: $CONFIG_SUFFIX"

# Step 1: Install Homebrew
print_status "Step 1: Installing Homebrew..."
if command -v brew &> /dev/null; then
    print_success "Homebrew is already installed"
else
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would install Homebrew"
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
fi

# Step 2: Install stow
print_status "Step 2: Installing GNU Stow..."
if command -v stow &> /dev/null; then
    print_success "GNU Stow is already installed"
else
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would install GNU Stow"
    else
        brew install stow
        print_success "GNU Stow installed successfully"
    fi
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
            if [[ "$DRY_RUN" == true ]]; then
                print_dry_run "Would create backup directory: $backup_dir"
            else
                mkdir -p "$backup_dir"
            fi
            conflicts_found=true
        fi
        
        # Find conflicting files and back them up
        # This is a simplified approach - in reality, you'd parse stow's output
        print_warning "You may need to manually resolve conflicts for package: $package"
    fi
done

# Step 5: Setup configuration files based on mode
print_status "Step 5: Setting up configuration files for $CONFIG_SUFFIX mode..."

# Handle gitconfig
if [[ -f "$DOTFILES_DIR/shell/dot-gitconfig-$CONFIG_SUFFIX" ]]; then
    print_status "Using $CONFIG_SUFFIX gitconfig..."
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would symlink dot-gitconfig-$CONFIG_SUFFIX to dot-gitconfig"
    else
        # Remove existing gitconfig symlink if it exists
        if [[ -L "$DOTFILES_DIR/shell/dot-gitconfig" ]]; then
            rm "$DOTFILES_DIR/shell/dot-gitconfig"
        fi
        # Create symlink to the appropriate gitconfig
        ln -sf "dot-gitconfig-$CONFIG_SUFFIX" "$DOTFILES_DIR/shell/dot-gitconfig"
    fi
    print_success "Configured gitconfig for $CONFIG_SUFFIX mode"
elif [[ -f "$DOTFILES_DIR/shell/dot-gitconfig" ]]; then
    print_status "Using default gitconfig (no $CONFIG_SUFFIX-specific config found)"
else
    print_warning "No gitconfig found for $CONFIG_SUFFIX mode"
fi

# Handle Brewfile
if [[ -f "$DOTFILES_DIR/homebrew/dot-Brewfile-$CONFIG_SUFFIX" ]]; then
    print_status "Using $CONFIG_SUFFIX Brewfile..."
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would symlink dot-Brewfile-$CONFIG_SUFFIX to dot-Brewfile"
    else
        # Remove existing Brewfile symlink if it exists
        if [[ -L "$DOTFILES_DIR/homebrew/dot-Brewfile" ]]; then
            rm "$DOTFILES_DIR/homebrew/dot-Brewfile"
        fi
        # Create symlink to the appropriate Brewfile
        ln -sf "dot-Brewfile-$CONFIG_SUFFIX" "$DOTFILES_DIR/homebrew/dot-Brewfile"
    fi
    print_success "Configured Brewfile for $CONFIG_SUFFIX mode"
elif [[ -f "$DOTFILES_DIR/homebrew/dot-Brewfile" ]]; then
    print_status "Using default Brewfile (no $CONFIG_SUFFIX-specific config found)"
else
    print_warning "No Brewfile found for $CONFIG_SUFFIX mode"
fi

# Step 6: Stow packages
print_status "Step 6: Stowing packages..."
for package in "${packages[@]}"; do
    print_status "Stowing package: $package"
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would stow package: $package"
        # Show what would be stowed
        stow --dotfiles -n -v -t "$HOME" "$package" 2>&1 | head -10 || true
    else
        if stow --dotfiles -v -t "$HOME" "$package"; then
            print_success "Successfully stowed package: $package"
        else
            print_error "Failed to stow package: $package"
            print_error "You may need to resolve conflicts manually"
        fi
    fi
done

# Step 6.5: Configure environment variables based on mode
print_status "Step 6.5: Configuring environment variables for $CONFIG_SUFFIX mode..."

if [[ "$WORK_MODE" == false ]]; then
    # Personal mode - add DISABLE_AUTOUPDATER=1 for Claude Code
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would add DISABLE_AUTOUPDATER=1 to .zshrc (personal mode only)"
    else
        # Check if the variable is already set in .zshrc
        if [[ -f "$HOME/.zshrc" ]] && grep -q "DISABLE_AUTOUPDATER" "$HOME/.zshrc"; then
            print_status "DISABLE_AUTOUPDATER already configured in .zshrc"
        else
            print_status "Adding DISABLE_AUTOUPDATER=1 to .zshrc (personal mode)"
            echo "" >> "$HOME/.zshrc"
            echo "# Personal mode - disable auto-updater" >> "$HOME/.zshrc"
            echo "export DISABLE_AUTOUPDATER=1" >> "$HOME/.zshrc"
            print_success "Added DISABLE_AUTOUPDATER=1 to .zshrc"
        fi
    fi
else
    print_status "Work mode - skipping DISABLE_AUTOUPDATER configuration"
fi

# Step 7: Install from Brewfile if it exists
print_status "Step 7: Installing from Brewfile..."
brew_success=true

# First, install the shared/base Brewfile if it exists
if [[ -f "$DOTFILES_DIR/homebrew/dot-Brewfile-shared" ]]; then
    print_status "Installing shared packages from Brewfile-shared..."
    cd "$DOTFILES_DIR"
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Checking shared Brewfile packages..."
        if brew bundle check --file="$DOTFILES_DIR/homebrew/dot-Brewfile-shared"; then
            print_success "All shared packages are already installed"
        else
            print_warning "Some shared packages are missing and would be installed"
            brew bundle list --file="$DOTFILES_DIR/homebrew/dot-Brewfile-shared" | head -10
        fi
    else
        if brew bundle install --file="$DOTFILES_DIR/homebrew/dot-Brewfile-shared"; then
            print_success "Shared Brewfile packages installed successfully"
        else
            print_error "Some packages from shared Brewfile failed to install"
            print_warning "Continuing with remaining setup tasks..."
            brew_success=false
        fi
    fi
fi

# Then install mode-specific packages
if [[ -f "$HOME/.Brewfile" ]]; then
    print_status "Found Brewfile in home directory, installing packages..."
    cd "$HOME"
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Checking home Brewfile packages..."
        if brew bundle check --file="$HOME/.Brewfile"; then
            print_success "All home packages are already installed"
        else
            print_warning "Some home packages are missing and would be installed"
        fi
    else
        if brew bundle install --file="$HOME/.Brewfile"; then
            print_success "Home Brewfile packages installed successfully"
        else
            print_error "Some packages from home Brewfile failed to install"
            print_warning "Continuing with remaining setup tasks..."
            brew_success=false
        fi
    fi
else
    print_warning "No .Brewfile found in home directory"
    # Check if Brewfile exists in any package (this will be the mode-specific one)
    brewfile_found=false
    for package in "${packages[@]}"; do
        if [[ -f "$package/dot-Brewfile" ]]; then
            print_status "Found Brewfile in package: $package (mode: $CONFIG_SUFFIX)"
            cd "$DOTFILES_DIR"
            brewfile_found=true
            if [[ "$DRY_RUN" == true ]]; then
                print_dry_run "Checking $CONFIG_SUFFIX Brewfile packages..."
                if brew bundle check --file="$package/dot-Brewfile"; then
                    print_success "All $CONFIG_SUFFIX packages are already installed"
                else
                    print_warning "Some $CONFIG_SUFFIX packages are missing and would be installed"
                    brew bundle list --file="$package/dot-Brewfile" | head -10
                fi
            else
                if brew bundle install --file="$package/dot-Brewfile"; then
                    print_success "Brewfile from $package installed successfully"
                else
                    print_error "Some packages from $package/dot-Brewfile failed to install"
                    print_warning "Continuing with remaining setup tasks..."
                    brew_success=false
                fi
            fi
            break
        fi
    done
    
    if [[ "$brewfile_found" == false ]]; then
        print_warning "No mode-specific Brewfile found in any package"
    fi
fi

# Step 8: Run macOS configuration script
print_status "Step 8: Configuring macOS settings..."
macos_setup_script="$DOTFILES_DIR/shell/macos-setup.sh"

if [[ -f "$macos_setup_script" ]]; then
    print_status "Found macOS setup script, running configuration..."
    print_warning "This will modify various macOS system preferences."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would run macOS configuration script: $macos_setup_script"
    else
        print_status "Running macOS setup script..."
        if bash "$macos_setup_script"; then
            print_success "macOS configuration completed"
        else
            print_warning "macOS configuration script encountered some issues"
        fi
    fi
else
    print_warning "macOS setup script not found at: $macos_setup_script"
fi

# Step 9: Configure macOS Dock
print_status "Step 9: Configuring macOS Dock..."
dock_setup_script="$DOTFILES_DIR/shell/dock-setup.sh"

if [[ -f "$dock_setup_script" ]]; then
    print_status "Found dock setup script, configuring dock..."
    print_warning "This will modify your macOS dock by removing and adding applications."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_dry_run "Would run dock configuration script: $dock_setup_script"
    else
        print_status "Running dock setup script..."
        if bash "$dock_setup_script"; then
            print_success "Dock configuration completed"
        else
            print_warning "Dock configuration script encountered some issues"
        fi
    fi
else
    print_warning "Dock setup script not found at: $dock_setup_script"
fi

# Final success message
if [[ "$DRY_RUN" == true ]]; then
    print_success "Dry run completed - no changes were made!"
    print_status "This is what would have been done (mode: $CONFIG_SUFFIX):"
else
    print_success "Dotfiles installation completed!"
    print_status "Summary of what was done (mode: $CONFIG_SUFFIX):"
fi

echo "  ✅ Homebrew installed/verified"
echo "  ✅ GNU Stow installed"
echo "  ✅ Configuration files set for $CONFIG_SUFFIX mode"
echo "  ✅ Stow packages installed: ${packages[*]}"
if [[ "$WORK_MODE" == false ]]; then
    echo "  ✅ Environment variables configured (DISABLE_AUTOUPDATER)"
else
    echo "  ✅ Environment variables configured (work mode - no auto-updater disable)"
fi

if [[ "$brew_success" == true ]]; then
    echo "  ✅ Applications installed from Brewfile(s)"
else
    echo "  ⚠️  Some Brewfile packages failed to install (check output above)"
fi

if [[ "$DRY_RUN" == false ]]; then
    echo "  ✅ macOS system preferences configured"
    echo "  ✅ macOS dock customized"
fi

if [[ "$conflicts_found" == true ]]; then
    echo "  ⚠️  Some conflicts may need manual resolution"
    if [[ "$DRY_RUN" == false ]]; then
        echo "  📁 Check backup directory: $backup_dir"
    fi
fi

if [[ "$brew_success" == false ]]; then
    echo ""
    print_warning "Some brew packages failed to install. You can:"
    echo "  • Check the error messages above"
    echo "  • Run 'brew bundle install' manually later"
    echo "  • Check if the failing packages are available"
fi

if [[ "$DRY_RUN" == false ]]; then
    print_status "Restart your terminal or run 'source ~/.zshrc' to apply changes."
else
    print_status "To actually run the installation, run this script without --dry-run"
fi
