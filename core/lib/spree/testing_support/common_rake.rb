require 'generators/spree/dummy/dummy_generator'
require 'generators/spree/dummy_model/dummy_model_generator'

desc 'Generates a dummy app for testing'
namespace :common do
  task :test_app, :user_class do |_t, args|
    args.with_defaults(
      authentication: 'dummy',
      user_class: 'Spree::LegacyUser',
      install_storefront: false,
      install_admin: false,
      javascript: false,
      css: false
    )
    require ENV['LIB_NAME'].to_s

    # Convert to booleans (supports both string and boolean values for backwards compatibility)
    install_admin = args[:install_admin].to_b
    install_storefront = args[:install_storefront].to_b
    javascript_enabled = args[:javascript].to_b
    css_enabled = args[:css].to_b

    # Admin and Storefront require CSS (Tailwind) to function properly
    css_enabled ||= install_admin || install_storefront

    puts args

    ENV['RAILS_ENV'] = 'test'
    Rails.env = 'test'

    dummy_app_args = [
      "--lib_name=#{ENV['LIB_NAME']}"
    ]
    dummy_app_args << '--javascript' if javascript_enabled
    dummy_app_args << '--css=tailwind' if css_enabled

    puts dummy_app_args

    Spree::DummyGenerator.start dummy_app_args

    # Install JavaScript dependencies (importmap, turbo, stimulus) if JavaScript is enabled
    # Rails includes the gems but doesn't run the installers automatically
    if javascript_enabled
      puts 'Installing JavaScript dependencies...'
      system('yes | bundle exec rails importmap:install turbo:install stimulus:install')
    end

    # install devise if it's not the legacy user, useful for testing storefront
    if args[:authentication] == 'devise' && args[:user_class] != 'Spree::LegacyUser'
      system('bundle exec rails g devise:install --force --auto-accept')
      system("bundle exec rails g devise #{args[:user_class]} --force --auto-accept")
      system("bundle exec rails g devise #{args[:admin_user_class]} --force --auto-accept") if args[:admin_user_class].present? && args[:admin_user_class] != args[:user_class]
      system('rm -rf spec') # we need to cleanup factories created by devise to avoid naming conflict
    end

    # Run core Spree install generator
    # The spree:install generator lives in the root spree gem. Core gems (spree_core, spree_api)
    # don't have spree as a dependency, so we need to use the root Gemfile to access the generator.
    # Other gems (admin, storefront, etc.) already have spree in their Gemfile.
    core_gems = %w[spree/core spree/api]
    root_gemfile = File.expand_path('../../../../Gemfile', __dir__)
    use_root_gemfile = core_gems.include?(ENV['LIB_NAME']) &&
                       File.exist?(root_gemfile) &&
                       File.exist?(File.expand_path('../../../../spree.gemspec', __dir__))
    bundle_exec = use_root_gemfile ? "bundle exec --gemfile=#{root_gemfile}" : 'bundle exec'
    puts 'Running Spree install generator...'
    system("#{bundle_exec} rails g spree:install --force --auto-accept --migrate=false --seed=false --sample=false --user_class=#{args[:user_class]} --admin_user_class=#{args[:admin_user_class]} --authentication=#{args[:authentication]}")

    # Determine if we need to install admin/storefront
    # Either via explicit flag or because we're testing that gem itself
    needs_admin = install_admin || ENV['LIB_NAME'] == 'spree/admin'
    needs_storefront = install_storefront || ENV['LIB_NAME'] == 'spree/storefront'

    # Run admin install generator if requested or testing admin gem
    if needs_admin
      # Only run install if explicitly requested (not when testing admin gem itself)
      if install_admin
        puts 'Running Spree Admin install generator...'
        system('bundle exec rails g spree:admin:install --force')
      end
      system('bundle exec rails g spree:admin:devise --force') if args[:authentication] == 'devise'
    end

    # Run storefront install generator if requested or testing storefront gem
    if needs_storefront
      # Only run install if explicitly requested (not when testing storefront gem itself)
      if install_storefront
        puts 'Running Spree Storefront install generator...'
        system('bundle exec rails g spree:storefront:install --force --migrate=false')
      end
      system('bundle exec rails g spree:storefront:devise --force') if args[:authentication] == 'devise'
    end

    unless ENV['NO_MIGRATE']
      puts 'Setting up dummy database...'
      system('bundle exec rails db:environment:set RAILS_ENV=test > /dev/null 2>&1')
      system('bundle exec rake db:drop db:create > /dev/null 2>&1')
      Spree::DummyModelGenerator.start
      system('bundle exec rake db:migrate > /dev/null 2>&1')
    end

    begin
      require "generators/#{ENV['LIB_NAME']}/install/install_generator"
      puts 'Running extension installation generator...'

      if ENV['NO_MIGRATE']
        "#{ENV['LIB_NAME'].camelize}::Generators::InstallGenerator".constantize.start(['--force'])
      else
        "#{ENV['LIB_NAME'].camelize}::Generators::InstallGenerator".constantize.start(['--force', '--auto-run-migrations'])
      end
    rescue LoadError => e
      puts "Error loading generator: #{e.message}"
      puts 'Skipping installation no generator to run...'
    end

    # Precompile assets after all generators have run
    # This ensures CSS entry points (like Spree Admin's Tailwind CSS) are created first
    if javascript_enabled || css_enabled
      puts 'Precompiling assets...'
      system('bundle exec rake assets:precompile')
    end
  end

  task :db_setup do |_t|
    puts 'Setting up dummy database...'
    system('bundle exec rails db:environment:set RAILS_ENV=test > /dev/null 2>&1')
    system('bundle exec rake db:drop db:create > /dev/null 2>&1')
    Spree::DummyModelGenerator.start
    system('bundle exec rake db:migrate > /dev/null 2>&1')
  end

  task :seed do |_t|
    puts 'Seeding ...'
    system('bundle exec rake db:seed RAILS_ENV=test > /dev/null 2>&1')
  end

  # Build a prebuilt test app template for CI reuse
  # Reads configuration from environment variables to avoid rake argument parsing issues
  task :build_prebuilt_app do |_t|
    require ENV['LIB_NAME'].to_s

    # Read configuration from environment variables
    authentication = ENV.fetch('AUTHENTICATION', 'dummy')
    user_class = ENV.fetch('USER_CLASS', 'Spree::LegacyUser')
    admin_user_class = ENV['ADMIN_USER_CLASS'].to_s.empty? ? nil : ENV['ADMIN_USER_CLASS']
    install_admin = ENV.fetch('INSTALL_ADMIN', 'false').to_b
    install_storefront = ENV.fetch('INSTALL_STOREFRONT', 'false').to_b
    javascript_enabled = ENV.fetch('JAVASCRIPT', 'false').to_b
    css_enabled = ENV.fetch('CSS', 'false').to_b

    # Admin and Storefront require CSS (Tailwind) to function properly
    css_enabled ||= install_admin || install_storefront

    puts "Building prebuilt app with config:"
    puts "  LIB_NAME: #{ENV['LIB_NAME']}"
    puts "  DUMMY_PATH: #{ENV['DUMMY_PATH']}"
    puts "  authentication: #{authentication}"
    puts "  user_class: #{user_class}"
    puts "  admin_user_class: #{admin_user_class}"
    puts "  install_admin: #{install_admin}"
    puts "  install_storefront: #{install_storefront}"
    puts "  javascript: #{javascript_enabled}"
    puts "  css: #{css_enabled}"

    ENV['RAILS_ENV'] = 'test'
    Rails.env = 'test'

    dummy_app_args = [
      "--lib_name=#{ENV['LIB_NAME']}"
    ]
    dummy_app_args << '--javascript' if javascript_enabled
    dummy_app_args << '--css=tailwind' if css_enabled

    Spree::DummyGenerator.start dummy_app_args

    # Install JavaScript dependencies (importmap, turbo, stimulus) if JavaScript is enabled
    if javascript_enabled
      puts 'Installing JavaScript dependencies...'
      system('yes | bundle exec rails importmap:install turbo:install stimulus:install')
    end

    # install devise if it's not the legacy user
    if authentication == 'devise' && user_class != 'Spree::LegacyUser'
      system('bundle exec rails g devise:install --force --auto-accept')
      system("bundle exec rails g devise #{user_class} --force --auto-accept")
      system("bundle exec rails g devise #{admin_user_class} --force --auto-accept") if admin_user_class.present? && admin_user_class != user_class
      system('rm -rf spec') # cleanup factories created by devise
    end

    # Run core Spree install generator
    core_gems = %w[spree/core spree/api]
    root_gemfile = File.expand_path('../../../../Gemfile', __dir__)
    use_root_gemfile = core_gems.include?(ENV['LIB_NAME']) &&
                       File.exist?(root_gemfile) &&
                       File.exist?(File.expand_path('../../../../spree.gemspec', __dir__))
    bundle_exec = use_root_gemfile ? "bundle exec --gemfile=#{root_gemfile}" : 'bundle exec'
    puts 'Running Spree install generator...'
    system("#{bundle_exec} rails g spree:install --force --auto-accept --migrate=false --seed=false --sample=false --user_class=#{user_class} --admin_user_class=#{admin_user_class} --authentication=#{authentication}")

    # Determine if we need to install admin/storefront
    needs_admin = install_admin || ENV['LIB_NAME'] == 'spree/admin'
    needs_storefront = install_storefront || ENV['LIB_NAME'] == 'spree/storefront'

    # Run admin install generator if requested or testing admin gem
    if needs_admin
      if install_admin
        puts 'Running Spree Admin install generator...'
        system('bundle exec rails g spree:admin:install --force')
      end
      system('bundle exec rails g spree:admin:devise --force') if authentication == 'devise'
    end

    # Run storefront install generator if requested or testing storefront gem
    if needs_storefront
      if install_storefront
        puts 'Running Spree Storefront install generator...'
        system('bundle exec rails g spree:storefront:install --force --migrate=false')
      end
      system('bundle exec rails g spree:storefront:devise --force') if authentication == 'devise'
    end

    unless ENV['NO_MIGRATE']
      puts 'Setting up dummy database...'
      system('bundle exec rails db:environment:set RAILS_ENV=test > /dev/null 2>&1')
      system('bundle exec rake db:drop db:create > /dev/null 2>&1')
      Spree::DummyModelGenerator.start
      system('bundle exec rake db:migrate > /dev/null 2>&1')
    end

    begin
      require "generators/#{ENV['LIB_NAME']}/install/install_generator"
      puts 'Running extension installation generator...'

      if ENV['NO_MIGRATE']
        "#{ENV['LIB_NAME'].camelize}::Generators::InstallGenerator".constantize.start(['--force'])
      else
        "#{ENV['LIB_NAME'].camelize}::Generators::InstallGenerator".constantize.start(['--force', '--auto-run-migrations'])
      end
    rescue LoadError => e
      puts "Error loading generator: #{e.message}"
      puts 'Skipping installation no generator to run...'
    end

    # Precompile assets after all generators have run
    if javascript_enabled || css_enabled
      puts 'Precompiling assets...'
      system('bundle exec rake assets:precompile')
    end

    puts "Prebuilt app created at #{ENV['DUMMY_PATH']}"
  end

  # Use a prebuilt test app template instead of generating from scratch
  # This is used in CI to speed up test app creation
  task :use_prebuilt_app, [:template_type] do |_t, args|
    require 'fileutils'
    require 'yaml'
    require 'erb'

    template_type = args[:template_type] || 'basic'
    prebuilt_dir = Pathname.new('/tmp/prebuilt-test-apps').join(template_type)
    dummy_path = ENV['DUMMY_PATH'] || 'spec/dummy'
    lib_name = ENV['LIB_NAME']

    unless prebuilt_dir.exist?
      raise "Prebuilt template not found at #{prebuilt_dir}. Run bin/build-test-apps.rb first."
    end

    puts "Using prebuilt #{template_type} template from #{prebuilt_dir}..."

    # Remove existing dummy app if present
    FileUtils.rm_rf(dummy_path) if File.exist?(dummy_path)

    # Copy the prebuilt template
    puts 'Copying prebuilt template...'
    FileUtils.cp_r(prebuilt_dir.to_s, dummy_path)

    # Update config/application.rb with the correct lib_name require
    update_application_rb(dummy_path, lib_name)

    # Update config/boot.rb with the correct Gemfile path
    update_boot_rb(dummy_path, lib_name)

    # database.yml uses ERB and reads from ENV vars at runtime, no need to regenerate

    # Run module-specific install generator if it exists
    run_module_generator(lib_name)

    # Setup database - create and load schema
    unless ENV['NO_MIGRATE']
      puts 'Setting up database...'
      # Set the environment
      system('bundle exec rails db:environment:set RAILS_ENV=test') || true
      # Drop and create the database
      puts 'Creating database...'
      system('bundle exec rake db:drop db:create') || raise('Failed to create database')
      # Generate the dummy model migration if not present
      Spree::DummyModelGenerator.start
      # Load schema (faster than running migrations) or run migrations if no schema exists
      schema_file = File.join(dummy_path, 'db', 'schema.rb')
      if File.exist?(schema_file)
        puts 'Loading schema...'
        system('bundle exec rake db:schema:load') || raise('Failed to load schema')
      else
        puts 'Running migrations...'
        system('bundle exec rake db:migrate') || raise('Failed to run migrations')
      end
    end

    puts "Prebuilt #{template_type} template ready at #{dummy_path}"
  end
