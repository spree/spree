# Spree Commerce Rails Application Template
# This template sets up a new Rails application with Spree Commerce

# Check if verbose mode is enabled via environment variable
VERBOSE = ENV['VERBOSE_MODE'] == '1'
LOAD_SAMPLE_DATA = ENV['LOAD_SAMPLE_DATA'] == 'true'
USE_LOCAL_SPREE = ENV['USE_LOCAL_SPREE'] == 'true'
ADMIN_EMAIL = ENV['ADMIN_EMAIL'] || 'spree@example.com'
ADMIN_PASSWORD = ENV['ADMIN_PASSWORD'] || 'spree123'
SPREE_VERSION = ENV['SPREE_VERSION'] || '~> 5.2'
# Authentication: 'rails' (default) or 'devise'
AUTHENTICATION = ENV['AUTHENTICATION'] || 'rails'

def add_gems
  say 'Adding required gems to Gemfile...', :blue

  # Core dependencies - only add devise if using devise authentication
  gem 'devise' if AUTHENTICATION == 'devise'

  # Spree gems - using main branch for latest
  gem 'spree', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_emails', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_sample', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_admin', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_storefront', USE_LOCAL_SPREE ? { path: '../' } : { version: SPREE_VERSION }
  gem 'spree_page_builder', path: '../packages/page_builder' if USE_LOCAL_SPREE
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

  if AUTHENTICATION == 'devise'
    setup_devise_auth
  else
    setup_rails_auth
  end
end

def setup_devise_auth
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

def setup_rails_auth
  # Rails 8 built-in authentication
  # First, generate authentication for the User model
  if VERBOSE
    rails_command 'generate authentication'
  else
    run 'bin/rails generate authentication >/dev/null 2>&1'
  end

  # Rename User to Spree::User
  rename_user_to_spree_user

  # Create AdminUser with authentication
  create_admin_user_with_auth
end

def rename_user_to_spree_user
  say 'Renaming User to Spree::User...', :blue

  # Create spree directory for models
  FileUtils.mkdir_p('app/models/spree')

  # Read the generated User model
  if File.exist?('app/models/user.rb')
    user_content = File.read('app/models/user.rb')

    # Transform to Spree::User
    spree_user_content = user_content
      .gsub('class User < ApplicationRecord', "module Spree\n  class User < Spree.base_class")
      .gsub(/^end\s*$/, "  end\nend")

    # Write Spree::User
    File.write('app/models/spree/user.rb', spree_user_content)

    # Remove original User model
    FileUtils.rm('app/models/user.rb')
  end

  # Update Session model to reference Spree::User
  if File.exist?('app/models/session.rb')
    session_content = File.read('app/models/session.rb')
    session_content = session_content.gsub("belongs_to :user", "belongs_to :user, class_name: 'Spree::User'")
    File.write('app/models/session.rb', session_content)
  end

  # Update Current model
  if File.exist?('app/models/current.rb')
    current_content = File.read('app/models/current.rb')
    # Add admin_session support
    unless current_content.include?('admin_session')
      current_content = current_content.gsub(
        "delegate :user, to: :session, allow_nil: true",
        "delegate :user, to: :session, allow_nil: true\n\n  attribute :admin_session\n  delegate :user, to: :admin_session, prefix: :admin, allow_nil: true"
      )
      File.write('app/models/current.rb', current_content)
    end
  end

  # Update migrations to use spree_users table
  Dir.glob('db/migrate/*_create_users.rb').each do |migration|
    content = File.read(migration)
    content = content.gsub('create_table :users', 'create_table :spree_users')
    File.write(migration, content)
  end

  Dir.glob('db/migrate/*_create_sessions.rb').each do |migration|
    content = File.read(migration)
    content = content.gsub('t.references :user', "t.references :user, foreign_key: { to_table: :spree_users }")
    File.write(migration, content)
  end

  # Update controllers to use Spree::User
  if File.exist?('app/controllers/sessions_controller.rb')
    content = File.read('app/controllers/sessions_controller.rb')
    content = content.gsub('User.authenticate_by', 'Spree::User.authenticate_by')
    File.write('app/controllers/sessions_controller.rb', content)
  end

  if File.exist?('app/controllers/passwords_controller.rb')
    content = File.read('app/controllers/passwords_controller.rb')
    content = content.gsub('User.find_by', 'Spree::User.find_by')
    content = content.gsub('User.find_by_password_reset_token!', 'Spree::User.find_by_password_reset_token!')
    File.write('app/controllers/passwords_controller.rb', content)
  end
end

def create_admin_user_with_auth
  say 'Creating Spree::AdminUser model...', :blue

  # Create AdminUser model
  admin_user_content = <<~RUBY
    module Spree
      class AdminUser < Spree.base_class
        has_secure_password
        has_many :sessions, class_name: 'AdminSession', dependent: :destroy

        normalizes :email_address, with: ->(e) { e.strip.downcase }
      end
    end
  RUBY

  File.write('app/models/spree/admin_user.rb', admin_user_content)

  # Create AdminSession model
  admin_session_content = <<~RUBY
    class AdminSession < ApplicationRecord
      belongs_to :admin_user, class_name: 'Spree::AdminUser'
    end
  RUBY

  File.write('app/models/admin_session.rb', admin_session_content)

  # Create migration for admin_users
  timestamp = (Time.now + 1).strftime('%Y%m%d%H%M%S')
  migration_content = <<~RUBY
    class CreateSpreeAdminUsers < ActiveRecord::Migration[8.0]
      def change
        create_table :spree_admin_users do |t|
          t.string :email_address, null: false
          t.string :password_digest, null: false

          t.timestamps
        end

        add_index :spree_admin_users, :email_address, unique: true
      end
    end
  RUBY

  File.write("db/migrate/#{timestamp}_create_spree_admin_users.rb", migration_content)

  # Create migration for admin_sessions
  timestamp2 = (Time.now + 2).strftime('%Y%m%d%H%M%S')
  session_migration_content = <<~RUBY
    class CreateAdminSessions < ActiveRecord::Migration[8.0]
      def change
        create_table :admin_sessions do |t|
          t.references :admin_user, null: false, foreign_key: { to_table: :spree_admin_users }
          t.string :ip_address
          t.string :user_agent

          t.timestamps
        end
      end
    end
  RUBY

  File.write("db/migrate/#{timestamp2}_create_admin_sessions.rb", session_migration_content)
end

def install_spree
  say 'Running Spree installer...', :blue

  # Run Spree installer with all options
  if VERBOSE
    rails_command "generate spree:install --auto-accept --user_class=Spree::User --admin_user_class=Spree::AdminUser --authentication=#{AUTHENTICATION} --install_storefront=true --install_admin=true --admin_email=#{ADMIN_EMAIL} --admin_password=#{ADMIN_PASSWORD}"
  else
    run "bin/rails generate spree:install --auto-accept --user_class=Spree::User --admin_user_class=Spree::AdminUser --authentication=#{AUTHENTICATION} --install_storefront=true --install_admin=true --admin_email=#{ADMIN_EMAIL} --admin_password=#{ADMIN_PASSWORD} >/dev/null 2>&1"
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
