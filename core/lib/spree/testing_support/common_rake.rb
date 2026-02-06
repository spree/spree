require 'generators/spree/dummy/dummy_generator'
require 'generators/spree/dummy_model/dummy_model_generator'

desc 'Generates a dummy app for testing'
namespace :common do
  task :test_app, [:authentication, :user_class, :admin_user_class, :css, :javascript, :install_admin, :install_storefront] do |_t, args|
    # Support both Rake::TaskArguments (via invoke) and Hash (via execute)
    # When using execute with a Hash, args IS the hash directly
    defaults = {
      authentication: 'dummy',
      user_class: 'Spree::LegacyUser',
      admin_user_class: 'Spree::LegacyAdminUser',
      install_storefront: false,
      install_admin: false,
      javascript: false,
      css: false
    }
    # Rake::TaskArguments#with_defaults modifies in-place
    # ActiveSupport adds Hash#with_defaults which returns a new hash, so check for Rake::TaskArguments specifically
    if args.is_a?(Rake::TaskArguments)
      args.with_defaults(defaults)
    else
      # Hash passed via execute - use reverse_merge! to merge defaults in place
      args.reverse_merge!(defaults)
    end
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
end

# Custom parallel setup task instead of parallel_tests' native parallel:create/parallel:prepare
# because Spree gems are not Rails apps — the Rails app lives in spec/dummy/ and db: rake tasks
# are not available from the gem directory. For SQLite, we copy the primary .sqlite3 file which
# is faster than creating + migrating N databases through Rails.
desc 'Create and prepare databases for parallel test workers'
task :parallel_setup, [:count] do |_t, args|
  require 'parallel'

  count = (args[:count] || ENV.fetch('PARALLEL_TEST_PROCESSORS', Parallel.processor_count)).to_i
  dummy_path = ENV['DUMMY_PATH'] || 'spec/dummy'
  db_config_path = File.join(dummy_path, 'config', 'database.yml')

  raise "Database config not found at #{db_config_path}. Run 'rake test_app' first." unless File.exist?(db_config_path)

  require 'erb'
  require 'yaml'

  db_config = YAML.safe_load(ERB.new(File.read(db_config_path)).result, permitted_classes: [Symbol])
  adapter = db_config.dig('test', 'adapter')

  if adapter == 'sqlite3'
    # For SQLite, copy the primary test database for each worker
    primary_db = File.join(dummy_path, db_config.dig('test', 'database'))

    raise "Primary test database not found at #{primary_db}. Run 'rake test_app' first." unless File.exist?(primary_db)

    2.upto(count) do |i|
      worker_db = primary_db.sub(/\.sqlite3$/, "#{i}.sqlite3")
      FileUtils.cp(primary_db, worker_db)
      puts "Created parallel database: #{worker_db}"
    end
  else
    # For PostgreSQL/MySQL, create and migrate each worker's database
    2.upto(count) do |i|
      env_vars = "TEST_ENV_NUMBER=#{i} RAILS_ENV=test"
      puts "Setting up database for worker #{i}..."
      Dir.chdir(dummy_path) do
        system("#{env_vars} bundle exec rake db:create db:migrate") || raise("Failed to setup database for worker #{i}")
      end
    end
  end

  puts "Parallel databases setup complete (#{count} workers)"
end

desc 'Run specs in parallel'
task :parallel_spec, [:count] do |_t, args|
  count = args[:count] || ENV.fetch('PARALLEL_TEST_PROCESSORS', nil)
  count_arg = count ? "-n #{count}" : ''
  success = system("bundle exec parallel_rspec #{count_arg} spec")
  exit(success ? 0 : 1)
end
