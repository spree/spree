#!/bin/bash

# Spree Commerce Guided Installer
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/spree/spree/main/install.sh)"
# Usage with options: bash -c "$(curl -fsSL https://raw.githubusercontent.com/spree/spree/main/install.sh)" -- --verbose
# Or: bash install.sh --verbose --local --app-name=my_store --auto-accept --force
# Options:
#   --verbose, -v           Show detailed output
#   --local, -l             Use local Spree gems from parent directory
#   --app-name=NAME         Set application name (skips prompt)
#   --storefront=TYPE       Set storefront type: none, rails (skips prompt)
#   --auto-accept, -y       Use default values for all prompts (non-interactive mode)
#   --force, -f             Remove existing directory if it exists

set -e

# Colors for output (used before gum is available and in error handler)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# GitHub issue URL for reporting problems
GITHUB_ISSUES_URL="https://github.com/spree/spree/issues/new?labels=installer&template=installer_issue.md"

# Error handler function
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command="$2"

    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}  Installation Failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}Error details:${NC}"
    echo -e "  Exit code: $exit_code"
    echo -e "  Line: $line_number"
    echo -e "  Command: $command"
    echo ""
    echo -e "${BOLD}System information:${NC}"
    echo -e "  OS: $(uname -s) $(uname -r)"
    echo -e "  Architecture: $(uname -m)"
    if command -v ruby &> /dev/null; then
        echo -e "  Ruby: $(ruby -v 2>/dev/null || echo 'not available')"
    else
        echo -e "  Ruby: not installed"
    fi
    if command -v rails &> /dev/null; then
        echo -e "  Rails: $(rails -v 2>/dev/null || echo 'not available')"
    else
        echo -e "  Rails: not installed"
    fi
    echo ""
    echo -e "${BOLD}Troubleshooting:${NC}"
    echo -e "  1. Run the installer with --verbose flag for detailed output:"
    echo -e "     ${BLUE}bash -c \"\$(curl -fsSL https://spreecommerce.org/install)\" -- --verbose${NC}"
    echo ""
    echo -e "  2. Ensure you have Ruby 3.2+ installed:"
    echo -e "     ${BLUE}ruby -v${NC}"
    echo ""
    echo -e "${BOLD}Report this issue:${NC}"
    echo -e "  If the problem persists, please report it at:"
    echo -e "  ${BLUE}${GITHUB_ISSUES_URL}${NC}"
    echo ""
    echo -e "  Please include the error details and system information above."
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    exit $exit_code
}

# Set up error trap
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# Configuration
RAILS_VERSION="${RAILS_VERSION:-8.1.2}"
APP_NAME=""
LOAD_SAMPLE_DATA="false"
STOREFRONT_TYPE=""
TEMPLATE_URL="https://raw.githubusercontent.com/spree/spree/main/spree/template.rb"
VERBOSE=false
USE_LOCAL_SPREE=false
AUTO_ACCEPT=false
FORCE_REMOVE=false
RUBY_CONFIGURED=false
USING_HOMEBREW_RUBY=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --local|-l)
            USE_LOCAL_SPREE=true
            shift
            ;;
        --app-name=*)
            APP_NAME="${arg#*=}"
            shift
            ;;
        --storefront=*)
            STOREFRONT_TYPE="${arg#*=}"
            shift
            ;;
        --auto-accept|-y)
            AUTO_ACCEPT=true
            shift
            ;;
        --force|-f)
            FORCE_REMOVE=true
            shift
            ;;
    esac
done

# Helper functions (require gum - only called after install_gum)
print_header() {
    echo ""
    gum style \
        --border double \
        --align center \
        --width 55 \
        --margin "1 0" \
        --padding "1 2" \
        --border-foreground 4 \
        --bold \
        "Spree Commerce Guided Installer"
    echo ""
}

print_step() {
    echo ""
    gum style --foreground 2 --bold "➜ $1"
}

print_info() {
    gum style --foreground 4 "ℹ $1"
}

print_success() {
    gum style --foreground 2 "✓ $1"
}

print_warning() {
    gum style --foreground 3 "⚠ $1"
}

