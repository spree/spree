# Spree Commerce Rails Application Template
# This template sets up a new Rails application with Spree Commerce

LOAD_SAMPLE_DATA = ENV['LOAD_SAMPLE_DATA'] == 'true'
STOREFRONT_TYPE = ENV['STOREFRONT_TYPE'] || 'none'
USE_LOCAL_SPREE = ENV['USE_LOCAL_SPREE'] == 'true'
ADMIN_EMAIL = ENV['ADMIN_EMAIL'] || 'spree@example.com'
ADMIN_PASSWORD = ENV['ADMIN_PASSWORD'] || 'spree123'
SPREE_VERSION = ENV['SPREE_VERSION'] || '>= 5.3.0.rc1'

def add_gems
  say 'Adding required gems to Gemfile...', :blue

  # Core dependencies
  gem 'devise'

  # Spree gems - core (includes core, api, cli)
  gem 'spree', USE_LOCAL_SPREE ? { path: '../backend/engines' } : { version: SPREE_VERSION }

  # Optional Spree packages
  gem 'spree_emails', USE_LOCAL_SPREE ? { path: '../backend/engines/emails' } : { version: SPREE_VERSION }
  gem 'spree_sample', USE_LOCAL_SPREE ? { path: '../backend/engines/sample' } : { version: SPREE_VERSION }
  gem 'spree_admin', USE_LOCAL_SPREE ? { path: '../backend/engines/admin' } : { version: SPREE_VERSION }

  # Storefront packages (only when Rails storefront is selected)
  if STOREFRONT_TYPE == 'rails'
    gem 'spree_storefront'
  end

  # translations
  gem 'spree_i18n'

  # Development & Test gems
  gem_group :development, :test do
    gem 'spree_dev_tools'
    gem 'letter_opener'
    gem 'listen'
  end
end

def setup_auth
  say 'Setting up authentication...', :blue

  generate 'devise:install'
  generate 'devise', 'Spree::User'
  generate 'devise', 'Spree::AdminUser'
end

def install_spree
  say 'Running Spree installer (core, api, cli)...', :blue

  # Run Spree installer with migrations but without seeds - seeds run after all generators complete
  generate 'spree:install', '--force', '--auto-accept', '--seed=false',
           '--user_class=Spree::User', '--admin_user_class=Spree::AdminUser',
           '--authentication=devise'
end

def install_spree_admin
  say 'Installing Spree Admin...', :blue

  generate 'spree:admin:install', '--force'
  generate 'spree:admin:devise', '--force'
end

def install_spree_storefront
  say 'Installing Spree Storefront...', :blue

  generate 'spree:storefront:install', '--force'
  generate 'spree:storefront:devise', '--force'
end

def configure_development_environment
  say 'Configuring development environment...', :blue

  # Letter opener and file watcher configuration
  environment nil, env: 'development' do
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

def seed_database
  say 'Loading seed data...', :blue

  rails_command "db:seed AUTO_ACCEPT=1 ADMIN_EMAIL=#{ADMIN_EMAIL} ADMIN_PASSWORD=#{ADMIN_PASSWORD}"
end

def load_sample_data
  if LOAD_SAMPLE_DATA
    say 'Loading sample data...', :blue
    rails_command 'spree_sample:load'
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
  if STOREFRONT_TYPE == 'rails'
    say '  Storefront: http://localhost:3000', :bold
  else
    say '  Storefront API: http://localhost:3000/api/v2/storefront', :bold
  end
  say '  Admin Panel: http://localhost:3000/admin', :bold
  say
  say 'Admin credentials:', :yellow
  say "  Email: #{ADMIN_EMAIL}", :bold
  say "  Password: #{ADMIN_PASSWORD}", :bold
  say
  say 'Useful commands:', :yellow
  say '  bin/rails console                # Rails console'
  say '  bin/rails spree_sample:load      # Load more sample data'
  say '  bin/spree version                # Spree CLI version'
  say '  bin/spree extension my_ext       # Generate a new Spree extension'
  say
end

# Main template execution
add_gems

after_bundle do
  configure_development_environment
  setup_auth
  install_spree
  install_spree_admin
  install_spree_storefront if STOREFRONT_TYPE == 'rails'
  setup_procfile
  seed_database
  load_sample_data
  show_success_message
end
