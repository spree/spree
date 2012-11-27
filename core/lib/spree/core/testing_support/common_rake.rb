unless defined?(Spree::InstallGenerator)
  require 'generators/spree/install/install_generator'
end

desc "Generates a dummy app for testing"
namespace :common do
  task :test_app, :user_class do |t, args|
    args.with_defaults(:user_class => "Spree::LegacyUser")
    require "#{ENV['LIB_NAME']}"

    Spree::DummyGenerator.start ["--lib_name=#{ENV['LIB_NAME']}", "--database=#{ENV['DB_NAME']}", "--quiet"]
    Spree::InstallGenerator.start ["--lib_name=#{ENV['LIB_NAME']}", "--auto-accept", "--migrate=false", "--seed=false", "--sample=false", "--quiet", "--user_class=#{args[:user_class]}"]

    puts "Setting up dummy database..."
    cmd = "bundle exec rake db:drop db:create db:migrate db:test:prepare"

    if RUBY_PLATFORM =~ /mswin/ #windows
      cmd += " >nul"
    else
      cmd += " >/dev/null"
    end

    system(cmd)
  end
end
