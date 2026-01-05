# Spree Commerce Rails Application Template
# This template sets up a new Rails application with Spree Commerce

# Check if verbose mode is enabled via environment variable
VERBOSE = ENV['VERBOSE_MODE'] == '1'
LOAD_SAMPLE_DATA = ENV['LOAD_SAMPLE_DATA'] == 'true'
USE_LOCAL_SPREE = ENV['USE_LOCAL_SPREE'] == 'true'
ADMIN_EMAIL = ENV['ADMIN_EMAIL'] || 'spree@example.com'
ADMIN_PASSWORD = ENV['ADMIN_PASSWORD'] || 'spree123'
SPREE_VERSION = ENV['SPREE_VERSION'] || '~> 5.2'

def add_gems
  say 'Adding required gems to Gemfile...', :blue

  # Core dependencies
  gem 'devise'

  # Spree gems - using main branch for latest
  gem 'spree', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_emails', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_sample', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_admin', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_storefront', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  # translations
  gem 'spree_i18n'

  # Development & Test gems
  gem_group :development, :test do
    gem 'spree_dev_tools'
    gem 'letter_opener'
    gem 'listen'
  end
end

def setup_importmap
  say 'Setting up JavaScript with Importmap...', :blue

  # Rails 8 already has importmap, turbo, and stimulus by default
  # Just ensure they're properly set up by running the install tasks
  # Using system with 'yes' to auto-accept prompts
  if VERBOSE
    system("yes | bin/rails importmap:install")
    system("yes | bin/rails turbo:install")
    system("yes | bin/rails stimulus:install")
  else
    system("yes | bin/rails importmap:install >/dev/null 2>&1")
    system("yes | bin/rails turbo:install >/dev/null 2>&1")
    system("yes | bin/rails stimulus:install >/dev/null 2>&1")
  end
end

def setup_auth
  say 'Setting up authentication...', :blue

  if VERBOSE
    rails_command 'generate devise:install'
    rails_command 'generate devise Spree::User'
    rails_command 'generate devise Spree::AdminUser'
  else
    run 'bin/rails generate devise:install >/dev/null 2>&1'
    run 'bin/rails generate devise Spree::User >/dev/null 2>&1'
    run 'bin/rails generate devise Spree::AdminUser >/dev/null 2>&1'
  end
end

def install_spree
  say 'Running Spree installer...', :blue

  # Run Spree installer with all options
  if VERBOSE
    rails_command "generate spree:install --auto-accept --user_class=Spree::User --admin_user_class=Spree::AdminUser --authentication=devise --install_storefront=true --install_admin=true --admin_email=#{ADMIN_EMAIL} --admin_password=#{ADMIN_PASSWORD}"
  else
    run "bin/rails generate spree:install --auto-accept --user_class=Spree::User --admin_user_class=Spree::AdminUser --authentication=devise --install_storefront=true --install_admin=true --admin_email=#{ADMIN_EMAIL} --admin_password=#{ADMIN_PASSWORD} >/dev/null 2>&1"
  end
end

def install_spree_dev_tools
  say 'Running Spree Dev Tools installer...', :blue
  if VERBOSE
    rails_command "generate spree_dev_tools:install"
  else
    run "bin/rails generate spree_dev_tools:install >/dev/null 2>&1"
  end
end

def configure_development_environment
  say 'Configuring development environment...', :blue

  # Letter opener and file watcher configuration
  inject_into_file 'config/environments/development.rb', before: /^end/ do
    <<-RUBY

  # Letter Opener for email previews
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true

  # Improved file watching
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
    RUBY
  end
end

def setup_procfile
  say 'Setting up Procfile.dev...', :blue

  # Add web server to Procfile.dev
  append_to_file 'Procfile.dev' do
    "\nweb: bin/rails s -p 3000\n"
  end
end

def setup_database
  say 'Setting up database...', :blue

  if VERBOSE
    rails_command 'db:migrate'
  else
    run 'bin/rails db:migrate >/dev/null 2>&1'
  end
end

def load_sample_data
  if LOAD_SAMPLE_DATA
    say 'Loading sample data...', :blue
    if VERBOSE
      rails_command 'spree_sample:load'
    else
      run 'bin/rails spree_sample:load >/dev/null 2>&1'
    end
  end
end

def show_success_message
  say
  say '=' * 60, :green
  say 'Spree Commerce has been successfully installed!', :green
  say '=' * 60, :green
  say
  say 'To start your server:', :yellow
  say '  bin/dev', :bold
  say
  say 'Then visit:', :yellow
  say '  Storefront: http://localhost:3000', :bold
  say '  Admin Panel: http://localhost:3000/admin', :bold
  say
  say 'Admin credentials:', :yellow
  say "  Email: #{ADMIN_EMAIL}", :bold
  say "  Password: #{ADMIN_PASSWORD}", :bold
  say
  say 'Useful commands:', :yellow
  say '  bin/rails console                # Rails console'
  say '  bin/rails spree_sample:load      # Load more sample data'
  say
end

# Main template execution
add_gems

after_bundle do
  setup_importmap
  configure_development_environment
  setup_auth
  install_spree
  install_spree_dev_tools
  setup_procfile
  setup_database
  load_sample_data
  show_success_message
end
