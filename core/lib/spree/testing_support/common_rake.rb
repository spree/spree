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
end
