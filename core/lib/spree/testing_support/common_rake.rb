unless defined?(Spree::InstallGenerator)
  require 'generators/spree/install/install_generator'
end

require 'generators/spree/dummy/dummy_generator'
require 'generators/spree/dummy_model/dummy_model_generator'

desc 'Generates a dummy app for testing'
namespace :common do
  task :test_app, :user_class do |_t, args|
    args.with_defaults(user_class: 'Spree::LegacyUser', install_storefront: 'false', install_admin: 'false')
    require ENV['LIB_NAME'].to_s

    ENV['RAILS_ENV'] = 'test'
    Rails.env = 'test'

    Spree::DummyGenerator.start ["--lib_name=#{ENV['LIB_NAME']}"]

    # install frontend libraries
    unless ['spree/api', 'spree/core', 'spree/sample'].include?(ENV['LIB_NAME'])
      system('bin/rails importmap:install')
      system('bin/rails turbo:install')
      system('bin/rails stimulus:install')
    end

    Spree::InstallGenerator.start [
      "--lib_name=#{ENV['LIB_NAME']}",
      '--auto-accept',
      '--migrate=false',
      '--seed=false',
      '--sample=false',
      '--copy_storefront=false',
      "--install_storefront=#{args[:install_storefront]}",
      "--install_admin=#{args[:install_admin]}",
      "--user_class=#{args[:user_class]}"
    ]

    puts 'Setting up dummy database...'
    system('bin/rails db:environment:set RAILS_ENV=test')
    system('bundle exec rake db:drop db:create')
    Spree::DummyModelGenerator.start
    system('bundle exec rake db:migrate')

    begin
      require "generators/#{ENV['LIB_NAME']}/install/install_generator"
      puts 'Running extension installation generator...'
      "#{ENV['LIB_NAME'].camelize}::Generators::InstallGenerator".constantize.start(['--auto-run-migrations'])
    rescue LoadError
      puts 'Skipping installation no generator to run...'
    end

    unless ['spree/api', 'spree/core', 'spree/sample'].include?(ENV['LIB_NAME'])
      puts 'Precompiling assets...'
      system('bundle exec rake assets:precompile')
    end
  end

  task :seed do |_t|
    puts 'Seeding ...'
    system('bundle exec rake db:seed RAILS_ENV=test')
  end
end
