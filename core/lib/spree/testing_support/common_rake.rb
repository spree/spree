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

    # Admin and Storefront require JavaScript and CSS (Tailwind) to function properly
    javascript_enabled ||= install_admin || install_storefront
    css_enabled ||= install_admin || install_storefront

    puts args

    ENV['RAILS_ENV'] = 'test'
    Rails.env = 'test'

    dummy_app_args = [
      "--lib_name=#{ENV['LIB_NAME']}"
    ]
    # Use API mode only if no frontend components are needed
    use_api_mode = !install_storefront && !install_admin && !javascript_enabled && !css_enabled
    dummy_app_args << '--api' if use_api_mode
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
    puts 'Running Spree install generator...'
    system("bundle exec rails g spree:install --force --auto-accept --migrate=false --seed=false --sample=false --user_class=#{args[:user_class]} --admin_user_class=#{args[:admin_user_class]} --authentication=#{args[:authentication]}")

    # Run admin install generator if requested
    if install_admin
      puts 'Running Spree Admin install generator...'
      system('bundle exec rails g spree:admin:install --force')
      system('bundle exec rails g spree:admin:devise --force') if args[:authentication] == 'devise'
    end

    # Run storefront install generator if requested
    if install_storefront
      puts 'Running Spree Storefront install generator...'
      system('bundle exec rails g spree:storefront:install --force --migrate=false')
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
