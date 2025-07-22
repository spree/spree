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

    Spree::DummyGenerator.start [
      "--lib_name=#{ENV['LIB_NAME']}",
      "--skip_javascript=#{skip_javascript}"
    ]

    # install frontend libraries
    unless skip_javascript
      system('bin/rails importmap:install')
      system('bin/rails turbo:install')
      system('bin/rails stimulus:install')
    end

    # install devise if it's not the legacy user, useful for testing storefront
    if args[:authentication] == 'devise' && args[:user_class] != 'Spree::LegacyUser'
      system('bin/rails g devise:install --force --auto-accept')
      system("bin/rails g devise #{args[:user_class]} --force --auto-accept")
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

    puts 'Setting up dummy database...'
    system('bin/rails db:environment:set RAILS_ENV=test > /dev/null 2>&1')
    system('bundle exec rake db:drop db:create > /dev/null 2>&1')
    Spree::DummyModelGenerator.start
    system('bundle exec rake db:migrate > /dev/null 2>&1')

    begin
      require "generators/#{ENV['LIB_NAME']}/install/install_generator"
      puts 'Running extension installation generator...'
      "#{ENV['LIB_NAME'].camelize}::Generators::InstallGenerator".constantize.start(['--auto-run-migrations'])
    rescue LoadError
      puts 'Skipping installation no generator to run...'
    end

    system('bundle exec rake assets:precompile > /dev/null 2>&1') if !skip_javascript || ENV['LIB_NAME'] == 'spree/emails'
  end

  task :seed do |_t|
    puts 'Seeding ...'
    system('bundle exec rake db:seed RAILS_ENV=test > /dev/null 2>&1')
  end
end
