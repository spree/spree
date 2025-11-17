#!/bin/bash

# Spree Commerce Guided Installer
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/spree/spree/main/install.sh)"
# Usage with options: bash install.sh --verbose --local --app-name=my_store --auto-accept --force
# Options:
#   --verbose, -v           Show detailed output
#   --local, -l             Use local Spree gems from parent directory
#   --app-name=NAME         Set application name (skips prompt)
#   --auto-accept, -y       Use default values for all prompts (non-interactive mode)
#   --force, -f             Remove existing directory if it exists

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
RAILS_VERSION="8.0.4"
APP_NAME=""
LOAD_SAMPLE_DATA="false"
TEMPLATE_URL="https://raw.githubusercontent.com/spree/spree/main/template.rb"
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

# Helper functions
print_header() {
    echo -e "\n${BOLD}${BLUE}===================================================${NC}"
    echo -e "${BOLD}${BLUE}  Spree Commerce Guided Installer${NC}"
    echo -e "${BOLD}${BLUE}===================================================${NC}\n"
}

print_step() {
    echo -e "\n${BOLD}${GREEN}➜${NC} ${BOLD}$1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

press_any_key() {
    echo -e "\n${BOLD}Press any key to continue...${NC}"
    read -n 1 -s
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
        print_info "$description"
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

show_spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    # Hide cursor
    tput civis 2>/dev/null || true

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        printf "\r${BLUE}${spin:$i:1}${NC} ${message}..."
        sleep 0.1
    done

    # Show cursor
    tput cnorm 2>/dev/null || true
    printf "\r"
}

# Detect OS
detect_os() {
    print_step "Detecting operating system..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
            print_success "Detected: Linux ($NAME)"
        else
            DISTRO="unknown"
            print_success "Detected: Linux (Unknown distribution)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        print_success "Detected: macOS"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        DISTRO="windows"
        print_warning "Windows detected. WSL is required for Spree."
        echo -e "\nPlease install WSL (Windows Subsystem for Linux) first:"
        echo -e "  ${BOLD}wsl --install${NC}"
        echo -e "\nThen run this installer from within WSL."
        exit 1
    else
        OS="unknown"
        DISTRO="unknown"
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
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

    # Interactive prompt if app name not provided
    echo -e "\n${BOLD}What would you like to name your application?${NC}"
    echo -e "This will be used for the directory name and Spree Commerce application name."
    echo -e "Use lowercase letters, numbers, and underscores (e.g., my_store, awesome_shop)"
    echo -e "${BLUE}Press Enter to use default: 'spree'${NC}"
    echo

    while true; do
        read -p "App name [spree]: " APP_NAME

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
            read -p "Remove and continue? (y/n): " -n 1 -r REMOVE_DIR
            echo
            if [[ $REMOVE_DIR =~ ^[Yy]$ ]]; then
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

# Ask about loading sample data
ask_sample_data() {
    print_step "Configure sample data..."

    # Skip prompt if auto-accept is enabled
    if [ "$AUTO_ACCEPT" = true ]; then
        LOAD_SAMPLE_DATA="true"
        print_info "Sample data will be loaded (default)"
        return 0
    fi

    echo -e "\n${BOLD}Would you like to load sample data?${NC}"
    echo -e "Sample data includes demo products, categories, and content to help you get started."
    echo -e "${BLUE}Press Enter to load sample data (recommended for testing)${NC}"
    echo

    read -p "Load sample data? (Y/n): " -r LOAD_SAMPLE_INPUT
    echo

    # Default to yes if empty response
    if [[ -z "$LOAD_SAMPLE_INPUT" ]] || [[ $LOAD_SAMPLE_INPUT =~ ^[Yy]$ ]]; then
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
        print_info "  Email: ${BOLD}$ADMIN_EMAIL${NC}"
        print_info "  Password: ${BOLD}$ADMIN_PASSWORD${NC}"
        return 0
    fi

    echo -e "\n${BOLD}Set up your admin user credentials${NC}"
    echo -e "These credentials will be used to access the admin panel."
    echo -e "${BLUE}Press Enter to use defaults${NC}"
    echo

    # Ask for admin email
    read -p "Admin email [spree@example.com]: " ADMIN_EMAIL
    if [[ -z "$ADMIN_EMAIL" ]]; then
        ADMIN_EMAIL="spree@example.com"
    fi

    # Ask for admin password
    read -p "Admin password [spree123]: " ADMIN_PASSWORD
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        ADMIN_PASSWORD="spree123"
    fi

    echo
    print_success "Admin credentials set:"
    print_info "  Email: ${BOLD}$ADMIN_EMAIL${NC}"
    print_info "  Password: ${BOLD}$ADMIN_PASSWORD${NC}"
}

# Install system dependencies
install_system_deps() {
    print_step "Installing system dependencies..."

    if [ "$OS" = "macos" ]; then
        if ! command_exists brew; then
            print_warning "Homebrew is not installed"
            echo -e "\n${BOLD}Installing Homebrew...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Add Homebrew to PATH
            # Detect brew installation path dynamically
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

            print_success "Homebrew installed successfully"
        fi

        print_info "Installing libvips..."
        run_with_status "Running: brew install vips" brew install vips || {
            print_warning "Package may already be installed"
        }

        print_success "System dependencies installed"

    elif [ "$OS" = "linux" ]; then
        if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
            print_info "Installing development dependencies..."
            run_with_status "Running: apt-get update" sudo apt-get update
            run_with_status "Running: apt-get install runtime deps" sudo apt-get install -y build-essential git libvips-dev libssl-dev libreadline-dev zlib1g-dev libsqlite3-dev libyaml-dev

            print_success "System dependencies installed"
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
            print_info "Installing development packages..."
            run_with_status "Running: dnf/yum install runtime deps" sudo dnf install -y vips vips-devel gcc gcc-c++ make openssl-devel readline-devel zlib-devel sqlite-devel libyaml-devel git || \
            sudo yum install -y vips vips-devel gcc gcc-c++ make openssl-devel readline-devel zlib-devel sqlite-devel libyaml-devel git

            print_success "System dependencies installed"
        else
            print_warning "Please install libvips development packages manually for your distribution"
            press_any_key
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

                if [ "$RUBY_MAJOR" -ge 3 ]; then
                    print_success "Ruby $CURRENT_RUBY is already installed at $CURRENT_RUBY_PATH"
                    print_info "Using existing Ruby installation"
                    return 0
                else
                    print_warning "Existing Ruby $CURRENT_RUBY at $CURRENT_RUBY_PATH is too old (need >= 3.0)"
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

            if [ "$RUBY_MAJOR" -ge 3 ]; then
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
        print_info "Installing Ruby..."
        run_with_status "Running: brew install ruby" brew install ruby || {
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

            if [ "$RUBY_MAJOR" -ge 3 ]; then
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
                print_warning "Current Ruby version $CURRENT_RUBY is too old (need >= 3.0)"
            fi
        fi

        print_info "Installing Ruby..."

        if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
            run_with_status "Running: apt install ruby-full" sudo apt-get install -y ruby-full
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
            run_with_status "Running: dnf install ruby" sudo dnf install -y ruby ruby-devel || \
            sudo yum install -y ruby ruby-devel
        else
            print_error "Unsupported Linux distribution: $DISTRO"
            print_info "Please install Ruby 3.0+ manually from: https://www.ruby-lang.org/en/documentation/installation/"
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

    if [ "$RUBY_MAJOR" -lt 3 ]; then
        print_error "Installed Ruby version $INSTALLED_RUBY is too old (need >= 3.0)"
        print_info "Please install Ruby 3.0+ manually from: https://www.ruby-lang.org/en/documentation/installation/"
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
    print_info "Installing Rails gem (this may take a few minutes)..."
    run_with_status "Running: gem install rails -v $RAILS_VERSION" gem install rails -v "$RAILS_VERSION" --no-document

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

# Create Rails app with Spree template
create_rails_app() {
    print_step "Creating new Spree Commerce application..."

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

    # Download template if running from URL, or use local if exists
    TEMPLATE_FILE="template.rb"
    if [ ! -f "$TEMPLATE_FILE" ]; then
        print_info "Downloading Spree Rails template..."
        curl -fsSL "$TEMPLATE_URL" -o "$TEMPLATE_FILE"
    fi

    print_info "Creating Spree Commerce application '$APP_NAME'..."

    if [ "$VERBOSE" = false ]; then
        echo -e "${YELLOW}This will take several minutes. Please be patient...${NC}\n"
    fi

    # Prepare environment variables
    local use_local_spree="false"
    if [ "$USE_LOCAL_SPREE" = true ]; then
        use_local_spree="true"
    fi

    # Run rails new with the template using the specific rails binary
    if [ "$VERBOSE" = true ]; then
        VERBOSE_MODE=1 LOAD_SAMPLE_DATA="$LOAD_SAMPLE_DATA" USE_LOCAL_SPREE="$use_local_spree" ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" "$RAILS_BIN" _${RAILS_VERSION}_ new "$APP_NAME" -m "$TEMPLATE_FILE"
    else
        # Run in background with spinner
        VERBOSE_MODE=0 LOAD_SAMPLE_DATA="$LOAD_SAMPLE_DATA" USE_LOCAL_SPREE="$use_local_spree" ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" "$RAILS_BIN" _${RAILS_VERSION}_ new "$APP_NAME" -m "$TEMPLATE_FILE" >/tmp/spree_install.log 2>&1 &
        local rails_pid=$!

        # Show spinner with progress messages
        local elapsed=0
        local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0

        # Hide cursor
        tput civis 2>/dev/null || true

        while kill -0 $rails_pid 2>/dev/null; do
            i=$(( (i+1) %10 ))

            # Change message based on elapsed time
            if [ $elapsed -lt 30 ]; then
                msg="Installing Spree dependencies"
            elif [ $elapsed -lt 60 ]; then
                msg="Installing Spree gems"
            elif [ $elapsed -lt 90 ]; then
                msg="Setting up authentication"
            elif [ $elapsed -lt 120 ]; then
                msg="Running Spree generators"
            elif [ $elapsed -lt 150 ]; then
                msg="Configuring payment integrations"
            elif [ $elapsed -lt 180 ]; then
                msg="Setting up database"
            else
                msg="Almost done, finalizing installation"
            fi

            printf "\r${BLUE}${spin:$i:1}${NC} ${msg}...                  "
            sleep 1
            elapsed=$((elapsed + 1))
        done

        # Show cursor
        tput cnorm 2>/dev/null || true
        printf "\r\033[K"  # Clear line

        # Check if rails command succeeded
        wait $rails_pid
        local exit_code=$?

        if [ $exit_code -ne 0 ]; then
            print_error "Spree Commerce application creation failed!"
            echo -e "\n${YELLOW}Error log:${NC}"
            tail -50 /tmp/spree_install.log
            exit 1
        fi

        rm -f /tmp/spree_install.log
    fi

    # Clean up downloaded template if it was downloaded
    if [ -f "$TEMPLATE_FILE" ] && [ "$TEMPLATE_FILE" != "template.rb" ]; then
        rm "$TEMPLATE_FILE"
    fi

    print_success "Spree Commerce application created successfully"
}

# Final instructions
show_final_instructions() {
    print_header
    print_success "Spree Commerce installation completed successfully!"

    echo -e "\n${BOLD}${GREEN}What's next?${NC}\n"

    echo -e "${BOLD}1. Start the development server:${NC}"
    echo -e "   ${BLUE}cd $APP_NAME${NC}"
    echo -e "   ${BLUE}bin/dev${NC}"

    echo -e "\n${BOLD}2. Access your Spree store:${NC}"
    echo -e "   • Storefront: ${BLUE}http://localhost:3000${NC}"
    echo -e "   • Admin Panel: ${BLUE}http://localhost:3000/admin${NC}"
    echo -e "   • Admin credentials:"
    echo -e "     Email: ${BOLD}$ADMIN_EMAIL${NC}"
    echo -e "     Password: ${BOLD}$ADMIN_PASSWORD${NC}"

    echo -e "\n${BOLD}3. Useful commands:${NC}"
    echo -e "   ${BLUE}bin/rails console${NC}              # Rails console"
    if [ "$LOAD_SAMPLE_DATA" = "false" ]; then
        echo -e "   ${BLUE}bin/rails spree_sample:load${NC}    # Load sample data"
    fi

    echo -e "\n${BOLD}4. Documentation:${NC}"
    echo -e "   • Developer Guide: ${BLUE}https://spreecommerce.org/docs/developer${NC}"
    echo -e "   • API Documentation: ${BLUE}https://spreecommerce.org/docs/api${NC}"

    echo -e "\n${BOLD}${GREEN}Happy coding with Spree Commerce!${NC}\n"

    # Skip server start prompt if auto-accept is enabled
    if [ "$AUTO_ACCEPT" = true ]; then
        return 0
    fi

    # Ask if user wants to start server now (Y is default)
    read -p "Would you like to start the server now? (Y/n): " -r START_SERVER
    echo

    # Default to yes if empty response
    if [[ -z "$START_SERVER" ]] || [[ $START_SERVER =~ ^[Yy]$ ]]; then
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
    print_header

    echo -e "This installer will set up Spree Commerce on your system."
    echo -e "It will install the following if needed:"
    echo -e "  • System dependencies (libvips for image processing)"
    echo -e "  • Ruby 3.0+ (via system package manager)"
    echo -e "  • Rails $RAILS_VERSION"
    echo -e "  • Create a new Spree Commerce application"

    if [ "$USE_LOCAL_SPREE" = true ]; then
        echo -e "\n${YELLOW}Using local Spree gems from parent directory${NC}"
    fi

    if [ "$AUTO_ACCEPT" = false ]; then
        press_any_key
    fi

    detect_os
    install_system_deps
    install_ruby
    install_rails
    get_app_name
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