print_error() {
    gum style --foreground 1 "✗ $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_quiet() {
    if [ "$VERBOSE" = true ]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

run_with_status() {
    local description="$1"
    shift

    if [ "$VERBOSE" = true ]; then
        gum log --level info "$description"
        "$@"
    else
        gum spin --spinner dot --title "$description" -- "$@"
    fi
}

# Detect OS
detect_os() {
    echo -e "\n${BOLD}${GREEN}➜${NC} ${BOLD}Detecting operating system...${NC}"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
            echo -e "${GREEN}✓${NC} Detected: Linux ($NAME)"
        else
            DISTRO="unknown"
            echo -e "${GREEN}✓${NC} Detected: Linux (Unknown distribution)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        echo -e "${GREEN}✓${NC} Detected: macOS"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        DISTRO="windows"
        echo -e "${YELLOW}⚠${NC} Windows detected. WSL is required for Spree."
        echo -e "\nPlease install WSL (Windows Subsystem for Linux) first:"
        echo -e "  ${BOLD}wsl --install${NC}"
        echo -e "\nThen run this installer from within WSL."
        exit 1
    else
        OS="unknown"
        DISTRO="unknown"
        echo -e "${RED}✗${NC} Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Install gum for interactive UI
install_gum() {
    if command_exists gum; then
        return 0
    fi

    echo -e "\n${BOLD}${GREEN}➜${NC} ${BOLD}Installing gum (interactive UI)...${NC}"

    if [ "$OS" = "macos" ]; then
        # Ensure Homebrew is available (needed to install gum)
        if ! command_exists brew; then
            echo -e "${BLUE}ℹ${NC} Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            BREW_PATH=$(command -v brew 2>/dev/null)
            if [[ -n "$BREW_PATH" ]]; then
                echo "eval \"\$($BREW_PATH shellenv)\"" >> ~/.zprofile
                eval "$($BREW_PATH shellenv)"
            elif [[ $(uname -m) == 'arm64' ]] && [[ -x /opt/homebrew/bin/brew ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -x /usr/local/bin/brew ]]; then
                echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/usr/local/bin/brew shellenv)"
            fi

            echo -e "${GREEN}✓${NC} Homebrew installed successfully"
        fi

        brew install gum >/dev/null 2>&1 || true
    elif [ "$OS" = "linux" ]; then
        if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg 2>/dev/null
            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install -y gum >/dev/null 2>&1
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
            echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo >/dev/null
            sudo dnf install -y gum >/dev/null 2>&1 || sudo yum install -y gum >/dev/null 2>&1
        fi
    fi

    if ! command_exists gum; then
        echo -e "${RED}✗${NC} Failed to install gum."
        echo -e "  Please install it manually: ${BLUE}https://github.com/charmbracelet/gum#installation${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} gum installed successfully"
}

# Install system dependencies
install_system_deps() {
    print_step "Installing system dependencies..."

    if [ "$OS" = "macos" ]; then
        run_with_status "Installing libvips..." brew install vips || {
            print_warning "Package may already be installed"
        }

        print_success "System dependencies installed"

    elif [ "$OS" = "linux" ]; then
        if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
            run_with_status "Updating package lists..." sudo apt-get update
            run_with_status "Installing development dependencies..." sudo apt-get install -y build-essential git curl libvips-dev libssl-dev libreadline-dev zlib1g-dev libsqlite3-dev libyaml-dev

            print_success "System dependencies installed"
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
            run_with_status "Installing development packages..." sudo dnf install -y vips vips-devel gcc gcc-c++ make openssl-devel readline-devel zlib-devel sqlite-devel libyaml-devel git || \
            sudo yum install -y vips vips-devel gcc gcc-c++ make openssl-devel readline-devel zlib-devel sqlite-devel libyaml-devel git

            print_success "System dependencies installed"
        else
            print_warning "Please install libvips development packages manually for your distribution"
        fi
    fi
}

# Install Ruby using system package manager
install_ruby() {
    print_step "Checking Ruby installation..."

    if [ "$OS" = "macos" ]; then
        # On macOS, check if there's already a non-system Ruby installed (e.g., via rvm, rbenv, etc.)
        if command_exists ruby; then
            CURRENT_RUBY_PATH=$(which ruby)

            # If Ruby is not the system Ruby and meets version requirements, use it
            if [[ "$CURRENT_RUBY_PATH" != "/usr/bin/ruby" ]]; then
                CURRENT_RUBY=$(ruby -v | awk '{print $2}' | cut -d'p' -f1)
                RUBY_MAJOR=$(echo "$CURRENT_RUBY" | cut -d'.' -f1)

                RUBY_MINOR=$(echo "$CURRENT_RUBY" | cut -d'.' -f2)
                if [ "$RUBY_MAJOR" -gt 3 ] || ([ "$RUBY_MAJOR" -eq 3 ] && [ "$RUBY_MINOR" -ge 2 ]); then
                    print_success "Ruby $CURRENT_RUBY is already installed at $CURRENT_RUBY_PATH"
                    print_info "Using existing Ruby installation"
                    return 0
                else
                    print_warning "Existing Ruby $CURRENT_RUBY at $CURRENT_RUBY_PATH is too old (need >= 3.2)"
                    print_info "Will install Homebrew Ruby"
                fi
            else
                print_info "System Ruby detected at /usr/bin/ruby (requires sudo for gems)"
                print_info "Will install Homebrew Ruby for better experience"
            fi
        fi

        # On macOS, prefer Homebrew Ruby over system Ruby
        # System Ruby requires root privileges for gem installation
        BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")

        # Check if Homebrew Ruby is already installed
        if [ -x "$BREW_PREFIX/opt/ruby/bin/ruby" ]; then
            # Homebrew Ruby exists, ensure it's in PATH
            export PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"

            CURRENT_RUBY=$("$BREW_PREFIX/opt/ruby/bin/ruby" -v | awk '{print $2}' | cut -d'p' -f1)
            RUBY_MAJOR=$(echo "$CURRENT_RUBY" | cut -d'.' -f1)

            RUBY_MINOR=$(echo "$CURRENT_RUBY" | cut -d'.' -f2)
            if [ "$RUBY_MAJOR" -gt 3 ] || ([ "$RUBY_MAJOR" -eq 3 ] && [ "$RUBY_MINOR" -ge 2 ]); then
                print_success "Homebrew Ruby $CURRENT_RUBY is already installed"

                # Still need to setup PATH in shell profiles
                RUBY_VERSION_PATH=$("$BREW_PREFIX/opt/ruby/bin/ruby" -e 'puts RbConfig::CONFIG["ruby_version"]' 2>/dev/null || echo "")

                # Add to zsh profile
                if [ -f ~/.zshrc ]; then
                    if ! grep -q "$BREW_PREFIX/opt/ruby/bin" ~/.zshrc; then
                        echo "" >> ~/.zshrc
                        echo "# Homebrew Ruby" >> ~/.zshrc
                        echo "export PATH=\"$BREW_PREFIX/opt/ruby/bin:\$PATH\"" >> ~/.zshrc
                        if [ -n "$RUBY_VERSION_PATH" ]; then
                            echo "export PATH=\"$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:\$PATH\"" >> ~/.zshrc
                        fi
                        print_info "Added Homebrew Ruby to ~/.zshrc"
                    fi
                fi

                # Add to bash profile
                if [ -f ~/.bash_profile ]; then
                    if ! grep -q "$BREW_PREFIX/opt/ruby/bin" ~/.bash_profile; then
                        echo "" >> ~/.bash_profile
                        echo "# Homebrew Ruby" >> ~/.bash_profile
                        echo "export PATH=\"$BREW_PREFIX/opt/ruby/bin:\$PATH\"" >> ~/.bash_profile
                        if [ -n "$RUBY_VERSION_PATH" ]; then
                            echo "export PATH=\"$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:\$PATH\"" >> ~/.bash_profile
                        fi
                        print_info "Added Homebrew Ruby to ~/.bash_profile"
                    fi
                fi

                # Add to bashrc if it exists
                if [ -f ~/.bashrc ]; then
                    if ! grep -q "$BREW_PREFIX/opt/ruby/bin" ~/.bashrc; then
                        echo "" >> ~/.bashrc
                        echo "# Homebrew Ruby" >> ~/.bashrc
                        echo "export PATH=\"$BREW_PREFIX/opt/ruby/bin:\$PATH\"" >> ~/.bashrc
                        if [ -n "$RUBY_VERSION_PATH" ]; then
                            echo "export PATH=\"$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:\$PATH\"" >> ~/.bashrc
                        fi
                        print_info "Added Homebrew Ruby to ~/.bashrc"
                    fi
                fi

                # Update PATH for current session (including gem bin)
                if [ -n "$RUBY_VERSION_PATH" ]; then
                    export PATH="$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:$PATH"
                fi

                # Rehash command cache to pick up Homebrew Ruby
                hash -r 2>/dev/null || true

                RUBY_CONFIGURED=true
                USING_HOMEBREW_RUBY=true
                return 0
            fi
        fi

        # Homebrew Ruby not found or too old, install it
        run_with_status "Installing Ruby..." brew install ruby || {
            print_warning "Ruby may already be installed"
        }

        RUBY_CONFIGURED=true
        USING_HOMEBREW_RUBY=true

        # Add Homebrew Ruby to PATH
        export PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"
        RUBY_VERSION_PATH=$("$BREW_PREFIX/opt/ruby/bin/ruby" -e 'puts RbConfig::CONFIG["ruby_version"]' 2>/dev/null || echo "")

        # Add to zsh profile
        if [ -f ~/.zshrc ]; then
            if ! grep -q "$BREW_PREFIX/opt/ruby/bin" ~/.zshrc; then
                echo "" >> ~/.zshrc
                echo "# Homebrew Ruby" >> ~/.zshrc
                echo "export PATH=\"$BREW_PREFIX/opt/ruby/bin:\$PATH\"" >> ~/.zshrc
                if [ -n "$RUBY_VERSION_PATH" ]; then
                    echo "export PATH=\"$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:\$PATH\"" >> ~/.zshrc
                fi
                print_info "Added Homebrew Ruby to ~/.zshrc"
            fi
        fi

        # Add to bash profile
        if [ -f ~/.bash_profile ]; then
            if ! grep -q "$BREW_PREFIX/opt/ruby/bin" ~/.bash_profile; then
                echo "" >> ~/.bash_profile
                echo "# Homebrew Ruby" >> ~/.bash_profile
                echo "export PATH=\"$BREW_PREFIX/opt/ruby/bin:\$PATH\"" >> ~/.bash_profile
                if [ -n "$RUBY_VERSION_PATH" ]; then
                    echo "export PATH=\"$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:\$PATH\"" >> ~/.bash_profile
                fi
                print_info "Added Homebrew Ruby to ~/.bash_profile"
            fi
        fi

        # Add to bashrc if it exists
        if [ -f ~/.bashrc ]; then
            if ! grep -q "$BREW_PREFIX/opt/ruby/bin" ~/.bashrc; then
                echo "" >> ~/.bashrc
                echo "# Homebrew Ruby" >> ~/.bashrc
                echo "export PATH=\"$BREW_PREFIX/opt/ruby/bin:\$PATH\"" >> ~/.bashrc
                if [ -n "$RUBY_VERSION_PATH" ]; then
                    echo "export PATH=\"$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:\$PATH\"" >> ~/.bashrc
                fi
                print_info "Added Homebrew Ruby to ~/.bashrc"
            fi
        fi

        # Update PATH for current session (including gem bin)
        if [ -n "$RUBY_VERSION_PATH" ]; then
            export PATH="$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:$PATH"
        fi

        # Rehash command cache to pick up newly installed Ruby
        hash -r 2>/dev/null || true

    elif [ "$OS" = "linux" ]; then
        # On Linux, check if Ruby is already installed and meets minimum version
        if command_exists ruby; then
            CURRENT_RUBY=$(ruby -v | awk '{print $2}' | cut -d'p' -f1)
            RUBY_MAJOR=$(echo "$CURRENT_RUBY" | cut -d'.' -f1)

            RUBY_MINOR=$(echo "$CURRENT_RUBY" | cut -d'.' -f2)
            if [ "$RUBY_MAJOR" -gt 3 ] || ([ "$RUBY_MAJOR" -eq 3 ] && [ "$RUBY_MINOR" -ge 2 ]); then
                print_success "Ruby $CURRENT_RUBY is already installed"

                # Still need to configure user gem installation if using system Ruby
                GEM_DIR=$(gem environment gemdir 2>/dev/null || echo "")
                if [[ "$GEM_DIR" == /var/lib/* ]] || [[ "$GEM_DIR" == /usr/lib/* ]]; then
                    print_info "Configuring user gem installation (system Ruby detected)"
                    # Will configure below
                else
                    return 0
                fi
            else
                print_warning "Current Ruby version $CURRENT_RUBY is too old (need >= 3.2)"
            fi
        fi

        if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
            run_with_status "Installing Ruby..." sudo apt-get install -y ruby-full
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
            run_with_status "Installing Ruby..." sudo dnf install -y ruby ruby-devel || \
            sudo yum install -y ruby ruby-devel
        else
            print_error "Unsupported Linux distribution: $DISTRO"
            print_info "Please install Ruby 3.2+ manually from: https://www.ruby-lang.org/en/documentation/installation/"
            exit 1
        fi

        # Configure gem to install to user directory (avoids need for sudo)
        print_info "Configuring user gem installation..."
        RUBY_VERSION=$(ruby -e 'puts RbConfig::CONFIG["ruby_version"]')
        USER_GEM_HOME="$HOME/.gem/ruby/$RUBY_VERSION"

        # Add gem configuration to shell profiles
        GEM_CONFIG="# Ruby gem user installation
export GEM_HOME=\"\$HOME/.gem/ruby/$RUBY_VERSION\"
export GEM_PATH=\"\$HOME/.gem/ruby/$RUBY_VERSION:/var/lib/gems/$RUBY_VERSION\"
export PATH=\"\$HOME/.gem/ruby/$RUBY_VERSION/bin:\$PATH\""

        # Add to bashrc (primary config file for Ubuntu/Debian)
        if [ -f ~/.bashrc ]; then
            if ! grep -q "GEM_HOME.*\.gem/ruby" ~/.bashrc; then
                echo "" >> ~/.bashrc
                echo "$GEM_CONFIG" >> ~/.bashrc
                print_info "Added gem configuration to ~/.bashrc"
            fi
        fi

        # Add to bash_profile if it exists
        if [ -f ~/.bash_profile ]; then
            if ! grep -q "GEM_HOME.*\.gem/ruby" ~/.bash_profile; then
                echo "" >> ~/.bash_profile
                echo "$GEM_CONFIG" >> ~/.bash_profile
                print_info "Added gem configuration to ~/.bash_profile"
            fi
        fi

        # Add to zshrc if it exists
        if [ -f ~/.zshrc ]; then
            if ! grep -q "GEM_HOME.*\.gem/ruby" ~/.zshrc; then
                echo "" >> ~/.zshrc
                echo "$GEM_CONFIG" >> ~/.zshrc
                print_info "Added gem configuration to ~/.zshrc"
            fi
        fi

        # Set for current session
        export GEM_HOME="$USER_GEM_HOME"
        export GEM_PATH="$USER_GEM_HOME:/var/lib/gems/$RUBY_VERSION"
        export PATH="$USER_GEM_HOME/bin:$PATH"

        # Create gem directory if it doesn't exist
        mkdir -p "$USER_GEM_HOME"

        RUBY_CONFIGURED=true
        hash -r 2>/dev/null || true
    fi

    # Verify Ruby installation and version
    if ! command_exists ruby; then
        print_error "Ruby installation failed"
        exit 1
    fi

    INSTALLED_RUBY=$(ruby -v | awk '{print $2}' | cut -d'p' -f1)
    RUBY_MAJOR=$(echo "$INSTALLED_RUBY" | cut -d'.' -f1)

    RUBY_MINOR=$(echo "$INSTALLED_RUBY" | cut -d'.' -f2)
    if [ "$RUBY_MAJOR" -lt 3 ] || ([ "$RUBY_MAJOR" -eq 3 ] && [ "$RUBY_MINOR" -lt 2 ]); then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}${BOLD}  Ruby Version Error${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Installed Ruby version:${NC} $INSTALLED_RUBY"
        echo -e "  ${BOLD}Required Ruby version:${NC}  3.2 or higher"
        echo ""
        echo -e "${BOLD}How to fix:${NC}"
        echo -e "  Install Ruby 3.2+ using one of these methods:"
        echo ""
        if [ "$OS" = "macos" ]; then
            echo -e "  ${BOLD}Option 1: Homebrew (recommended)${NC}"
            echo -e "    ${BLUE}brew install ruby${NC}"
            echo ""
            echo -e "  ${BOLD}Option 2: rbenv${NC}"
            echo -e "    ${BLUE}brew install rbenv${NC}"
            echo -e "    ${BLUE}rbenv install 3.3.0${NC}"
            echo -e "    ${BLUE}rbenv global 3.3.0${NC}"
        else
            echo -e "  ${BOLD}Option 1: rbenv (recommended)${NC}"
            echo -e "    ${BLUE}curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash${NC}"
            echo -e "    ${BLUE}rbenv install 3.3.0${NC}"
            echo -e "    ${BLUE}rbenv global 3.3.0${NC}"
            echo ""
            echo -e "  ${BOLD}Option 2: rvm${NC}"
            echo -e "    ${BLUE}curl -sSL https://get.rvm.io | bash -s stable${NC}"
            echo -e "    ${BLUE}rvm install 3.3.0${NC}"
            echo -e "    ${BLUE}rvm use 3.3.0 --default${NC}"
        fi
        echo ""
        echo -e "  More info: ${BLUE}https://www.ruby-lang.org/en/documentation/installation/${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        exit 1
    fi

    print_success "Ruby $INSTALLED_RUBY installed successfully"

    # Show which Ruby is in use
    RUBY_PATH=$(which ruby)
    print_info "Using Ruby at: $RUBY_PATH"
}

# Install Rails
install_rails() {
    print_step "Installing Rails $RAILS_VERSION..."

    # Ensure Homebrew Ruby is in PATH for macOS (only if using Homebrew Ruby)
    if [ "$OS" = "macos" ] && [ "$USING_HOMEBREW_RUBY" = true ]; then
        BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
        export PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"

        # Add gem bin directory to PATH (dynamically detect Ruby version)
        if [ -x "$BREW_PREFIX/opt/ruby/bin/ruby" ]; then
            RUBY_VERSION_PATH=$("$BREW_PREFIX/opt/ruby/bin/ruby" -e 'puts RbConfig::CONFIG["ruby_version"]')
            export PATH="$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:$PATH"
        fi

        # Rehash command cache to pick up gem executables
        hash -r 2>/dev/null || true
    fi

    # On Linux, ensure user gem paths are set
    if [ "$OS" = "linux" ]; then
        RUBY_VERSION=$(ruby -e 'puts RbConfig::CONFIG["ruby_version"]')
        USER_GEM_HOME="$HOME/.gem/ruby/$RUBY_VERSION"
        export GEM_HOME="$USER_GEM_HOME"
        export GEM_PATH="$USER_GEM_HOME:/var/lib/gems/$RUBY_VERSION"
        export PATH="$USER_GEM_HOME/bin:$PATH"
        mkdir -p "$USER_GEM_HOME"
    fi

    # Check if Rails is already installed
    if command_exists rails; then
        CURRENT_RAILS=$(rails --version | awk '{print $2}')
        print_info "Current Rails version: $CURRENT_RAILS"
    fi

    # Install specific Rails version
    run_with_status "Installing Rails $RAILS_VERSION..." gem install rails -v "$RAILS_VERSION" --no-document

    # Determine the exact rails binary path for this Ruby/gem environment
    RAILS_BIN=$(gem environment gemdir)/bin/rails
    if [ ! -x "$RAILS_BIN" ]; then
        # Fallback: try to find rails in PATH
        RAILS_BIN=$(command -v rails)
        if [ -z "$RAILS_BIN" ]; then
            print_error "Failed to locate rails binary after installation"
            exit 1
        fi
    fi

    print_success "Rails $RAILS_VERSION installed successfully"
    print_info "Rails binary at: $RAILS_BIN"
}

# Get app name from user
get_app_name() {
    print_step "Setting up your Spree application..."

    # Check if we're in WSL and in a Windows mount point
    if [ "$OS" = "linux" ] && [[ $(pwd) == /mnt/* ]]; then
        print_warning "You are currently in a Windows directory ($(pwd))"
        print_warning "Rails requires Unix file permissions which Windows filesystems don't support."
        echo
        print_info "Changing to your Linux home directory: $HOME"
        cd "$HOME" || {
            print_error "Failed to change to home directory"
            exit 1
        }
        print_success "Now in: $(pwd)"
        echo
    fi

    # Use default app name if auto-accept is enabled and no app name provided
    if [ "$AUTO_ACCEPT" = true ] && [[ -z "$APP_NAME" ]]; then
        APP_NAME="spree"
        print_info "Using default app name: $APP_NAME"
    fi

    # Check if app name was provided via command line argument or auto-accept
    if [[ -n "$APP_NAME" ]]; then
        # Validate app name provided via argument
        if [[ ! "$APP_NAME" =~ ^[a-z0-9_]+$ ]]; then
            print_error "App name must contain only lowercase letters, numbers, and underscores"
            print_error "Provided: $APP_NAME"
            exit 1
        fi

        # Handle existing directory
        if [ -d "$APP_NAME" ]; then
            if [ "$FORCE_REMOVE" = true ]; then
                print_warning "Directory '$APP_NAME' already exists, removing..."
                rm -rf "$APP_NAME"
            else
                print_error "Directory '$APP_NAME' already exists"
                print_error "Use --force to remove it automatically"
                exit 1
            fi
        fi

        print_success "App name set to: $APP_NAME"
        return 0
    fi

    # Interactive prompt using gum
    echo
    while true; do
        APP_NAME=$(gum input \
            --header "What would you like to name your application?" \
            --header.foreground 4 \
            --placeholder "my_store" \
            --value "spree" \
            --width 40)

        # Use default if empty
        if [[ -z "$APP_NAME" ]]; then
            APP_NAME="spree"
        fi

        # Validate app name
        if [[ ! "$APP_NAME" =~ ^[a-z0-9_]+$ ]]; then
            print_error "App name must contain only lowercase letters, numbers, and underscores"
            continue
        fi

        if [ -d "$APP_NAME" ]; then
            print_warning "Directory '$APP_NAME' already exists"
            if gum confirm "Remove and continue?"; then
                rm -rf "$APP_NAME"
                break
            else
                print_info "Please choose a different name"
                continue
            fi
        fi

        break
    done

    print_success "App name set to: $APP_NAME"
}

# Ask about storefront type
ask_storefront_type() {
    print_step "Configure storefront..."

    # Skip prompt if storefront type was provided via command line
    if [[ -n "$STOREFRONT_TYPE" ]]; then
        if [[ "$STOREFRONT_TYPE" == "none" ]]; then
            print_success "No storefront will be installed (headless mode)"
        elif [[ "$STOREFRONT_TYPE" == "rails" ]]; then
            print_success "Ruby on Rails storefront with visual page builder will be installed"
        else
            print_error "Invalid storefront type: $STOREFRONT_TYPE (valid options: none, rails)"
            exit 1
        fi
        return 0
    fi

    # Skip prompt if auto-accept is enabled
    if [ "$AUTO_ACCEPT" = true ]; then
        STOREFRONT_TYPE="none"
        print_info "No storefront will be installed (default)"
        return 0
    fi

    echo
    print_info "Next.js storefront coming soon!"
    echo

    STOREFRONT_CHOICE=$(gum choose \
        --header "Which storefront would you like to install?" \
        --header.foreground 4 \
        --cursor.foreground 2 \
        "No storefront (headless mode) - recommended for custom frontends" \
        "Ruby on Rails with visual page builder")

    case "$STOREFRONT_CHOICE" in
        "No storefront"*)
            STOREFRONT_TYPE="none"
            echo
            print_success "No storefront will be installed (headless mode)"
            ;;
        "Ruby on Rails"*)
            STOREFRONT_TYPE="rails"
            echo
            print_success "Ruby on Rails storefront with visual page builder will be installed"
            ;;
    esac
}

# Ask about loading sample data
ask_sample_data() {
    print_step "Configure sample data..."

    # Skip prompt if auto-accept is enabled
    if [ "$AUTO_ACCEPT" = true ]; then
        LOAD_SAMPLE_DATA="true"
        print_info "Sample data will be loaded (default)"
        return 0
    fi

    echo
    print_info "Sample data includes demo products, categories, and content to help you get started."
    echo

    if gum confirm "Load sample data?" --default=true; then
        LOAD_SAMPLE_DATA="true"
        print_success "Sample data will be loaded"
    else
        LOAD_SAMPLE_DATA="false"
        print_success "Sample data will not be loaded"
    fi
}

# Ask about admin credentials
ask_admin_credentials() {
    print_step "Configure admin user..."

    # Skip prompt if auto-accept is enabled
    if [ "$AUTO_ACCEPT" = true ]; then
        ADMIN_EMAIL="spree@example.com"
        ADMIN_PASSWORD="spree123"
        print_info "Using default admin credentials:"
        print_info "  Email: $ADMIN_EMAIL"
        print_info "  Password: $ADMIN_PASSWORD"
        return 0
    fi

    echo
    ADMIN_EMAIL=$(gum input \
        --header "Admin email" \
        --header.foreground 4 \
        --placeholder "admin@example.com" \
        --value "spree@example.com" \
        --width 40)

    if [[ -z "$ADMIN_EMAIL" ]]; then
        ADMIN_EMAIL="spree@example.com"
    fi

    ADMIN_PASSWORD=$(gum input \
        --header "Admin password" \
        --header.foreground 4 \
        --value "spree123" \
        --width 40)

    if [[ -z "$ADMIN_PASSWORD" ]]; then
        ADMIN_PASSWORD="spree123"
    fi

    echo
    print_success "Admin credentials set:"
    print_info "  Email: $ADMIN_EMAIL"
    print_info "  Password: $ADMIN_PASSWORD"
}

# Create Rails app with Spree template
create_rails_app() {
    # Ensure Homebrew Ruby is in PATH for macOS (only if using Homebrew Ruby)
    if [ "$OS" = "macos" ] && [ "$USING_HOMEBREW_RUBY" = true ]; then
        BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
        export PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"

        # Add gem bin directory to PATH (dynamically detect Ruby version)
        if [ -x "$BREW_PREFIX/opt/ruby/bin/ruby" ]; then
            RUBY_VERSION_PATH=$("$BREW_PREFIX/opt/ruby/bin/ruby" -e 'puts RbConfig::CONFIG["ruby_version"]')
            export PATH="$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:$PATH"
        fi

        # Rehash command cache to pick up gem executables
        hash -r 2>/dev/null || true
    fi

    # On Linux, ensure user gem paths are set
    if [ "$OS" = "linux" ]; then
        RUBY_VERSION=$(ruby -e 'puts RbConfig::CONFIG["ruby_version"]')
        USER_GEM_HOME="$HOME/.gem/ruby/$RUBY_VERSION"
        export GEM_HOME="$USER_GEM_HOME"
        export GEM_PATH="$USER_GEM_HOME:/var/lib/gems/$RUBY_VERSION"
        export PATH="$USER_GEM_HOME/bin:$PATH"
        mkdir -p "$USER_GEM_HOME"
    fi

    # Use local template if available, otherwise use remote URL
    if [ -f "spree/template.rb" ]; then
        TEMPLATE_FILE="spree/template.rb"
    else
        TEMPLATE_FILE="$TEMPLATE_URL"
    fi

    # Prepare environment variables
    local use_local_spree="false"
    if [ "$USE_LOCAL_SPREE" = true ]; then
        use_local_spree="true"
    fi

    # Run rails new with the template using the specific rails binary
    if [ "$VERBOSE" = true ]; then
        print_step "Creating Spree Commerce application '$APP_NAME'..."
        VERBOSE_MODE=1 LOAD_SAMPLE_DATA="$LOAD_SAMPLE_DATA" STOREFRONT_TYPE="$STOREFRONT_TYPE" USE_LOCAL_SPREE="$use_local_spree" ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" "$RAILS_BIN" _${RAILS_VERSION}_ new "$APP_NAME" -m "$TEMPLATE_FILE"
    else
        # Run with gum spinner
        echo ""
        gum spin --spinner dot --title "Creating Spree Commerce application '$APP_NAME' (this will take several minutes)..." -- \
            bash -c "VERBOSE_MODE=0 LOAD_SAMPLE_DATA=\"$LOAD_SAMPLE_DATA\" STOREFRONT_TYPE=\"$STOREFRONT_TYPE\" USE_LOCAL_SPREE=\"$use_local_spree\" ADMIN_EMAIL=\"$ADMIN_EMAIL\" ADMIN_PASSWORD=\"$ADMIN_PASSWORD\" \"$RAILS_BIN\" _${RAILS_VERSION}_ new \"$APP_NAME\" -m \"$TEMPLATE_FILE\" >/tmp/spree_install.log 2>&1"
        local exit_code=$?

        if [ $exit_code -ne 0 ]; then
            echo ""
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${RED}${BOLD}  Spree Installation Failed${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "${BOLD}Error log (last 50 lines):${NC}"
            echo ""
            tail -50 /tmp/spree_install.log
            echo ""
            echo -e "${BOLD}Full log saved at:${NC} /tmp/spree_install.log"
            echo ""
            echo -e "${BOLD}Troubleshooting:${NC}"
            echo -e "  1. Run the installer with --verbose flag for detailed output:"
            echo -e "     ${BLUE}bash -c \"\$(curl -fsSL https://spreecommerce.org/install)\" -- --verbose${NC}"
            echo ""
            echo -e "  2. Check your Ruby version (requires 3.2+):"
            echo -e "     ${BLUE}ruby -v${NC}"
            echo ""
            echo -e "${BOLD}Report this issue:${NC}"
            echo -e "  If the problem persists, please report it at:"
            echo -e "  ${BLUE}${GITHUB_ISSUES_URL}${NC}"
            echo ""
            echo -e "  Please include the error log above in your report."
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            exit 1
        fi

        rm -f /tmp/spree_install.log
    fi

    print_success "Spree Commerce application created successfully"
}

# Final instructions
show_final_instructions() {
    print_header
    print_success "Spree Commerce installation completed successfully!"

    echo ""
    gum style --foreground 2 --bold "What's next?"
    echo ""

    echo -e "${BOLD}1. Start the development server:${NC}"
    echo -e "   ${BLUE}cd $APP_NAME${NC}"
    echo -e "   ${BLUE}bin/dev${NC}"

    echo -e "\n${BOLD}2. Access your Spree store:${NC}"
    if [ "$STOREFRONT_TYPE" = "rails" ]; then
        echo -e "   Storefront: ${BLUE}http://localhost:3000${NC}"
    else
        echo -e "   Storefront API: ${BLUE}http://localhost:3000/api/v2/storefront${NC}"
    fi
    echo -e "   Admin Panel: ${BLUE}http://localhost:3000/admin${NC}"
    echo -e "   Admin credentials:"
    echo -e "     Email: ${BOLD}$ADMIN_EMAIL${NC}"
    echo -e "     Password: ${BOLD}$ADMIN_PASSWORD${NC}"

    echo -e "\n${BOLD}3. Useful commands:${NC}"
    echo -e "   ${BLUE}bin/rails console${NC}              # Rails console"
    if [ "$LOAD_SAMPLE_DATA" = "false" ]; then
        if [ "$USE_LOCAL_SPREE" = true ]; then
            echo -e "   ${BLUE}bin/rails spree:load_sample_data${NC} # Load sample data"
        else
            echo -e "   ${BLUE}bin/rails spree_sample:load${NC}    # Load sample data"
        fi
    fi

    echo -e "\n${BOLD}4. Documentation:${NC}"
    echo -e "   Developer Guide: ${BLUE}https://spreecommerce.org/docs/developer${NC}"
    echo -e "   API Documentation: ${BLUE}https://spreecommerce.org/docs/api${NC}"

    echo ""
    gum style --foreground 2 --bold "Happy coding with Spree Commerce!"
    echo ""

    # Skip server start prompt if auto-accept is enabled
    if [ "$AUTO_ACCEPT" = true ]; then
        return 0
    fi

    # Ask if user wants to start server now
    if gum confirm "Would you like to start the server now?" --default=true; then
        print_info "Starting server... (Press Ctrl+C to stop)"
        cd "$APP_NAME"

        # Ensure Homebrew Ruby is in PATH for macOS (only if using Homebrew Ruby)
        if [ "$OS" = "macos" ] && [ "$USING_HOMEBREW_RUBY" = true ]; then
            BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
            export PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"

            # Add gem bin directory to PATH (dynamically detect Ruby version)
            if [ -x "$BREW_PREFIX/opt/ruby/bin/ruby" ]; then
                RUBY_VERSION_PATH=$("$BREW_PREFIX/opt/ruby/bin/ruby" -e 'puts RbConfig::CONFIG["ruby_version"]')
                export PATH="$BREW_PREFIX/lib/ruby/gems/$RUBY_VERSION_PATH/bin:$PATH"
            fi

            # Rehash command cache to pick up gem executables
            hash -r 2>/dev/null || true
        fi

        # On Linux, ensure user gem paths are set
        if [ "$OS" = "linux" ]; then
            RUBY_VERSION=$(ruby -e 'puts RbConfig::CONFIG["ruby_version"]')
            USER_GEM_HOME="$HOME/.gem/ruby/$RUBY_VERSION"
            export GEM_HOME="$USER_GEM_HOME"
            export GEM_PATH="$USER_GEM_HOME:/var/lib/gems/$RUBY_VERSION"
            export PATH="$USER_GEM_HOME/bin:$PATH"
        fi

        bin/dev
    fi
}

# Main installation flow
main() {
    detect_os
    install_gum

    print_header

    echo "This installer will set up Spree Commerce on your system."
    echo ""
    echo "It will install the following if needed:"
    echo "  - System dependencies (libvips for image processing)"
    echo "  - Ruby language"
    echo "  - Create a new Spree application"

    if [ "$USE_LOCAL_SPREE" = true ]; then
        print_warning "Using local Spree gems from parent directory"
    fi

    if [ "$AUTO_ACCEPT" = false ]; then
        echo
        gum confirm "Continue with installation?" --default=true || exit 0
    fi

    install_system_deps
    install_ruby
    install_rails
    get_app_name
    ask_storefront_type
    ask_sample_data
    ask_admin_credentials
    create_rails_app
    show_final_instructions

    # Automatically start a new shell with updated PATH if Ruby/gem paths were configured
    # (Only needed when we modify shell profiles - Homebrew Ruby or gem bin paths)
    if [ "$RUBY_CONFIGURED" = true ]; then
        sleep 1

        # Detect user's shell and start it with updated environment
        USER_SHELL="${SHELL:-/bin/bash}"

        if [[ "$USER_SHELL" == *"zsh"* ]]; then
            exec /bin/zsh -l
        elif [[ "$USER_SHELL" == *"bash"* ]]; then
            exec /bin/bash -l
        else
            # Fallback to their configured shell
            exec "$USER_SHELL" -l
        fi
    fi
}

# Run main installation
main
