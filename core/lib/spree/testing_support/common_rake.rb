unless defined?(Spree::InstallGenerator)
  require 'generators/spree/install/install_generator'
end

require 'generators/spree/dummy/dummy_generator'
require 'generators/spree/dummy_model/dummy_model_generator'

desc 'Generates a dummy app for testing'
namespace :common do
  task :test_app, :user_class do |_t, args|
    args.with_defaults(
      user_class: 'Spree::LegacyUser',
      install_storefront: 'false',
      install_admin: 'false',
      authentication: 'dummy'
    )
    require ENV['LIB_NAME'].to_s

    ENV['RAILS_ENV'] = 'test'
    Rails.env = 'test'

    skip_javascript = ['spree/api', 'spree/core', 'spree/sample', 'spree/emails'].include?(ENV['LIB_NAME'])

    dummy_app_args = [
      "--lib_name=#{ENV['LIB_NAME']}"
    ]
    if skip_javascript
      dummy_app_args << '--skip_javascript'
    end
    Spree::DummyGenerator.start dummy_app_args

    unless skip_javascript
      system('bundle add sprockets-rails') # we need this until we will remove bootstrap/popper_js gems
      system('bundle exec rails importmap:install turbo:install stimulus:install')
    end

    # install devise if it's not the legacy user, useful for testing storefront
    if args[:authentication] == 'devise' && args[:user_class] != 'Spree::LegacyUser'
      system('bundle exec rails g devise:install --force --auto-accept')
      system("bundle exec rails g devise #{args[:user_class]} --force --auto-accept")
      system('rm -rf spec') # we need to cleanup factories created by devise to avoid naming conflict
    end

    Spree::InstallGenerator.start [
      "--lib_name=#{ENV['LIB_NAME']}",
      '--auto-accept',
      '--migrate=false',
      '--seed=false',
      '--sample=false',
      "--install_storefront=#{args[:install_storefront]}",
      "--install_admin=#{args[:install_admin]}",
      "--user_class=#{args[:user_class]}",
      "--authentication=#{args[:authentication]}"
    ]

    if !skip_javascript || ENV['LIB_NAME'] == 'spree/emails'
      puts 'Precompiling assets...'
      system('bundle exec rake assets:precompile > /dev/null 2>&1')
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
        "#{ENV['LIB_NAME'].camelize}::Generators::InstallGenerator".constantize.start([])
      else
        "#{ENV['LIB_NAME'].camelize}::Generators::InstallGenerator".constantize.start(['--auto-run-migrations'])
      end
    rescue LoadError
      puts 'Skipping installation no generator to run...'
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
