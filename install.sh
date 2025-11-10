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
RUBY_VERSION="3.3.0"
RAILS_VERSION="8.0.4"
APP_NAME=""
LOAD_SAMPLE_DATA="false"
TEMPLATE_URL="https://raw.githubusercontent.com/spree/spree/main/template.rb"
VERBOSE=false
USE_LOCAL_SPREE=false
AUTO_ACCEPT=false
FORCE_REMOVE=false

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
            read -p "Remove and continue? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
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

    read -p "Load sample data? (Y/n): " -r
    echo

    # Default to yes if empty response
    if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
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
            if [[ $(uname -m) == 'arm64' ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
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
            print_info "Installing libvips-dev..."
            run_with_status "Running: apt-get update" sudo apt-get update
            run_with_status "Running: apt-get install runtime deps" sudo apt-get install -y build-essential libvips-dev libssl-dev libreadline-dev zlib1g-dev libsqlite3-dev 

            print_success "System dependencies installed"
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
            print_info "Installing vips development packages..."
            run_with_status "Running: dnf/yum install runtime deps" sudo dnf install -y vips vips-devel gcc gcc-c++ make openssl-devel readline-devel zlib-devel sqlite-devel || \
            sudo yum install -y vips vips-devel gcc gcc-c++ make openssl-devel readline-devel zlib-devel sqlite-devel 

            print_success "System dependencies installed"
        else
            print_warning "Please install libvips development packages manually for your distribution"
            press_any_key
        fi
    fi
}

# Install rbenv and Ruby
install_ruby() {
    print_step "Checking Ruby installation..."

    # Check if Ruby 3.3.0 is already installed
    if command_exists ruby; then
        CURRENT_RUBY=$(ruby -v | awk '{print $2}' | cut -d'p' -f1)
        if [[ "$CURRENT_RUBY" == "$RUBY_VERSION"* ]]; then
            print_success "Ruby $RUBY_VERSION is already installed"
            return 0
        else
            print_info "Current Ruby version: $CURRENT_RUBY"
            print_info "Spree requires Ruby $RUBY_VERSION"
        fi
    fi

    # Check for rbenv
    if ! command_exists rbenv; then
        print_info "Installing rbenv..."

        if [ "$OS" = "macos" ]; then
            run_with_status "Running: brew install rbenv ruby-build" brew install rbenv ruby-build || {
                print_warning "Packages may already be installed"
            }

            # Ensure Homebrew environment is loaded
            if [[ $(uname -m) == 'arm64' ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
            else
                eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
            fi

            # Initialize rbenv for macOS (brew installation)
            eval "$(rbenv init - bash)" 2>/dev/null || true
        elif [ "$OS" = "linux" ]; then
            curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

            # Add rbenv to PATH
            export PATH="$HOME/.rbenv/bin:$PATH"
            eval "$(rbenv init - bash)"

            # Add to shell profile
            if [ -f ~/.bashrc ]; then
                echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
                echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
            fi
            if [ -f ~/.zshrc ]; then
                echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
                echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
            fi
        fi

        print_success "rbenv installed"
    else
        print_success "rbenv is already installed"

        # Initialize rbenv in current shell for existing installations
        if [ "$OS" = "macos" ]; then
            # Ensure Homebrew environment is loaded for existing brew installations
            if [[ $(uname -m) == 'arm64' ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
            else
                eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
            fi
        else
            # For Linux, use manual installation path
            export PATH="$HOME/.rbenv/bin:$PATH"
        fi

        eval "$(rbenv init - bash)" 2>/dev/null || true
    fi

    # Install Ruby 3.3.0
    print_info "Installing Ruby $RUBY_VERSION (this may take several minutes)..."

    if rbenv versions | grep -q "$RUBY_VERSION"; then
        print_success "Ruby $RUBY_VERSION is already installed via rbenv"
    else
        rbenv install "$RUBY_VERSION"
        print_success "Ruby $RUBY_VERSION installed successfully"
    fi

    rbenv global "$RUBY_VERSION"
    rbenv rehash

    print_success "Ruby $RUBY_VERSION is now active"
}

# Install Rails
install_rails() {
    print_step "Installing Rails $RAILS_VERSION..."

    # Ensure rbenv is initialized
    if [ "$OS" = "macos" ]; then
        # Ensure Homebrew environment is loaded
        if [[ $(uname -m) == 'arm64' ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
        else
            eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
        fi
    else
        export PATH="$HOME/.rbenv/bin:$PATH"
    fi
    eval "$(rbenv init - bash)" 2>/dev/null || true

    # Check if Rails is already installed
    if command_exists rails; then
        CURRENT_RAILS=$(rails --version | awk '{print $2}')
        print_info "Current Rails version: $CURRENT_RAILS"
    fi

    # Install specific Rails version
    print_info "Installing Rails gem (this may take a few minutes)..."
    run_with_status "Running: gem install rails -v $RAILS_VERSION" gem install rails -v "$RAILS_VERSION" --no-document
    run_quiet rbenv rehash

    print_success "Rails $RAILS_VERSION installed successfully"
}

# Create Rails app with Spree template
create_rails_app() {
    print_step "Creating new Spree Commerce application..."

    # Ensure rbenv is initialized
    if [ "$OS" = "macos" ]; then
        # Ensure Homebrew environment is loaded
        if [[ $(uname -m) == 'arm64' ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
        else
            eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
        fi
    else
        export PATH="$HOME/.rbenv/bin:$PATH"
    fi
    eval "$(rbenv init - bash)" 2>/dev/null || true

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

    # Run rails new with the template
    if [ "$VERBOSE" = true ]; then
        VERBOSE_MODE=1 LOAD_SAMPLE_DATA="$LOAD_SAMPLE_DATA" USE_LOCAL_SPREE="$use_local_spree" ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" rails _${RAILS_VERSION}_ new "$APP_NAME" -m "$TEMPLATE_FILE"
    else
        # Run in background with spinner
        VERBOSE_MODE=0 LOAD_SAMPLE_DATA="$LOAD_SAMPLE_DATA" USE_LOCAL_SPREE="$use_local_spree" ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" rails _${RAILS_VERSION}_ new "$APP_NAME" -m "$TEMPLATE_FILE" >/tmp/spree_install.log 2>&1 &
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
                msg="Installing Rails and dependencies"
            elif [ $elapsed -lt 60 ]; then
                msg="Installing Spree gems (this takes a while)"
            elif [ $elapsed -lt 90 ]; then
                msg="Setting up Devise authentication"
            elif [ $elapsed -lt 120 ]; then
                msg="Running Spree generators"
            elif [ $elapsed -lt 150 ]; then
                msg="Configuring payment integrations"
            elif [ $elapsed -lt 180 ]; then
                msg="Setting up database"
            else
                msg="Almost done, finalizing installation"
            fi

            printf "\r${BLUE}${spin:$i:1}${NC} ${msg}... (${elapsed}s)"
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
    read -p "Would you like to start the server now? (Y/n): " -r
    echo

    # Default to yes if empty response
    if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Starting server... (Press Ctrl+C to stop)"
        cd "$APP_NAME"
        bin/dev
    fi
}

# Main installation flow
main() {
    print_header

    echo -e "This installer will set up Spree Commerce on your system."
    echo -e "It will install the following if needed:"
    echo -e "  • System dependencies (libvips for image processing)"
    echo -e "  • rbenv (Ruby version manager)"
    echo -e "  • Ruby $RUBY_VERSION"
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
}

# Run main installation
main
