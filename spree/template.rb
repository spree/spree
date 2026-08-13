require 'shellwords'

# Spree Commerce Rails Application Template
# Sets up a new headless Rails application (Spree core + API) using the gem-owned
# Spree::Customer / Spree::AdminUser auth models (has_secure_password). The admin
# UI is the React dashboard (@spree/dashboard) talking to the Admin API.

LOAD_SAMPLE_DATA = ENV['LOAD_SAMPLE_DATA'] == 'true'
USE_LOCAL_SPREE = ENV['USE_LOCAL_SPREE'] == 'true'
# Monorepo root (the dir that contains the `spree` gem dir) for USE_LOCAL_SPREE
# (dev only). A path source rooted at `<root>/spree` exposes every nested
# gemspec (spree, spree_core, spree_api, spree_emails, …) via Bundler's default
# glob, resolving the whole stack locally.
SPREE_LOCAL_PATH = ENV['SPREE_LOCAL_PATH'] || '.'
# No defaults: without explicit credentials the seed mints no admin and
# prints a one-time setup link instead — the dashboard's first-run screen
# creates the account. This keeps well-known credentials out of every app
# scaffolded from this template.
ADMIN_EMAIL = ENV['ADMIN_EMAIL']
ADMIN_PASSWORD = ENV['ADMIN_PASSWORD']
SPREE_VERSION = ENV['SPREE_VERSION'] || '>= 5.4.2'

def add_gems
  say 'Adding required gems to Gemfile...', :blue

  # Spree gems - core (includes core, api, cli)
  gem 'spree', USE_LOCAL_SPREE ? { path: File.join(SPREE_LOCAL_PATH, 'spree') } : { version: SPREE_VERSION }

  # Optional Spree packages
  gem 'spree_emails', USE_LOCAL_SPREE ? { path: File.join(SPREE_LOCAL_PATH, 'spree', 'emails') } : { version: SPREE_VERSION }

  # translations
  gem 'spree_i18n'

  # Development & Test gems
  gem_group :development, :test do
    gem 'spree_dev_tools'
    gem 'letter_opener'
    gem 'listen'
  end
end

def install_spree
  say 'Running Spree installer (core, api, cli)...', :blue

  # Run Spree installer with migrations but without seeds - seeds run after all
  # generators complete. Uses the gem-owned Spree::Customer / Spree::AdminUser
  # defaults (has_secure_password); no --authentication scaffolding.
  generate 'spree:install', '--force', '--auto-accept', '--seed=false'
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

def seed_database
  say 'Loading seed data...', :blue

  if ADMIN_EMAIL.present? && ADMIN_PASSWORD.present?
    # rails_command interpolates into a shell command line, so a password
    # containing shell metacharacters would otherwise be mangled or executed.
    rails_command "db:seed AUTO_ACCEPT=1 ADMIN_EMAIL=#{Shellwords.escape(ADMIN_EMAIL)} ADMIN_PASSWORD=#{Shellwords.escape(ADMIN_PASSWORD)}"
  else
    rails_command 'db:seed AUTO_ACCEPT=1'
  end
end

def load_sample_data
  if LOAD_SAMPLE_DATA
    if ADMIN_EMAIL.present? && ADMIN_PASSWORD.present?
      say 'Loading sample data...', :blue
      rails_command 'spree:load_sample_data'
    else
      # Sample-data imports need an admin as their owner, and none was seeded.
      say 'Skipping sample data — it needs an admin account. Load it after first-run setup with: bin/rails spree:load_sample_data', :yellow
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
  say '  Store API: http://localhost:3000/api/v3/store', :bold
  say '  Admin API: http://localhost:3000/api/v3/admin', :bold
  say
  if ADMIN_EMAIL.present? && ADMIN_PASSWORD.present?
    say 'Admin account (sign in via the Admin API / React dashboard):', :yellow
    say "  Email: #{ADMIN_EMAIL}", :bold
    say "  Password: #{ADMIN_PASSWORD}", :bold
  else
    say 'Admin account:', :yellow
    say '  Use the setup link printed by the seed above to create it.', :bold
    say '  (Reprint it any time with: bin/rails spree:setup:token)'
  end
  say
  say 'Useful commands:', :yellow
  say '  bin/rails console                # Rails console'
  say "  bin/rails spree:load_sample_data # Load more sample data"
  say
end

# Main template execution
add_gems

after_bundle do
  configure_development_environment
  install_spree
  setup_procfile
  seed_database
  load_sample_data
  show_success_message
end