end

def update_application_rb(dummy_path, lib_name)
  app_rb_path = File.join(dummy_path, 'config', 'application.rb')
  return unless File.exist?(app_rb_path)

  content = File.read(app_rb_path)

  # Replace the require line with the correct lib_name
  # The template may have been built with a different lib_name
  content.gsub!(/require ['"]spree\/\w+['"]/, "require '#{lib_name}'")

  File.write(app_rb_path, content)
  puts "Updated #{app_rb_path} to require '#{lib_name}'"
end

def update_boot_rb(dummy_path, lib_name)
  boot_rb_path = File.join(dummy_path, 'config', 'boot.rb')
  return unless File.exist?(boot_rb_path)

  # Determine the correct Gemfile path based on lib_name
  core_gems = ['spree/core', 'spree/api']
  gemfile_path = if core_gems.include?(lib_name)
                   '../../../../../Gemfile'
                 else
                   '../../../../Gemfile'
                 end

  content = <<~RUBY
    require 'rubygems'
    gemfile = File.expand_path("#{gemfile_path}", __FILE__)

    ENV['BUNDLE_GEMFILE'] = gemfile
    require 'bundler'
    Bundler.setup
  RUBY

  File.write(boot_rb_path, content)
  puts "Updated #{boot_rb_path} with Gemfile path: #{gemfile_path}"
end

def run_module_generator(lib_name)
  begin
    require "generators/#{lib_name}/install/install_generator"
    puts "Running #{lib_name} installation generator..."

    if ENV['NO_MIGRATE']
      "#{lib_name.camelize}::Generators::InstallGenerator".constantize.start(['--force'])
    else
      "#{lib_name.camelize}::Generators::InstallGenerator".constantize.start(['--force', '--auto-run-migrations'])
    end
  rescue LoadError => e
    puts "No installation generator found for #{lib_name}, skipping..."
  end
end
